package Language::INTERCAL::Interface::X;

# Graphical (Gtk2 or Gtk3) interface for sick and intercalc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/UI-X INTERCAL/Interface/X.pm 1.-94.-2") =~ /\s(\S+)$/;

my ($Gtk, $GtkAccelGroup, $GtkButton, $GtkCheckMenuItem, $GtkClipboard, $GtkDialog, $GtkEntry, $GtkFileChooserDialog, $GtkGdkAtom, $GtkLabel, $GtkMenu, $GtkMenuBar, $GtkMenuItem, $GtkWindow);
BEGIN {
    eval {
	require Gtk3;
	import Gtk3;
	$Gtk = 'Gtk3';
	*accelerator_parse = \&Gtk3::accelerator_parse;
	*events_pending = \&Gtk3::events_pending;
	*main_iteration = \&Gtk3::main_iteration;
	*table_new = sub { Gtk3::Table->new($_[0], $_[1], 0) };
	*vbox = sub { $_[0]->get_content_area };
    };
    defined $Gtk or eval {
	require Gtk2;
	import Gtk2;
	$Gtk = 'Gtk2';
	*accelerator_parse = sub { Gtk2::Accelerator->parse(@_) };
	*events_pending = sub { Gtk2->events_pending };
	*main_iteration = sub { Gtk2->main_iteration };
	*table_new = sub { Gtk2::Table->new($_[0], $_[1]) };
	*vbox = sub { $_[0]->vbox };
    };
    defined $Gtk or die "Cannot find either Gtk2 or Gtk3, giving up\n";
    $GtkAccelGroup = $Gtk . '::AccelGroup';
    $GtkButton = $Gtk . '::Button';
    $GtkCheckMenuItem = $Gtk . '::CheckMenuItem';
    $GtkClipboard = $Gtk . '::Clipboard';
    $GtkDialog = $Gtk . '::Dialog';
    $GtkEntry = $Gtk . '::Entry';
    $GtkFileChooserDialog = $Gtk . '::FileChooserDialog';
    $GtkGdkAtom = $Gtk . '::Gdk::Atom';
    $GtkLabel = $Gtk . '::Label';
    $GtkMenu = $Gtk . '::Menu';
    $GtkMenuBar = $Gtk . '::MenuBar';
    $GtkMenuItem = $Gtk . '::MenuItem';
    $GtkWindow = $Gtk . '::Window';
};

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Interface::common '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::Interface::common);

my %keymap = (
    ' ' => 'space',
    '!' => 'exclam',
    '"' => 'quotedbl',
    '#' => 'numbersign',
    "'" => 'apostrophe',
    '$' => 'dollar',
    '%' => 'percent',
    '&' => 'ampersand',
    '(' => 'parenleft',
    ')' => 'parenright',
    '*' => 'asterisk',
    '+' => 'plus',
    ',' => 'comma',
    '-' => 'minus',
    '.' => 'period',
    '/' => 'slash',
    ':' => 'colon',
    ';' => 'semicolon',
    '<' => 'less',
    '=' => 'equal',
    '>' => 'greater',
    '?' => 'question',
    '@' => 'at',
    '[' => 'bracketleft',
    '\\' => 'backslash',
    ']' => 'bracketright',
    '^' => 'asciicircum',
    '_' => 'underscore',
    '`' => 'grave',
    '{' => 'braceleft',
    '|' => 'bar',
    '}' => 'braceright',
    '~' => 'asciitilde',
    "\xa2" => 'cent',
    "\xa5" => 'yen',
    'Enter' => 'KP_Enter',
);

sub new {
    @_ == 2 or croak "Usage: Language::INTERCAL::Interface::X->new(SERVER)";
    my ($class, $server) = @_;
    $server or croak "Must provide SERVER";
    $ENV{DISPLAY} or return undef;
    $Gtk->init();
    # XXX there's probably a better way of doing this
    Glib::Timeout->add(100, sub { $server->progress(0); 1 });
    my $toplevel = $GtkWindow->new();
    my $X = bless {
	keylist => {},
	wid => 0,
	toplevel => $toplevel,
	topused => 0,
    }, $class;
    $X->_initialise;
    $X;
}

sub has_window { 1 }
sub is_interactive { 1 }
sub is_terminal { 1 }
sub can_paste { 1 }

sub stdread {
    croak "X interface should not use stdread directly";
}

sub getline {
    @_ == 2 or croak "Usage: X->getline(PROMPT)";
    my ($X, $prompt) = @_;
    my $d = $GtkDialog->new($prompt, undef,
			    [qw(modal destroy-with-parent)],
			    'Go ahead'   => 'accept',
			    'Give up'    => 'reject');
    my $vbox = vbox($d);
    my $t = $GtkLabel->new($prompt);
    $vbox->add($t);
    my $e = $GtkEntry->new;
    $vbox->add($e);
    $e->signal_connect(activate => sub {$d->response('accept')});
    $d->show_all;
    my $resp = $d->run;
    my $line = undef;
    if ($resp eq 'accept') {
	$line = $e->get_text() . "\n";
    }
    $d->destroy;
    return $line;
}

sub window {
    @_ == 4 || @_ == 5 || @_ == 6
	or croak "Usage: X->window(NAME, DESTROY, DEFINITION [, MENUS [, ACT]])";
    my ($X, $name, $destroy, $def, $menus, $act) = @_;
    my $window;
    if ($X->{topused}) {
	$window = $GtkWindow->new();
    } else {
	$window = $X->{toplevel};
	$window->resize(1, 1);
	$X->{toplist} = [];
    }
    $window->set_title($name);
    $X->{_accel} = $GtkAccelGroup->new();
    $X->{_act} = $act;
    $X->{_alter} = undef;
    delete $X->{_skip_table};
    my $wid = ++$X->{wid};
    my $table = undef;
    if (defined $menus) {
	$X->{_menubar} = $GtkMenuBar->new;
	$X->_parse_menus($wid, @$menus);
	$table = table_new(2, 1);
	if (! $X->{topused}) {
	    unshift @{$X->{toplist}}, $table;
	    unshift @{$X->{toplist}}, $X->{_menubar};
	}
	$table->set_border_width(0);
	$table->attach_defaults($X->{_menubar}, 0, 1, 0, 1);
	$window->add($table);
	delete $X->{_menubar};
    }
    my $content = $X->_parse_def($wid, @$def);
    if ($table) {
	$table->attach_defaults($content->[0], 0, 1, 1, 2);
    } else {
	$window->add($content->[0]);
    }
    $window->add_accel_group($X->{_accel});
    my $alter = $X->{_alter} ? $X->{_alter}[0] : undef;
    delete $X->{_alter};
    delete $X->{_accel};
    delete $X->{_act};
    my $code;
    if ($act) {
	$code = sub {
	    my $res = eval { &$destroy; };
	    $act->($X, $@ || $res, @_);
	    1;
	}
    } elsif ($destroy) {
	$code = sub {
	    &$destroy;
	    0;
	}
    } else {
	$code = sub { 1 };
    }
    $window->signal_connect(delete_event => $code);
    $window->show_all;
    $X->{topused} = 1;
    [$window, $wid, $alter];
}

sub alter_data {
    @_ == 3 or croak "Usage: X->alter_data(WINDOW, DATA)";
    my ($X, $window, $data) = @_;
    $window->[2] or croak "Not alterable";
    my $table = $window->[2];
    $X->{_alter} = undef;
    $X->{_skip_table} = 1;
    my $content = $X->_parse_def(0, @$data);
    $X->{_alter} or croak "Must provide a new alterable item";
    my @goner = $table->get_children;
    for my $goner (@goner) {
	$table->remove($goner);
    }
    my ($newtable, $newrows, $newcols, $newelements) = @{$X->{_alter}};
    delete $X->{_alter};
    delete $X->{_skip_table};
    $table->resize($newrows, $newcols);
    for my $te (@$newelements) {
	my ($e, $c0, $c1, $r0, $r1) = @$te;
	$table->attach_defaults($e->[0], $c0, $c1, $r0, $r1);
    }
    $table->show_all;
    $X;
}

sub show {
    @_ == 2 or croak "Usage: X->show(WINDOW)";
    my ($X, $window) = @_;
    $window->[0]->set_keep_above(1);
    $window->[0]->deiconify;
    $window->[0]->show_all;
    $window->[0]->set_keep_above(0);
    $window;
}

sub start {
    @_ == 1 or croak "Usage: X->start";
    my ($X) = @_;
    main_iteration() while events_pending();
}

sub run {
    @_ == 1 or croak "Usage: X->run";
    my ($X) = @_;
    $Gtk->main;
}

sub stop {
    @_ == 1 or croak "Usage: X->stop";
    my ($X) = @_;
    $Gtk->main_quit if $Gtk->main_level > 0;
}

sub pending_events {
    @_ == 1 or croak "Usage: X->pending_events";
    return 0; # XXX
    return events_pending();
}

sub update {
    @_ == 1 or croak "Usage: X->update";
    my ($X) = @_;
    main_iteration() while events_pending();
}

sub has_paste {
    @_ == 1 or croak "Usage: X->has_paste";
    my ($X) = @_;
    my $clipboard = $GtkClipboard->get($GtkGdkAtom->new('PRIMARY'));
    return $clipboard->wait_is_text_available;
}

sub do_paste {
    @_ == 1 or croak "Usage: X->do_paste";
    my ($X) = @_;
    my $clipboard = $GtkClipboard->get($GtkGdkAtom->new('PRIMARY'));
    $clipboard->wait_is_text_available or return;
    my $text = $clipboard->wait_for_text;
    while ($text ne '') {
	my $k = substr($text, 0, 1, '');
	&{$X->{keylist}{$k}} if exists $X->{keylist}{$k};
	main_iteration() while events_pending();
    }
}

sub _set_text {
    my ($X, $text, $value) = @_;
    $text->[0]->set_label($value);
}

sub _get_text {
    @_ == 2 or croak "Usage: X->get_text(NAME)";
    my ($X, $text) = @_;
    $text->[0]->get_label();
}

sub close {
    @_ == 2 or croak "Usage: X->close(WINDOW)";
    my ($X, $window) = @_;
    if ($window->[0] == $X->{toplevel}) {
	# we never close the main window - otherwise when they change mode
	# or reload the compiler the main window gets closed and may be
	# reopened in a different screen / location which I find annoying
	# and I assume other people may find annoying too.
	$_->destroy for @{$X->{toplist}};
	$X->{topused} = 0;
    } else {
	$X->_close($window->[1]);
	$window->[0]->destroy;
    }
}

sub enable {
    @_ == 2 or croak "Usage: X->enable(BUTTON)";
    my ($X, $button) = @_;
    ref $button->[1] or die "Cannot enable this element\n";
    $button->[0]->set_relief('normal');
    ${$button->[1]} = 1;
}

sub disable {
    @_ == 2 or croak "Usage: X->disable(BUTTON)";
    my ($X, $button) = @_;
    ref $button->[1] or die "Cannot disable this element\n";
    $button->[0]->set_relief('none');
    ${$button->[1]} = 0;
}

sub file_dialog {
    @_ == 5 or croak "Usage: X->file_dialog(TITLE, NEW?, OK, CANCEL)";
    my ($X, $title, $new, $ok, $cancel) = @_;
    my $window = $GtkWindow->new();
    my @acts = (
	(defined $new ? 'save' : 'open'),
	$ok => 'accept',
	$cancel => 'cancel',
    );
    my $dialog = $GtkFileChooserDialog->new($title, $window, @acts);
    $new and $dialog->set_filename($new);
    my $resp = $dialog->run;
    my $file = undef;
    if ($resp eq 'accept') {
	$file = $dialog->get_filename;
    }
    $dialog->destroy;
    $file;
}

sub _make_table {
    my ($X, $rows, $cols, $elements, $border, $alter) = @_;
    my $table = $alter && $X->{_skip_table}
	      ? undef
	      : table_new($rows, $cols);
    unshift @{$X->{toplist}}, $table if ! $X->{topused};
    $X->{_alter} = [$table, $rows, $cols, $elements] if $alter;
    defined $table or return [0, 0];
    $table->set_border_width($border);
    for my $te (@$elements) {
	my ($e, $c0, $c1, $r0, $r1) = @$te;
	$table->attach_defaults($e->[0], $c0, $c1, $r0, $r1);
    }
    [$table, 0];
}

sub _make_text {
    my ($X, $value, $align, $size) = @_;
    my $text = $GtkLabel->new($value);
    unshift @{$X->{toplist}}, $text if ! $X->{topused};
    $text->set_width_chars($size) if $size;
    $text->set_max_width_chars($size) if $size;
    $text->set_alignment(0.0, 0.0) if $align =~ /^l/i;
    $text->set_alignment(0.5, 0.0) if $align =~ /^c/i;
    $text->set_alignment(1.0, 0.0) if $align =~ /^r/i;
    [$text, 0];
}

sub _make_key {
    my ($X, $label, $action, $keys) = @_;
    my $key = $GtkButton->new_with_label($label);
    unshift @{$X->{toplist}}, $key if ! $X->{topused};
    my $acode;
    my $enabled = 1;
    if ($X->{_act}) {
	my $act = $X->{_act};
	$acode = sub {
	      $@ = '';
	      $enabled or return;
	      my $res = eval { $action->(@_); };
	      $act->($X, $@ || $res, @_);
	};
    } else {
	$acode = sub {
	      $@ = '';
	      $enabled or return;
	      $action->(@_);
	};
    }
    $key->signal_connect(clicked => $acode);
    for my $k (@$keys) {
	$X->{keylist}{$k} = $action;
	$k =~ s/^([\c@-\c_])$/sprintf("<control>%c", 64 + ord($1))/e;
	$k =~ s/^([A-Z])$/sprintf("<shift>%c", 32 + ord($1))/e;
	$k = $keymap{$k} if exists $keymap{$k};
	my ($a, $m) = accelerator_parse($k);
die "k=$k a=$a m=$m\n" if $a == 0; # XXX
	my $fs = sub { $key->activate };
	$X->{_accel}->connect($a, $m, [], $fs);
    };
    [$key, \$enabled];
}

sub _make_menu {
    my ($X, $name) = @_;
    my $menu = $GtkMenu->new;
    my $item = $GtkMenuItem->new_with_label($name);
    $item->show;
    $X->{_menubar}->append($item);
    $item->set_submenu($menu);
    [$menu, 0];
}

sub _make_menu_entry {
    my ($X, $action, $menu, $name, $entry, $ticks) = @_;
    my $item;
    if ($ticks) {
	$item = $GtkCheckMenuItem->new_with_label($entry);
    } else {
	$item = $GtkMenuItem->new_with_label($entry);
    }
    $menu->[0]->append($item);
    my $enabled = 1;
    my $acode;
    if ($X->{_act}) {
	my $act = $X->{_act};
	$acode = sub {
	      $@ = '';
	      $enabled or return;
	      my $res = eval { $action->($X, $name, $entry); };
	      $act->($X, $@ || $res, @_);
	};
    } else {
	$acode = sub {
	      $enabled or return;
	      $action->($X, $name, $entry);
	};
    }
    $item->signal_connect(activate => $acode);
    $item->show;
    [$item, \$enabled, $ticks];
}

sub _enable_menu {
    my ($X, $item, $state, $name, $entry) = @_;
    ref $item->[1] or die "Cannot enable this menu\n";
    ${$item->[1]} = $state;
    $state ? $item->[0]->show : $item->[0]->hide;
    1;
}

sub _tick_menu {
    my ($X, $item, $state, $name, $entry) = @_;
    $item->[2] or die "Cannot tick this menu\n";
    my $ov = ${$item->[1]};
    ${$item->[1]} = 0;
    $item->[0]->set_active($state);
    ${$item->[1]} = $ov;
    1;
}

sub _menu_action {
    my ($X, $item, $name, $entry) = @_;
    $item->activate;
}

1;
