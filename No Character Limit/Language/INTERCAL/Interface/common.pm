package Language::INTERCAL::Interface::common;

# Base class for all interface; not to be used directly

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Interface/common.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import has_type);

sub name {
    @_ == 1 or croak "Usage: INTERFACE->name";
    my ($obj) = @_;
    my $r = ref $obj or croak "INTERFACE is not a reference";
    $r =~ s/^Language::INTERCAL::Interface::// or croak "INTERFACE is not an interface\n";
    $r;
}

sub _initialise {
    my ($intf) = @_;
    $intf->{common} = {
	keylist => [],
	text => {},
    };
}

sub _parse_def {
    my $intf = shift;
    my $wid = shift;
    @_ or croak "Invalid empty definition";
    my $type = lc(shift);
    if ($type eq 'vstack' || $type eq 'hstack' || $type eq 'table') {
	my %options = (
	    border => 0,
	    alterable => 0,
	);
	$options{columns} = $options{rows} = undef if $type eq 'table';
	_getoptions($type, \%options, \@_, qw(data));
	if ($type eq 'table') {
	    defined $options{rows} || defined $options{columns}
		or croak "Table must specify either rows or columns";
	    defined $options{rows} && defined $options{columns}
		and croak "Table cannot specify both rows and columns";
	    defined $options{rows} && $options{rows} < 1
		and croak "Rows must be at least 1";
	    defined $options{columns} && $options{columns} < 1
		and croak "Columns must be at least 1";
	} elsif ($type eq 'vstack') {
	    $options{columns} = 1;
	} else {
	    $options{rows} = 1;
	}
	my $div = $options{rows} || $options{columns};
	@_ % $div
	    and croak "Invalid number of data items, not multiple of $div";
	my ($rows, $cols, $byrow);
	if (defined $options{rows}) {
	    $rows = $options{rows};
	    $cols = @_ / $rows;
	    $byrow = 1;
	} else {
	    $cols = $options{columns};
	    $rows = @_ / $cols;
	    $byrow = 0;
	}
	my ($row, $col) = (0, 0);
	# crude but it does the job; we save the entries then attach
	# them all at once, after we know which ones are multiline and/or
	# multicolumn; also, we can adapt the single _make_table method
	# for different styles of user interface without much effort
	my @table = ();
	while (@_) {
	    my $def = shift;
	    if (! ref $def) {
		if ($def =~ /^l/i) {
		    $col > 0 or croak "Invalid left reference";
		    $table[$col][$row] = $table[$col - 1][$row];
		    $table[$col][$row][2]++;
		} elsif ($def =~ /^u/i) {
		    $row > 0 or croak "Invalid up reference";
		    $table[$col][$row] = $table[$col][$row - 1];
		    $table[$col][$row][4]++;
		} else {
		    croak "$def: Invalid multicell entry";
		}
	    } else {
		my $e = $intf->_parse_def($wid, @$def);
		$table[$col][$row] = [$e, $col, $col + 1, $row, $row + 1, 0];
	    }
	    if ($byrow) {
		$row++;
		if ($row >= $rows) {
		    $col++;
		    $row = 0;
		}
	    } else {
		$col++;
		if ($col >= $cols) {
		    $row++;
		    $col = 0;
		}
	    }
	}
	# make a list out of this
	my @t = ();
	for my $tc (@table) {
	    for my $tr (@$tc) {
		next if $tr->[5];
		$tr->[5] = 1;
		push @t, $tr;
	    }
	}
	return $intf->_make_table($rows, $cols, \@t,
				  $options{border},
				  $options{alterable});
    }
    if ($type eq 'text') {
	my %options = (
	    value => '',
	    size => undef,
	    name => undef,
	    align => 'c',
	);
	_getoptions($type, \%options, \@_);
	$options{align} =~ /^[lrc]/i or croak "Invalid align";
	my $value = $options{value};
	my $text = $intf->_make_text($value, $options{align}, $options{size});
	$intf->{common}{text}{$options{name}} =
	    [$text, $options{align}, $options{size}, $wid]
		if defined $options{name};
	return $text;
    }
    if ($type eq 'key') {
	my %options = (
	    name => undef,
	    label => undef,
	    key => undef,
	    action => undef,
	);
	_getoptions($type, \%options, \@_);
	defined $options{key} or croak "key must specify a key sequence";
	defined $options{action} or croak "key must specify action";
	defined $options{name} or croak "key must specify name";
	$options{label} = $options{name}
	    if ! defined $options{label};
	my $action = sub {
	    &{$options{action}}($options{name});
	};
	my $k = ref $options{key} ? $options{key} : [$options{key}];
	my $key = $intf->_make_key($options{label}, $action, $k);
	push @{$intf->{common}{keylist}},
	    [$key, $options{name}, $k, $options{action}, $wid];
	return $key;
    }
    croak "Invalid definition: type=$type";
}

sub _close {
    my ($intf, $wid) = @_;
    @{$intf->{common}{keylist}} =
	grep { $_->[4] != $wid } @{$intf->{common}{keylist}};
    my @del = grep { $intf->{common}{text}{$_}[3] == $wid }
		   keys %{$intf->{common}{text}};
    delete $intf->{common}{text}{$_} for @del;
}

sub _parse_menus {
    @_ >= 3 or croak "Invalid menu, no entries";
    my ($intf, $wid, @defs) = @_;
    my %ticks = ();
    my %menu = ();
    my @menu = ();
    for my $def (@defs) {
	ref $def && has_type($def, 'ARRAY')
	    or croak "Invalid menu spec, must be an ARRAY reference";
	@$def or croak "Invalid empty menu spec";
	@$def >= 2 or croak "Invalid menu spec for $def->[0]: no entries";
	my ($name, @entries) = @$def;
	exists $menu{$name} and croak "Duplicate menu $name";
	my $menu = $intf->_make_menu($name);
	my $ml = [];
	my %md = ('' => [$menu, $ml]);
	my @items = ();
	for my $entry (@entries) {
	    ref $entry && has_type($entry, 'ARRAY')
		or croak "Invalid menu entry (in $name), "
		   . "must be an ARRAY reference";
	    my ($ename, @edata) = @$entry;
	    $ename eq '' and croak "Invalid entry (empty name) in $name";
	    exists $md{$ename} and croak "Duplicate entry $ename (in $name)";
	    my %options = (
		action => undef,
		enabled => undef,
		ticked => undef,
	    );
	    _getoptions('menu', \%options, \@edata);
	    push @items, [$ename, \%options];
	    $ticks{$name} = 1 if defined $options{ticked};
	}
	for my $item (@items) {
	    my ($ename, $options) = @$item;
	    my $item = $intf->_make_menu_entry($options->{action},
					       $menu, $name, $ename,
					       $ticks{$name});
	    $md{$ename} = $item;
	    push @$ml, $ename;
	    defined $options->{ticked}
		and $intf->_tick_menu($item, $options->{ticked}, $name, $ename);
	    defined $options->{enabled}
		and $intf->_enable_menu($item, $options->{enabled},
					$name, $ename);
	}
	$menu{$name} = \%md;
	push @menu, $name;
    }
    $intf->{common}{menu_hash} = \%menu;
    $intf->{common}{menu_list} = \@menu;
    $intf->{common}{menu_ticks} = \%ticks;
    $intf;
}

sub forall {
    @_ >= 3 or croak "Usage: INTERFACE->forall(TYPE, CODE, ...)";
    my $intf = shift;
    my $type = shift;
    if ($type eq 'key') {
	@_ == 1 or croak "Usage: INTERFACE->forall('key', CODE)";
	my $code = shift;
	for my $k (@{$intf->{common}{keylist}}) {
	    my ($key, $name, $shortcuts, $action) = @$k;
	    last unless $code->($intf, $key, $name, $action);
	}
    } elsif ($type eq 'menu') {
	@_ == 2 or croak "Usage: INTERFACE->forall('menu', NAME, CODE)";
	my $name = shift;
	my $code = shift;
	exists $intf->{common}{menu_hash}{$name} or croak "Invalid menu $name";
	my ($menu, $list) = @{$intf->{common}{menu_hash}{$name}{''}};
	for my $entry (@$list) {
	    last unless $code->($intf, $name, $entry, $menu,
				$intf->{common}{menu_hash}{$code}{$entry});
	}
    } else {
	croak "Invalid TYPE"; # XXX handle other types
    }
    $intf;
}

sub set_text {
    @_ == 3 or croak "Usage: INTERFACE->set_text(NAME, VALUE)";
    my ($intf, $name, $value) = @_;
    exists $intf->{common}{text}{$name} or croak "Unknown NAME $name";
    if (defined $intf->{common}{text}{$name}[2] &&
	length $value > $intf->{common}{text}{$name}[2])
    {
	if ($intf->{common}{text}{$name}[1] =~ /^l/i) {
	    $value = substr($value, -$intf->{common}{text}{$name}[2]);
	} else {
	    $value = substr($value, 0, $intf->{common}{text}{$name}[2]);
	}
    }
    $intf->_set_text($intf->{common}{text}{$name}[0], $value);
}

sub get_text {
    @_ == 2 or croak "Usage: INTERFACE->get_text(NAME)";
    my ($intf, $name) = @_;
    exists $intf->{common}{text}{$name} or croak "Unknown NAME";
    $intf->_get_text($intf->{common}{text}{$name}[0]);
}

sub menu_action {
    @_ == 3 or croak "Usage: INTERFACE->menu_action(MENU, ENTRY)";
    my ($intf, $menu, $entry) = @_;
    my $item = _find_menu($intf, $menu, $entry);
    $intf->_menu_action($item, $menu, $entry);
    $intf;
}

sub enable_menu {
    @_ == 4 or croak "Usage: INTERFACE->enable_menu(STATE, MENU, ENTRY)";
    my ($intf, $state, $menu, $entry) = @_;
    my $item = _find_menu($intf, $menu, $entry);
    $intf->_enable_menu($item, $state, $menu, $entry);
    $intf;
}

sub tick_menu {
    @_ == 4 or croak "Usage: INTERFACE->tick_menu(STATE, MENU, ENTRY)";
    my ($intf, $state, $menu, $entry) = @_;
    my $item = _find_menu($intf, $menu, $entry);
    $intf->_tick_menu($item, $state, $menu, $entry);
    $intf;
}

sub _find_menu {
    my ($intf, $menu, $entry) = @_;
    exists $intf->{common}{menu_hash}{$menu}
	or croak "Invalid menu name: $menu";
    exists $intf->{common}{menu_hash}{$menu}{$entry}
	or croak "No such entry in $menu: $entry";
    $intf->{common}{menu_hash}{$menu}{$entry};
}

sub _getoptions {
    my ($type, $options, $parms, @stop) = @_;
    my %stop = map { ($_ => 0) } @stop;
    while (@$parms) {
	my $opt = lc(shift @$parms);
	last if exists $stop{$opt};
	@$parms or croak "Missing argument to $opt";
	exists $options->{$opt} or croak "Invalid option for $type: $opt";
	$options->{$opt} = shift @$parms;
    }
}

1;
