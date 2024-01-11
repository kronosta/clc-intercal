package Language::INTERCAL::ICALC::Extend;

# extend RC file definitions for intercalc

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Rcfile '1.-94.-2.1';

use vars qw($VERSION $PERVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/ICALC INTERCAL/ICALC/Extend.pm 1.-94.-2.1") =~ /\s(\S+)$/;

@EXPORT_OK = qw(all_styles get_style get_frame);

my %elements = map { ($_ => undef) } qw(
    ENABLEDKEYS
    DISABLEDKEYS
    ENABLEDMENUS
    DISABLEDMENUS
    CURRENTITEM
    MESSAGES
    FRAMES
);

my %styles = (
    EMBOLDEN  => ['BOLD',      'emboldening'],
    ITALICISE => ['ITALIC',    'italicising'],
    UNDERLINE => ['UNDERLINE', 'underlining'],
    REVERSE   => ['REVERSE',   'reversing'],
    DIM       => ['DIM',       'dimming'],
);

# this will do for now, we can get a proper colour check another escape
my %colours = map { ($_ => undef) } qw(
    white
    red
    green
    yellow
    blue
    magenta
    cyan
    black
);

sub add_rcdef {
    my ($code, $ext, $module) = @_;
    $code->('CALCULATE', \&_c_calculate, \&_p_calculate, 0, 0, "Calculator's default language");
    $code->('OPERATE', \&_c_operate, undef, 0, 0, "Calculator's default mode");
    # these are common configuration items for any windowed interface so we put them
    # here rather than in the interfaces; interfaces can of course add more
    $code->($_, \&_c_style, \&_p_style, 1, 0, "Calculator's $styles{$_}[1] style")
	for keys %styles;
    $code->('PAINT', \&_c_paint, \&_p_paint, 1, 0, "Calculator's colour style");
    $code->('DRAW', \&_c_draw, \&_p_draw, 1, 0, "Calculator's font style");
    $code->('FRAME', \&_c_frame, \&_p_frame, 1, 0, "Calculator's windows options");
    $code->('POINT', \&_c_point, \&_p_point, 0, 0, "Calcularot's mouse options");
}

sub _c_calculate {
    my ($rc, $mode, $ln) = @_;
    my $values = Language::INTERCAL::Rcfile::_unquote_list($rc, \$ln, "value for $mode");
    $ln eq '' or die "Invalid $mode\: extra stuff at end: $ln\n";
    for my $v (@$values) {
	Language::INTERCAL::Rcfile::_locate_module($rc, 1, "$v.io");
    }
    $values;
}

sub _p_calculate {
    my ($value) = @_;
    @$value or return ''; # not supposed to happen
    my ($lang, @opts) = @$value;
    Language::INTERCAL::Rcfile::_quote_list([$lang, sort @opts]);
}

sub _c_operate {
    my ($rc, $mode, $ln) = @_;
    $ln =~ /^(full|expr|oic)\s*$/i or die "Invalid $mode: $ln\n";
    lc($1);
}

sub _c_what {
    my ($rc, $mode, $ln) = @_;
    # split stuff manually rather than using _unquote_list so we can have for
    # example ENABLED KEYS unquoted
    my %what;
    while ($$ln ne '') {
	my $element;
	if ($$ln =~ s/^\s*(.*?)\s*\+//) {
	    $element = $1;
	} else {
	    $element = $$ln;
	    $$ln = '';
	}
	$element =~ s/^\s+//;
	$element =~ s/\s+$//;
	(my $trim = uc $element) =~ s/\s+//g;
	exists $elements{$trim} or die "Invalid $mode\: '$element' not understood\n";
	$what{$trim} = [0 + keys %what, $element];
    }
    keys %what or die "Invalid $mode\: missing WHAT\n";
    \%what;
}

sub _p_what {
    my ($value) = @_;
    join(' + ', map { $_->[1] } sort { $a->[0] <=> $b->[0] } values %$value);
}

sub _c_where {
    my ($rc, $mode, $ln) = @_;
    $$ln =~ s/\s*\bwhen\s*using\b\s*(\S+(?:\s*\+\s*\S+)*)\s*$//i or return ();
    my $using = $1;
    my $v = Language::INTERCAL::Rcfile::_unquote_list($rc, \$using, "Value for $mode (WHEN USING)");
    $using eq '' or die "Invalid $mode (WHEN USING): extra stuff at end: $using\n";
    # we don't check if the names are valid; if they aren't, they won't match
    # anything and the user will have to figure out why
    my %where = map { ($v->[$_] => $_) } (0..$#$v);
    \%where;
}

sub _p_where {
    my ($value) = @_;
    $value && keys %$value or return '';
    ' WHEN USING ' .
	Language::INTERCAL::Rcfile::_quote_list([ sort { $value->{$a} <=> $value->{$b} } keys %$value]);
}

sub _c_style {
    my ($rc, $mode, $ln) = @_;
    my $where = _c_where($rc, $mode, \$ln);
    my $what = _c_what($rc, $mode, \$ln);
    [$what, $where];
}

sub _p_style {
    my ($value) = @_;
    my ($what, $where) = @$value;
    _p_what($what) . _p_where($where);
}

sub _c_colour {
    my ($rc, $mode, $ln) = @_;
    (my $encoded = lc $ln) =~ s/\s+//g;
    exists $colours{$encoded} or die "$mode\: invalid colour $ln\n";
    [$encoded, $ln];
}

sub _p_colour {
    my ($value) = @_;
    $value->[1];
}

sub _c_paint {
    my ($rc, $mode, $ln) = @_;
    my $where = _c_where($rc, $mode, \$ln);
    my $background;
    if ($ln =~ s/\s*\bON\s+(\S+)\s*$//i) {
	$background = _c_colour($rc, $mode, $1);
    }
    $ln =~ s/\s*\bIN\s+(\S+)\s*$//i or die "Invalid $mode\: missing COLOUR\n";
    my $colour = _c_colour($rc, $mode, $1);
    my $what = _c_what($rc, $mode, \$ln);
    [$what, $where, $colour, $background];
}

sub _p_paint {
    my ($value) = @_;
    my ($what, $where, $colour, $background) = @$value;
    $background = defined $background ? (' ON ' . _p_colour($background)) : '';
    _p_what($what) . ' IN ' . _p_colour($colour) . $background . _p_where($where);
}

sub _c_draw {
    my ($rc, $mode, $ln) = @_;
    my $where = _c_where($rc, $mode, \$ln);
    my $size;
    $ln =~ s/\s*\bAT\s+(\S+)\s*$//i and $size = $1;
    $ln =~ s/\s*\bIN\s+(\S+)\s*$//i or die "Invalid $mode\: missing FONT\n";
    my $font = $1;
    my $what = _c_what($rc, $mode, \$ln);
    [$what, $where, $font, $size];
}

sub _p_draw {
    my ($value) = @_;
    my ($what, $where, $font, $size) = @$value;
    $size = defined $size ? " AT $size" : '';
    _p_what($what) . ' IN ' . $font . $size . _p_where($where);
}

sub _c_frame {
    my ($rc, $mode, $ln) = @_;
    my $where = _c_where($rc, $mode, \$ln);
    $ln =~ /^\s*WITH\s*(LINE\s*DRAWING|ASCII)\s*$/i or die "Invalid $mode\: $ln\n";
    my $how = uc($1) eq 'ASCII' ? 'A' : 'L';
    [$how, $where];
}

sub _p_frame {
    my ($value) = @_;
    my ($how, $where) = @$value;
    ($how eq 'A' ? 'ASCII' : 'LINE DRAWING') . _p_where($where);
}

sub _c_point {
    my ($rc, $mode, $ln) = @_;
    $ln =~ /^\s*WITH(OUT)?\s*THE\s*MOUSE\s*$/i or die "Invalid POINT: $ln\n";
    ! (defined $1 && $1 ne '');
}

sub _p_point {
    my ($value) = @_;
    ($value ? 'WITH' : 'WITHOUT') . ' THE MOUSE';
}

sub all_styles {
    sort (qw(PAINT DRAW), keys %styles);
}

sub get_style {
    @_ == 3 or croak "Usage: get_style(RC, INTERFACE, ELEMENT)";
    my ($rc, $interface, $srcelement) = @_;
    (my $element = uc $srcelement) =~ s/\s+//g;
    exists $elements{$element} or croak "No such ELEMENT: $srcelement";
    my $done = 0;
    my %data;
    for my $style (keys %styles) {
	my $item = $styles{$style}[0];
	for my $value ($rc->getitem($style, 1)) {
	    my ($what, $where) = @$value;
	    keys %$where && ! exists $where->{$interface} and next; # not for us
	    exists $what->{$element} or next;
	    $data{$item} = 1;
	    $done = 1;
	    last;
	}
    }
    for my $value ($rc->getitem('PAINT', 1)) {
	my ($what, $where, $colour, $background) = @$value;
	keys %$where && ! exists $where->{$interface} and next; # not for us
	exists $what->{$element} or next;
	$data{COLOUR} = $colour->[0];
	$background and $data{BACKGROUND} = $background->[0];
	$done = 1;
	last;
    }
    for my $value ($rc->getitem('DRAW', 1)) {
	my ($what, $where, $font, $size) = @$value;
	keys %$where && ! exists $where->{$interface} and next; # not for us
	exists $what->{$element} or next;
	$data{FONT} = $font;
	$size and $data{SIZE} = $size;
	$done = 1;
	last;
    }
    $done ? \%data : undef;
}

sub get_frame {
    @_ == 2 or croak "Usage: get_frame(RC, INTERFACE)";
    my ($rc, $interface) = @_;
    my $data = 'L';
    for my $value ($rc->getitem('FRAME', 1)) {
	my ($how, $where) = @$value;
	keys %$where && ! exists $where->{$interface} and next; # not for us
	$data = $how;
	last;
    }
    $data;
}

1
