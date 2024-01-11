package Language::INTERCAL::Interface::Curses;

# Text (Curses) interface for sick and intercalc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/UI-Curses INTERCAL/Interface/Curses.pm 1.-94.-2.1") =~ /\s(\S+)$/;

use Carp;
use Curses;
use Config '%Config';
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Interface::common '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::Interface::common);

my %keymap = (
    'Left' => KEY_LEFT,
    'BackSpace' => KEY_BACKSPACE,
    'Enter' => KEY_ENTER,
    'Return' => "\cM",
    'Linefeed' => "\cJ",
    (map { ("F$_" => KEY_F($_)) } (1..12)),
    (map { ("M-" . chr($_) => chr($_ + 128)) } (1..127)),
);

my @reserved = (
    {
	"\cM"        => \&_activate,
	"\cJ"        => \&_activate,
    },
    {
	&KEY_LEFT    => \&_move_left,
	&KEY_RIGHT   => \&_move_right,
	&KEY_UP      => \&_move_up,
	&KEY_DOWN    => \&_move_down,
	&KEY_ENTER   => \&_activate,
    },
);

my $line_draw = ' │─└││┌├─┘─┴┐┤┬┼';
utf8::decode($line_draw);

my %frame = (
    A => ' |-+||++-+-+++++',
    L => $line_draw,
);

my %styles = (
    MESSAGES      => [],
    ENABLEDKEYS   => [A_BOLD],
    DISABLEDKEYS  => [],
    ENABLEDMENUS  => [A_BOLD],
    DISABLEDMENUS => [],
    CURRENTITEM   => [A_REVERSE],
    FRAMES        => [],
);

my %colours = (
    white   => COLOR_WHITE,
    red     => COLOR_RED,
    green   => COLOR_GREEN,
    yellow  => COLOR_YELLOW,
    blue    => COLOR_BLUE,
    magenta => COLOR_MAGENTA,
    cyan    => COLOR_CYAN,
    black   => COLOR_BLACK,
);

sub _add_window {
    my ($curs) = @_;
    unshift @{$curs->{windows}}, {
	keypress => [],
	keylist => [],
	keyrows => [],
	keycols => [],
	lastkey => [0, 0],
	prevkey => 0,
	menu_byname => {},
	menu_entries => {},
	menu_keys => [],
	menu_index => {},
	in_menu => 0,
	in_dialog => 0,
	after_act => 0,
    };
}

sub new {
    @_ == 2
	or croak "Usage: Language::INTERCAL::Interface::Curses->new(SERVER)";
    my ($class, $server) = @_;
    $server or croak "Must provide SERVER";
    -t STDIN or die "Standard input not a terminal\n";
    -t STDOUT or die "Standard output not a terminal\n";
    my $screen = newterm(undef, *STDOUT, *STDIN) or return undef;
    set_term($screen);
    clearok(1);
    noecho();
    cbreak();
    leaveok(0);
    eval "END { eval { keypad(0) }; eval { nocbreak() }; eval { meta(0) }; eval { nodelay(0) }; endwin(); print '\n' }";
    keypad(1);
    meta(1);
    nodelay(1);
    eval { start_color() };
    # copy values not reference; it's OK to have reference to the elements
    # as we'll install a new reference if they call set_style
    my %s = %styles;
    my $curse = bless {
	windows => [],
	resize => 0,
	redraw => 0,
	pending => [],
	wid => 0,
	server => $server,
	frame => $line_draw,
	styles => \%s,
	colours => {},
	ncolours => 0,
	use_mouse => 0,
    }, $class;
    $curse->_initialise;
    # Curses may generate keys while STDIN does not show ready, but we might as
    # well add something to interrupt a wait if we know something will be coming in
    $server->file_listen(fileno(STDIN), sub { _get_keys($curse) });
    defined \&KEY_RESIZE or $SIG{WINCH} = sub { push @{$curse->{pending}}, undef; };
    $curse;
}

sub set_frame {
    @_ == 2 or croak "Usage: Curses->set_frame(FRAME)";
    my ($curse, $frame) = @_;
    exists $frame{uc $frame} or croak "Invalid FRAME: $frame";
    $curse->{frame} = $frame{uc $frame};
}

sub all_styles {
    @_ == 1 or croak "Usage: Curses->all_styles";
    my ($curse) = @_;
    keys %{$curse->{styles}};
}

sub _colour {
    my ($curse, $colour, $isbg) = @_;
    if (defined $colour) {
	$colour = lc $colour;
	$colour =~ s/\s+//g;
	exists $colours{$colour} and return $colours{$colour};
    }
    my ($fg, $bg);
    pair_content(0, $fg, $bg);
    $isbg ? $bg : $fg;
}

sub set_style {
    @_ == 3 or croak "Usage: Curses->set_style(STYLE, VALUE)";
    my ($curse, $style, $value) = @_;
    exists $curse->{styles}{$style} or croak "Invalid STYLE $style";
    my @value;
    $value->{BOLD} and push @value, A_BOLD;
    defined &A_ITALIC && $value->{ITALIC} and push @value, &A_ITALIC;
    $value->{DIM} and push @value, A_DIM;
    $value->{REVERSE} and push @value, A_REVERSE;
    if (defined $value->{COLOUR}) {
	my $fg = _colour($curse, $value->{COLOUR}, 0);
	my $bg = _colour($curse, $value->{BACKGROUND}, 1);
	my $v;
	if (exists $curse->{colours}{$fg}{$bg}) {
	    $v = $curse->{colours}{$fg}{$bg};
	} else {
	    $curse->{ncolours}++;
	    $curse->{colours}{$fg}{$bg} = $v = $curse->{ncolours};
	    init_pair($curse->{ncolours}, $fg, $bg);
	}
	push @value, COLOR_PAIR($v);
    }
    $curse->{styles}{$style} = \@value;
    $curse;
}

sub _get_keys {
    my ($curse) = @_;
    while (1) {
	my ($ch, $key) = getchar();
	if (defined $key) {
	    push @{$curse->{pending}}, [1, $key];
	} elsif (defined $ch) {
	    push @{$curse->{pending}}, [0, $ch];
	} else {
	    last;
	}
    }
}

sub use_mouse {
    @_ == 2 or croak "Usage: Curses->use_mouse(VALUE)";
    my ($curse, $value) = @_;
    $value = !!$value;
    if ($curse->{use_mouse} != $value) {
	$curse->{use_mouse} = $value;
	eval {
	    my $mask = 0;
	    defined &BUTTON1_CLICKED and $mask |= &BUTTON1_CLICKED;
	    $curse->{mouse_button} = pack('i', $mask);
	    defined &REPORT_MOUSE_POSITION and $mask |= &REPORT_MOUSE_POSITION;
	    # mousemask() in the C code accepts a NULL, but the Perl one
	    # will not, and produce "Modification of a read-only value attempted"
	    # so we'll save the old mask even if we don't need it
	    my $oldmask;
	    mousemask($mask, $oldmask);
	};
    }
    $curse;
}

sub has_window { 1 }
sub is_interactive { 1 }
sub is_terminal { 1 }
sub can_paste { 0 }

sub stdread {
    croak "Curses interface should not use stdread directly";
}

sub getline {
    @_ == 2 or croak "Usage: Curses->getline(PROMPT)";
    my ($curse, $prompt) = @_;
    # XXX this is just a draft implementation so there is some way of
    # XXX executing a WRITE IN - it's not meant to be the final form
    my $v = ' ' x ($COLS - 10);
    my @def = (
	'vstack', border => 2, data =>
	['text', value => $prompt, align => 'c'],
	['text', value => $v, align => 'l', name => '__getline'],
    );
    my $window = $curse->window("Program input", undef, \@def);
    $curse->set_text('__getline', '');
    my $line = '';
    $curse->{windows}[0]{in_dialog} = \$line;
    my $ok = 1;
    $curse->{windows}[0]{keypress}[0]{"\c["} = $curse->{windows}[0]{keypress}[0]{'`'} = {
	hidden => 1,
	action => sub { $curse->{running} = 0; $ok = 0 },
	enabled => 1,
    };
    $curse->{windows}[0]{keypress}[0]{"\cH"} = $curse->{windows}[0]{keypress}[1]{&KEY_BACKSPACE} = {
	hidden => 1,
	action => sub {
	    $line eq '' and return;
	    chop $line;
	    $curse->set_text('__getline', $line);
	},
	enabled => 1,
    };
    my $or = $curse->{running};
    $curse->run;
    $curse->close($window);
    $curse->{running} = $or;
    $ok ? "$line\n" : undef;
}

sub file_dialog {
    @_ == 5 or croak "Usage: Curses->file_dialog(TITLE, NEW?, OK, CANCEL)";
    my ($curse, $title, $new, $ok, $cancel) = @_;
    # XXX this is just a draft implementation so there is some way of
    # XXX getting a file name - it's not meand to be the final form
    my $res = $curse->getline($title);
    chomp($res);
    $res;
}

sub alter_data {
    @_ == 3 or croak "Usage: Curses->alter_data(WINDOW, DATA)";
    croak "alter_data not implemented for Curses"; # XXX
}

sub window {
    @_ == 4 || @_ == 5 || @_ == 6
	or croak "Usage: Curses->window(NAME, DESTROY, DEFINITION "
	       . "[, MENUS [, ACT]])";
    my ($curse, $name, $destroy, $def, $menus, $act) = @_;
    my $window = _window($curse, $def, $menus);
    $curse->{windows}[0]{after_act} = $act;
    $curse->{windows}[0]{name} = $name;
    _place($window, 0, COLS, 0, LINES);
    _finish_window($curse, $window);
    &{$window->{show}}($curse, $window, 0);
    $window;
}

sub _window {
    my ($curse, $def, $menus) = @_;
    _add_window($curse);
    my $wid = ++$curse->{wid};
    if (defined $menus) {
	$curse->{windows}[0]{keypress}[0]{"\c["} = $curse->{windows}[0]{keypress}[0]{'`'} = {
	    hidden => 1,
	    action => \&_swap_menu_and_keypad,
	    enabled => 1,
	};
	$curse->_parse_menus($wid, @$menus);
	my @def = (
	    'vstack', border => 0, data =>
	    ['hstack', border => 1, data => @{$curse->{windows}[0]{menu_keys}}, ],
	    $def,
	);
	$def = \@def;
    }
    my $window = $curse->_parse_def($wid, @$def);
    $window->{wid} = $wid;
    $curse->{windows}[0]{window} = $window;
    $window;
}

sub _setup_keymaps {
    my ($curse) = @_;
    $curse->{windows}[0]{keyrows} = [];
    $curse->{windows}[0]{keycols} = [];
    if (@{$curse->{windows}[0]{keylist}}) {
	$curse->{windows}[0]{keylist} =
	    [ sort { $a->{y} <=> $b->{y} || $a->{x} <=> $b->{x} }
		   @{$curse->{windows}[0]{keylist}} ];
	for (my $kp = 0; $kp < @{$curse->{windows}[0]{keylist}}; $kp++) {
	    my $k = $curse->{windows}[0]{keylist}[$kp];
	    push @{$curse->{windows}[0]{keyrows}[$k->{y}]}, $kp;
	    push @{$curse->{windows}[0]{keycols}[$k->{x}]}, $kp;
	    # a double-width key will be also added to the next column
	    my $sc = $k->{x} + 1;
	    my $ec = $k->{x} + $k->{width} - 1;
	    my %seen;
	    for (my $op = 0; $op < @{$curse->{windows}[0]{keylist}}; $op++) {
		my $o = $curse->{windows}[0]{keylist}[$op];
		my $so = $o->{x};
		$so < $sc  || $so > $ec and next;
		$seen{$so} and next;
		$seen{$so} = 1;
		push @{$curse->{windows}[0]{keycols}[$so]}, $kp;
	    }
	}
    }
}

sub _finish_window {
    my ($curse, $window) = @_;
    _setup_keymaps($curse);
    if (@{$curse->{windows}[0]{keylist}}) {
	my $nmenu = @{$curse->{windows}[0]{menu_keys} || []};
	$curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[$nmenu];
	$curse->{windows}[0]{lastkey}[0] = $nmenu;
    } else {
	$curse->{windows}[0]{lastkey} = [0, 0];
    }
    $curse->{windows}[0]{prevkey} = 0;
    $window;
}

sub show {
    @_ == 2 or croak "Usage: Curses->show(WINDOW)";
    my ($curse, $window) = @_;
    &{$window->{show}}($curse, $window, 0);
}

sub enable {
    @_ == 2 or croak "Usage: Curses->enable(WINDOW)";
    my ($curse, $window) = @_;
    $window->{enabled} = 1;
    $curse->{redraw} = 1;
}

sub disable {
    @_ == 2 or croak "Usage: Curses->disable(WINDOW)";
    my ($curse, $window) = @_;
    $window->{enabled} = 0;
    $curse->{redraw} = 1;
}

sub update {
    @_ == 1 or croak "Usage: Curses->update";
    my ($curse) = @_;
    refresh();
}

sub start {
    @_ == 1 or croak "Usage: Curses->start";
    refresh();
}

sub run {
    @_ == 1 or croak "Usage: Curses->run";
    my ($curse) = @_;
    $curse->{running} = 1;
    refresh();
    nodelay(1);
    while ($curse->{running}) {
	if ($curse->{resize}) {
	    $curse->{resize} = $curse->{redraw} = 0;
	    endwin();
	    clearok(1);
	    $curse->_redraw(1);
	} elsif ($curse->{redraw}) {
	    $curse->{redraw} = 0;
	    $curse->_redraw(0);
	}
	while (! @{$curse->{pending}}) {
	    move($LINES - 1, $COLS - 1);
	    refresh();
	    _get_keys($curse);
	    while (! @{$curse->{pending}}) {
		# SIGWINCH *may* interrupt the select in progress() but it all
		# depends on the system; we we wait at most 1 second then we
		# check for events anyway
		$curse->{server}->progress(1);
		_get_keys($curse);
	    }
	}
	my $key = shift @{$curse->{pending}};
	if (! defined $key || ($key->[0] && defined \&KEY_RESIZE && $key->[1] == &KEY_RESIZE)) {
	    $curse->{resize} = $curse->{redraw} = 1;
	    next;
	}
	if ($key->[0] && defined \&KEY_REFRESH && $key->[1] == &KEY_REFRESH) {
	    $curse->{redraw} = 1;
	    next;
	}
	if ($key->[0] && defined \&KEY_MOUSE && $key->[1] == &KEY_MOUSE) {
	    eval {
		my $ev;
		# in theory, one keeps calling getmouse() until it returns ERR,
		# however on OpenBSD (and probably other OSs) it keeps repeating
		# the last event forever: so we just call it once and hope we
		# get another KEY_MOUSE with the next event
		if (getmouse($ev) == OK) {
		    # in theory, $ev is a short followed by three ints and a mask
		    # however we need to figure out where the ints start, and that
		    # means guessing the alignment. This is the kind of things the
		    # XS could easily have done for us... we'll assume that the
		    # ints are aligned unless we hear evidence to the contrary;
		    # the last field, buttons, is an mmask_t and we have no idea
		    # what the C compiler will have made of that, so we'll get
		    # all the bytes at the end of the structure and use bitwise
		    # operations to get that.
		    my ($id, $mx, $my, $mz, $event) = unpack('iiiia*', $ev);
		    # big-endian workaround; still think it'd be much better if
		    # the XS did that as they have all the information we don't
		    if (length($event) != length($curse->{mouse_button}) && $Config{byteorder} !~ /^1234/) {
			if (length($event) < length($curse->{mouse_button})) {
			    substr($curse->{mouse_button}, 0, length($curse->{mouse_button}) - length($event)) = '';
			} else {
			    $curse->{mouse_button} .= "\000" x  (length($event) - length($curse->{mouse_button}));
			}
		    }
		    my $btn = ($event & $curse->{mouse_button}) =~ /[^\000]/;
		    my $pos = 0;
		    FIND_KEY: while (1) {
			my $keylist = $curse->{windows}[$pos]{keylist};
			for (my $kp = 0; $kp < @$keylist; $kp++) {
			    my $key = $keylist->[$kp];
			    $key->{type} eq 'key' or next;
			    $key->{x} <= $mx or next;
			    $key->{y} <= $my or next;
			    $key->{x} + $key->{width} > $mx or next;
			    $key->{y} + $key->{height} > $my or next;
			    $key->{enabled} or last;
			    # OK, we found where the mouse is; if we were in a menu
			    # and they clicked outside it, close the menu first; if
			    # the mouse is outside the menu and they didn't click,
			    # ignore this event
			    if ($pos > 0) {
				$btn or last FIND_KEY;
				$curse->close($curse->{windows}[0]{in_menu});
				# if the click is on the current menu, just close it
				$curse->{windows}[0]{lastkey}[0] == $kp and last FIND_KEY;
				# otherwise continue, which may open another menu etc
			    }
			    if ($curse->{windows}[0]{lastkey}[0] != $kp) {
				my $ok = $curse->{windows}[0]{lastkey}[1];
				$curse->{windows}[0]{lastkey}[0] = $kp;
				$curse->{windows}[0]{lastkey}[1] = $key;
				$curse->show($ok);
			    }
			    $curse->show($key);
			    @{$curse->{pending}} or $curse->{server}->progress(0);
			    @{$curse->{pending}} or refresh();
			    if ($btn) {
				my $res = $key->{action}->();
				$curse->{windows}[0]{after_act}
				    and $curse->{windows}[0]{after_act}($curse, $res);
				@{$curse->{pending}} or $curse->{server}->progress(0);
				@{$curse->{pending}} or refresh();
			    }
			    last FIND_KEY;
			}
			# we haven't found any key yet, but if we are in a menu we
			# can try the parent keyboard
			$pos > 0 and last FIND_KEY;
			$curse->{windows}[0]{in_menu} or last FIND_KEY;
			$pos++;
			$pos < @{$curse->{windows}} or last FIND_KEY;
		    }
		}
	    };
	    next;
	}
	if (exists $reserved[$key->[0]]{$key->[1]}) {
	    &{$reserved[$key->[0]]{$key->[1]}}($curse);
	    next;
	}
	if (exists $curse->{windows}[0]{keypress}[$key->[0]]{$key->[1]}) {
	    $key = $curse->{windows}[0]{keypress}[$key->[0]]{$key->[1]};
	    next unless $key->{enabled};
	    if ($curse->{windows}[0]{lastkey}[1] != $key && ! $key->{hidden}) {
		my $ok = $curse->{windows}[0]{lastkey}[1];
		$curse->{windows}[0]{lastkey}[0] >= @{$curse->{windows}[0]{menu_keys} || []}
		    and $curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
		$curse->{windows}[0]{lastkey}[1] = $key;
		for (my $kp = 0; $kp < @{$curse->{windows}[0]{keylist}}; $kp++) {
		    next if $curse->{windows}[0]{keylist}[$kp] != $key;
		    $curse->{windows}[0]{lastkey}[0] = $kp;
		}
		$curse->show($ok);
	    }
	    $curse->show($key) unless $key->{hidden};
	    $curse->{server}->progress(0) if ! @{$curse->{pending}};
	    refresh() if ! @{$curse->{pending}};
	    my $res = &{$key->{action}};
	    $curse->{windows}[0]{after_act}
		and $curse->{windows}[0]{after_act}($curse, $res);
	    $curse->{server}->progress(0) if ! @{$curse->{pending}};
	    refresh() if ! @{$curse->{pending}};
	    next;
	}
	if (! $key->[0] && $key->[1] =~ /^[[:print:]]$/ && $curse->{windows}[0]{in_dialog}) {
	    ${$curse->{windows}[0]{in_dialog}} .= $key->[1];
	    $curse->set_text('__getline', ${$curse->{windows}[0]{in_dialog}});
	    # XXX need to have the cursor in the dialog
	    $curse->update;
	    next;
	}
    }
}

sub stop {
    @_ == 1 or croak "Usage: Curses->stop";
    my ($curse) = @_;
    $curse->{running} = 0;
}

sub pending_events {
    @_ == 1 or croak "Usage: Curses->pending_events";
    my ($curse) = @_;
    @{$curse->{pending}} or $curse->{server}->progress(0);
    return @{$curse->{pending}} != 0;
}

sub _activate {
    my ($curse) = @_;
    if ($curse->{windows}[0]{in_dialog}) {
	$curse->{running} = 0;
	return;
    }
    return unless $curse->{windows}[0]{lastkey}[1];
    return unless $curse->{windows}[0]{lastkey}[1]->{enabled};
    &{$curse->{windows}[0]{lastkey}[1]->{action}};
}

sub _swap_menu_and_keypad {
    my ($curse) = @_;
    return unless $curse->{windows}[0]{lastkey}[1];
    my $nmenu = @{$curse->{windows}[0]{menu_keys} || []};
    my $i = $curse->{windows}[0]{lastkey}[0];
    my $o = $curse->{windows}[0]{lastkey}[1];
    if ($i < $nmenu) {
	# return to keypad
	$curse->{windows}[0]{prevkey} and $nmenu = $curse->{windows}[0]{prevkey};
	$curse->{windows}[0]{lastkey}[0] = $nmenu;
	$curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[$nmenu];
    } else {
	# go to menu
	$curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
	$curse->{windows}[0]{lastkey}[0] = 0;
	$curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[0];
    }
    $curse->show($o);
    $curse->show($curse->{windows}[0]{lastkey}[1]);
    undef;
}

sub _move_left {
    my ($curse) = @_;
    if ($curse->{windows}[0]{in_menu}) {
	# close this menu, then open the one on the left
	$curse->close($curse->{windows}[0]{in_menu});
	$curse->{windows}[0]{in_menu} = 0;
	return unless $curse->{windows}[0]{lastkey}[1];
	_move_left($curse);
	_activate($curse);
	return;
    }
    return unless $curse->{windows}[0]{lastkey}[1];
    my $i = $curse->{windows}[0]{lastkey}[0];
    my $k = $curse->{windows}[0]{lastkey}[1];
    my $r = $curse->{windows}[0]{keyrows}[$k->{y}];
    my $ok = $curse->{windows}[0]{lastkey}[1];
    if ($r->[0] == $i) {
	$i = $#$r;
    } else {
	my $j = 1;
	$j++ while $j < @$r && $r->[$j] != $i;
	$j--;
	$i = $j;
    }
    $curse->{windows}[0]{lastkey}[0] >= @{$curse->{windows}[0]{menu_keys} || []}
	and $curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
    $curse->{windows}[0]{lastkey}[0] = $r->[$i];
    $curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[$r->[$i]];
    $curse->show($ok);
    $curse->show($curse->{windows}[0]{lastkey}[1]);
}

sub _move_right {
    my ($curse) = @_;
    if ($curse->{windows}[0]{in_menu}) {
	# close this menu, then open the one on the left
	$curse->close($curse->{windows}[0]{in_menu});
	$curse->{windows}[0]{in_menu} = 0;
	return unless $curse->{windows}[0]{lastkey}[1];
	_move_right($curse);
	_activate($curse);
	return;
    }
    return unless $curse->{windows}[0]{lastkey}[1];
    my $i = $curse->{windows}[0]{lastkey}[0];
    my $k = $curse->{windows}[0]{lastkey}[1];
    my $r = $curse->{windows}[0]{keyrows}[$k->{y}];
    my $ok = $curse->{windows}[0]{lastkey}[1];
    if ($r->[-1] == $i) {
	$i = 0;
    } else {
	my $j = $#$r;
	$j-- while $j >= 0 && $r->[$j] != $i;
	$j++;
	$i = $j;
    }
    $curse->{windows}[0]{lastkey}[0] >= @{$curse->{windows}[0]{menu_keys} || []}
	and $curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
    $curse->{windows}[0]{lastkey}[0] = $r->[$i];
    $curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[$r->[$i]];
    $curse->show($ok);
    $curse->show($curse->{windows}[0]{lastkey}[1]);
}

sub _move_up {
    my ($curse) = @_;
    return unless $curse->{windows}[0]{lastkey}[1];
    my $nmenu = @{$curse->{windows}[0]{menu_keys} || []};
    my $i = $curse->{windows}[0]{lastkey}[0];
    return if $i < $nmenu;
    my $k = $curse->{windows}[0]{lastkey}[1];
    my $r = $curse->{windows}[0]{keycols}[$k->{x}];
    my $ok = $curse->{windows}[0]{lastkey}[1];
    my $idx = 0;
    $idx++ while $idx < @$r && $r->[$idx] < $nmenu;
    if ($r->[$idx] == $i) {
	$i = $#$r;
    } else {
	my $j = 1;
	$j++ while $j < @$r && $r->[$j] != $i;
	$j--;
	$i = $j;
    }
    $curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
    $curse->{windows}[0]{lastkey}[0] = $r->[$i];
    $curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[$r->[$i]];
    $curse->show($ok);
    $curse->show($curse->{windows}[0]{lastkey}[1]);
}

sub _down_until {
    my ($curse, $until) = @_;
    return unless $curse->{windows}[0]{lastkey}[1];
    my $i = $curse->{windows}[0]{lastkey}[0];
    do {
	_move_down($curse);
    } until $curse->{windows}[0]{lastkey}[0] == $i
	 || $curse->{windows}[0]{lastkey}[1]->{value} =~ $until;
}

sub _move_down {
    my ($curse) = @_;
    return unless $curse->{windows}[0]{lastkey}[1];
    my $i = $curse->{windows}[0]{lastkey}[0];
    my $nmenu = @{$curse->{windows}[0]{menu_keys} || []};
    if ($i < $nmenu) {
	# open this menu
	_activate($curse);
	return;
    }
    my $k = $curse->{windows}[0]{lastkey}[1];
    my $r = $curse->{windows}[0]{keycols}[$k->{x}];
    my $ok = $curse->{windows}[0]{lastkey}[1];
    my $idx = 0;
    $idx++ while $idx < @$r && $r->[$idx] < $nmenu;
    if ($r->[-1] == $i) {
	$i = $idx;
    } else {
	my $j = $#$r;
	$j-- while $j >= 0 && $r->[$j] != $i;
	$j++;
	$i = $j;
    }
    $curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
    $curse->{windows}[0]{lastkey}[0] = $r->[$i];
    $curse->{windows}[0]{lastkey}[1] = $curse->{windows}[0]{keylist}[$r->[$i]];
    $curse->show($ok);
    $curse->show($curse->{windows}[0]{lastkey}[1]);
}

sub _redraw {
    my ($curse, $place) = @_;
    erase();
    $place and refresh();
    $@ = '';
    delete $curse->{too_narrow};
    delete $curse->{too_short};
    eval {
	for my $w (@{$curse->{windows}}) {
	    $place and _place($w->{window}, 0, $COLS, 0, $LINES);
	    &{$w->{window}{show}}($curse, $w->{window}, $place);
	}
	$place and _setup_keymaps($curse);
	if ($curse->{too_narrow} || $curse->{too_short}) {
	    my @msg;
	    $curse->{too_narrow} and push @msg, 'narrow';
	    $curse->{too_short} and push @msg, 'short';
	    my $msg = 'Screen is too ' . join(' and ', @msg) . ' for this content';
	    if (length($msg) < $COLS) {
		$msg = " $msg ";
		if (length($msg) < $COLS) {
		    my $diff = $COLS - length($msg);
		    my $d0 = int($diff / 2);
		    my $d1 = $diff - $d0;
		    $msg = '*' x $d0 . $msg . '*' x $d1;
		}
	    }
	    _addstr($curse, 'MESSAGES', $LINES - 1, 0, substr($msg, 0, $COLS));
	}
    };
    if ($@) {
	clearok(1);
	erase();
	my $line = 0;
	for my $s (split(/\n/, $@)) {
	    _addstr($curse, 'MESSAGES', $line++, 0, $s) if $line < $LINES;
	}
    }
    refresh();
}

sub _offset {
    my ($window, $x, $y) = @_;
    $window->{x} += $x;
    $window->{y} += $y;
    return unless exists $window->{children};
    for my $child (@{$window->{children}}) {
	_offset($child, $x, $y);
    }
}

sub _place {
    my ($window, $x, $width, $y, $height) = @_;
    my $diff = $width - $window->{width};
    $diff < 0 and $diff = 0;
    $x += int($diff / 2);
    $window->{x} ||= 0;
    $diff = $height - $window->{height};
    $diff < 0 and $diff = 0;
    $y += int($diff / 2);
    $window->{y} ||= 0;
    _offset($window, $x - $window->{x}, $y - $window->{y});
}

sub close {
    @_ == 2 or croak "Usage: Curses->close(WINDOW)";
    my ($curse, $window) = @_;
    $curse->_close($window->{wid});
    my @nw = grep { $_->{window} != $window } @{$curse->{windows}};
    $curse->{windows} = \@nw;
    $curse->_redraw(0);
}

sub _extend_width {
    my ($e, $cw) = @_;
    return if $e->{width} >= $cw;
    my $diff = $cw - $e->{width};
    $e->{width} = $cw;
    return unless exists $e->{children};
    my $d0 = int($diff / scalar @{$e->{colwidth}});
    my $d1 = $diff % scalar @{$e->{colwidth}};
    my $d = 0;
    my @d = ();
    for (my $c = 0; $c < @{$e->{colwidth}}; $c++) {
	$d[$c] = $d;
	$d += $d0 + (($c < $d1) ? 1 : 0);
	$e->{colwidth}[$c] += $d0 + (($c < $d1) ? 1 : 0);
    }
    for my $child (@{$e->{children}}) {
	my ($c0, $c1, $r0, $r1) = @{$child->{table}};
	$d = -$e->{border};
	for (my $c = $c0; $c < $c1; $c++) {
	    $d += $e->{colwidth}[$c] + $e->{border};
	}
	_extend_width($child, $d);
	_offset($child, $d[$c0], 0);
    }
}

sub _extend_height {
    my ($e, $rh) = @_;
    return if $e->{height} >= $rh;
    my $diff = $rh - $e->{height};
    $e->{height} = $rh;
    return unless exists $e->{children};
    my $d0 = int($diff / scalar @{$e->{rowheight}});
    my $d1 = $diff % scalar @{$e->{rowheight}};
    my $d = 0;
    my @d = ();
    for (my $r = 0; $r < @{$e->{rowheight}}; $r++) {
	$d[$r] = $d;
	$d += $d0 + (($r < $d1) ? 1 : 0);
	$e->{rowheight}[$r] += $d0 + (($r < $d1) ? 1 : 0);
    }
    for my $child (@{$e->{children}}) {
	my ($c0, $c1, $r0, $r1) = @{$child->{table}};
	$d = -$e->{border};
	for (my $r = $r0; $r < $r1; $r++) {
	    $d += $e->{rowheight}[$r] + $e->{border};
	}
	_extend_height($child, $d);
	_offset($child, 0, $d[$r0]);
    }
}

sub _make_table {
    my ($curse, $rows, $cols, $elements, $border, $augment) = @_;
    my @width = (0) x $cols;
    my @height = (0) x $rows;
    $border = $border ? 1 : 0;
    # try to determine row/column sizes using one cell elements
    for my $te (@$elements) {
	my ($e, $c0, $c1, $r0, $r1) = @$te;
	$width[$c0] = $e->{width}
	    if $c0 + 1 == $c1 && $width[$c0] < $e->{width};
	$height[$r0] = $e->{height}
	    if $r0 + 1 == $r1 && $height[$r0] < $e->{height};
    }
    # now adjust it for multirow/multicolumn
    for my $te (@$elements) {
	my ($e, $c0, $c1, $r0, $r1) = @$te;
	if ($c1 - $c0 > 1) {
	    my $cw = ($c1 - $c0 - 1) * $border;
	    for (my $c = $c0; $c < $c1; $c++) {
		$cw += $width[$c];
	    }
	    if ($cw < $e->{width}) {
		my $diff = $e->{width} - $cw;
		my $d0 = int($diff / ($c1 - $c0));
		my $d1 = $diff % ($c1 - $c0);
		for (my $c = $c0; $c < $c1; $c++) {
		    $width[$c] += $d0;
		    $width[$c] ++ if $c < $d1;
		}
	    }
	}
	if ($r1 - $r0 > 1) {
	    my $rh = ($r1 - $r0 - 1) * $border;
	    for (my $r = $r0; $r < $r1; $r++) {
		$rh += $height[$r];
	    }
	    if ($rh < $e->{height}) {
		my $diff = $e->{height} - $rh;
		my $d0 = int($diff / ($r1 - $r0));
		my $d1 = $diff % ($r1 - $r0);
		for (my $r = $r0; $r < $r1; $r++) {
		    $height[$r] += $d0;
		    $height[$r] ++ if $r < $d1;
		}
	    }
	}
    }
    # determine total window size and cell starting points
    my $width = $border;
    my @x = ();
    for (my $c = 0; $c < $cols; $c++) {
	$x[$c] = $width;
	$width += $width[$c] + $border;
    }
    my $height = $border;
    my @y = ();
    for (my $r = 0; $r < $rows; $r++) {
	$y[$r] = $height;
	$height += $height[$r] + $border;
    }
    # place all elements and extend them to fill cell if required
    my @children = ();
    for my $te (@$elements) {
	my ($e, $c0, $c1, $r0, $r1) = @$te;
	_offset($e, $x[$c0], $y[$r0]);
	my $cw = ($c1 - $c0 - 1) * $border;
	for (my $c = $c0; $c < $c1; $c++) {
	    $cw += $width[$c];
	}
	_extend_width($e, $cw);
	my $rh = ($r1 - $r0 - 1) * $border;
	for (my $r = $r0; $r < $r1; $r++) {
	    $rh += $height[$r];
	}
	_extend_height($e, $rh);
	$e->{table} = [$c0, $c1, $r0, $r1];
	push @children, $e;
    }
    # ready to go...
    return {
	type => 'table',
	width => $width,
	height => $height,
	colwidth => \@width,
	rowheight => \@height,
	show => \&_show_table,
	children => \@children,
	border => $border,
    };
}

sub _set_border {
    my ($curse, $table) = @_;
    # get the information necessary to draw borders
    my $linechars = $curse->{frame};
    my (@border_data, @tmpdata);
    for my $c (@{$table->{children}}) {
	my $y = $c->{y};
	my $h = $c->{height};
	my $w = $c->{width};
	my $x = $c->{x};
	# top left corner of cell
	$tmpdata[$y][$x] |= 0x6;
	# top right corner of cell
	$tmpdata[$y][$x + $w + 1] |= 0xc;
	# bottom right corner of cell
	$tmpdata[$y + $h + 1][$x] |= 0x3;
	# bottom right corner of cell
	$tmpdata[$y + $h + 1][$x + $w + 1] |= 0x9;
	# vertical lines before and after cell
	for (my $p = 0; $p < $h; $p++) {
	    $tmpdata[$y + $p + 1][$x] |= 0x5;
	    $tmpdata[$y + $p + 1][$x + $w + 1] |= 0x5;
	}
	# horizontal lines above and below cell
	for (my $p = 0; $p < $w; $p++) {
	    $tmpdata[$y][$x + $p + 1] |= 0xa;
	    $tmpdata[$y + $h + 1][$x + $p + 1] |= 0xa;
	}
    }
    for (my $y = 0; $y < @tmpdata; $y++) {
	my $r = $tmpdata[$y];
	$r or next;
	my $x = 0;
	$x++ while $x < @$r && ! defined $r->[$x];
	$x < @$r or next;
	my $l = '';
	for (my $z = $x; $z < @$r; $z++) {
	    # XXX hline() and vline() don't seem to work at least with ncurses
	    # XXX ACS_x are all 0 so there's no way to tell a corner from a
	    # XXX line from anything else; we'll use normal characters for now
	    $l .= substr($linechars, $r->[$z] || 0, 1);
	}
	push @border_data, [$y - 1, $x - 1, $l];
    }
    $table->{border_data} = \@border_data;
}

sub _addstr {
    my ($curse, $style, $y, $x, $s, $len) = @_;
    defined $len or $len = length($s);
    if ($x + $len > $COLS) {
	$s = substr($s, 0, $COLS);
	$curse->{too_narrow} = 1;
    }
    if ($y < $LINES) {
	my @attr = @{$curse->{styles}{$style} || []};
	attrset(A_NORMAL);
	attron($_) for @attr;
	addstring($y, $x, $s);
	attroff(pop @attr) while @attr;
	attrset(A_NORMAL);
    } else {
	$curse->{too_short} = 1;
    }
}

sub _show_table {
    my ($curse, $table, $place) = @_;
    $table->{type} eq 'table' or die "Internal error";
    # draw border, if required
    if ($table->{border}) {
	$place || ! exists $table->{border_data} and _set_border($curse, $table);
	for my $b (@{$table->{border_data}}) {
	    my ($by, $bx, $bp) = @$b;
	    _addstr($curse, 'FRAMES', $by, $bx, $bp);
	}
    }
    # draw elements
    for my $e (@{$table->{children}}) {
	&{$e->{show}}($curse, $e, $place);
    }
}

sub _make_text {
    my ($curse, $value, $align, $size) = @_;
    $size ||= length $value;
    return {
	type => 'text',
	width => $size,
	height => 1,
	value => $value,
	enabled => 1,
	align => $align,
	show => \&_show_text_key,
    };
}

sub _show_text_key {
    my ($curse, $text, $place) = @_;
    $text->{type} eq 'text' || $text->{type} eq 'key'
	or die "Internal error";
    my $s = $text->{value};
    my $diff0 = $text->{width} - length($s);
    my $diff1 = int($diff0 / 2);
    my $diff2 = $diff0 - $diff1;
    my $pre = '';
    $pre .= ' ' x $diff0 if $diff0 > 0 && $text->{align} =~ /^r/i;
    $pre .= ' ' x $diff1 if $diff1 > 0 && $text->{align} =~ /^c/i;
    my $post = '';
    $post .= ' ' x $diff0 if $diff0 > 0 && $text->{align} =~ /^l/i;
    $post .= ' ' x $diff2 if $diff2 > 0 && $text->{align} =~ /^c/i;
    my $attribute = 'MESSAGES';
    $text->{type} eq 'key'
	and $attribute = ($text->{enabled} ? 'ENABLED' : 'DISABLED')
		       . ($curse->{windows}[0]{in_menu} ||
		          $text->{position} < @{$curse->{windows}[0]{menu_keys} || []}
			  ? 'MENUS' : 'KEYS');
    $text == $curse->{windows}[0]{lastkey}[1] and $attribute = 'CURRENTITEM';
    _addstr($curse, $attribute, $text->{y}, $text->{x}, $pre . $s . $post, length($pre . $text->{value} . $post));
}

sub _set_text {
    my ($curse, $text, $value) = @_;
    $text->{type} eq 'text' or die "Internal error";
    defined $value or $value = '';
    $value = substr($value, 0, $text->{width});
    $text->{value} = $value;
    _show_text_key($curse, $text);
}

sub _get_text {
    my ($curse, $text) = @_;
    $text->{type} eq 'text' or die "Internal error";
    $text->{value};
}

sub _make_key {
    my ($curse, $label, $action, $keys) = @_;
    if ($curse->{windows}[0]{after_act}) {
	my $act = $curse->{windows}[0]{after_act};
	my $cb = $action;
	$action = sub {
	      $@ = '';
	      my $res = eval { $cb->(@_); };
	      if ($act) {
		  $act->($curse, $@ || $res, @_);
	      } elsif ($@) {
		  die $@;
	      }
	};
    }
    my $key = {
	type => 'key',
	width => length $label,
	height => 1,
	action => $action,
	align => ($curse->{keyalign} || 'c'),
	enabled => 1,
	value => $label,
	position => scalar(@{$curse->{windows}[0]{keylist}}),
	show => \&_show_text_key,
    };
    push @{$curse->{windows}[0]{keylist}}, $key;
    for my $k (@$keys) {
	$k = $keymap{$k} if exists $keymap{$k};
	my $type = $k =~ /^\d{2,}$/;
	next if exists $reserved[$type]{$k};
	$curse->{windows}[0]{keypress}[$type]{$k} = $key;
    };
    return $key;
}

sub _make_menu {
    my ($curse, $name) = @_;
    $curse->{windows}[0]{menu_byname}{$name} = {};
    $curse->{windows}[0]{menu_entries}{$name} = [];
    my $key1 = 'M-' . lc(substr($name, 0, 1));
    my $key2 = 'M-' . uc(substr($name, 0, 1));
    $curse->{windows}[0]{menu_index}{$name} = scalar @{$curse->{windows}[0]{menu_keys}};
    push @{$curse->{windows}[0]{menu_keys}}, [
	'key',
	name => $name,
	action => sub { _show_menu($curse, $name) },
	key => [$key1, $key2],
    ];
    1;
}

sub _show_menu {
    my ($curse, $name, $place) = @_;
    # find this menu
    exists $curse->{windows}[0]{menu_index}{$name} or return;
    my $entry = $curse->{windows}[0]{menu_index}{$name};
    # check if menu has ticks
    my $c = $curse->{windows}[0]{menu_byname}{$name};
    my $ticks = grep { exists $_->{ticked} } values %$c;
    # get list of entries;
    my $e = $curse->{windows}[0]{menu_entries}{$name};
    my @entries = grep { $c->{$_->[0]}{enabled} } @$e;
    return unless @entries;
    if ($ticks) {
	@entries =
	    map { [($c->{$_->[0]}{ticked} ? '*' : ' ') . $_->[0],
		   $_->[0],
		   $_->[1]]
	        } @entries;
    } else {
	@entries = map { [$_->[0], $_->[0], $_->[1]] } @entries;
    }
    # determine menu size and draw window
    my $rows = scalar @entries;
    my $cols = 0;
    for my $e (@entries) {
	$cols = length($e->[0]) if $cols < length($e->[0]);
    }
    # now open a window under the menu label with the entries as a stack of buttons
    my $mw;
    my $act = $curse->{windows}[0]{after_act};
    my @keys = map {
	my ($label, $keyname, $action) = @$_;
	[ 'key',
	  action => sub {
	      $curse->close($mw);
	      $@ = '';
	      my $res = eval { $action->($curse, $name, @_); };
	      if ($act) {
		  $act->($curse, $@ || $res, $name, @_);
	      } elsif ($@) {
		  die $@;
	      }
	  },
	  name => $keyname,
	  label => $label,
	  key => [],
	],
    } @entries;
    my @wd = (
	'vstack',
	border => 1,
	data => [
	    'vstack',
	    border => 0,
	    data => @keys,
	],
    );
    my $k = $curse->{windows}[0]{keylist}[$entry];
    $curse->{windows}[0]{lastkey}[0] >= @{$curse->{windows}[0]{menu_keys} || []}
	and $curse->{windows}[0]{prevkey} = $curse->{windows}[0]{lastkey}[0];
    $curse->{windows}[0]{lastkey}[0] = $entry;
    $curse->{windows}[0]{lastkey}[1] = $k;
    $curse->{keyalign} = 'l';
    $mw = $curse->_window(\@wd);
    delete $curse->{keyalign};
    $curse->{windows}[0]{keypress}[0]{"\c["} = $curse->{windows}[0]{keypress}[0]{'`'} = {
	hidden => 1,
	action => sub { $curse->close($mw); undef },
	enabled => 1,
    };
    for my $ent (@entries) {
	my $initial = lc(substr($ent->[1], 0, 1));
	next if exists $curse->{windows}[0]{keypress}[0]{$initial};
	$curse->{windows}[0]{keypress}[0]{$initial} = {
	    hidden => 1,
	    enabled => 1,
	    action => sub { _down_until($curse, qr/^[\s\*]*$initial/i) },
	}
    }
    _offset($mw, $k->{x} - 1, $k->{y} + 1);
    _finish_window($curse, $mw);
    $curse->{windows}[0]{in_menu} = $mw;
    &{$mw->{show}}($curse, $mw, $place);
}

sub _make_menu_entry {
    my ($curse, $action, $menu, $name, $entry, $ticks) = @_;
    $curse->{windows}[0]{menu_byname}{$name}{$entry} = {
	action => $action,
	enabled => 1,
    };
    push @{$curse->{windows}[0]{menu_entries}{$name}}, [$entry, $action];
    1;
}

sub _enable_menu {
    my ($curse, $item, $state, $name, $entry) = @_;
    $curse->{windows}[0]{menu_byname}{$name}{$entry}{enabled} = $state;
    1;
}

sub _tick_menu {
    my ($curse, $item, $state, $name, $entry) = @_;
    $curse->{windows}[0]{menu_byname}{$name}{$entry}{ticked} = $state;
    1;
}

sub _menu_action {
    my ($curse, $item, $name, $entry) = @_;
    exists $curse->{windows}[0]{menu_byname}{$name}{$entry} or return 0;
    $curse->{windows}[0]{menu_byname}{$name}{$entry}{enabled} or return 0;
    my $action = $curse->{windows}[0]{menu_byname}{$name}{$entry}{action};
    $action or return 0;
    $action->($curse, $name, $entry);
}

1;
