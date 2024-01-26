package Language::INTERCAL::ReadNumbers;

# Convert numbers to Roman numerals

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/ReadNumbers.pm 1.-94.-2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(SP_ROMAN faint);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(roman_type roman_name roman_type_default read_number roman);

my (@roman_types, %roman_types);

BEGIN {
    @roman_types = (
	['CLC'         => \&_roman_clc],         # CLC-INTERCAL's "roman"
	['UNDERLINE'   => \&_roman_underline],   # alternative CLC-INTERCAL's
	['ARCHAIC'     => \&_roman_archaic],     # as used when Rome was new
	['MEDIAEVAL'   => \&_roman_mediaeval],   # as used in the middle ages
	['MODERN'      => \&_roman_modern],      # as used today
	['TRADITIONAL' => \&_roman_1972],        # INTERCAL-1972
	['WIMPMODE'    => \&_roman_wimpmode],    # not Roman at all
    );

    %roman_types =
	map { ( $roman_types[$_][0] => $_ + 1 ) } (0..@roman_types - 1);

    my $d = $roman_types{'CLC'};
    use vars '*roman_type_default';
    *roman_type_default = sub () { $d };
}

sub roman_type {
    @_ == 1 or croak "Usage: roman_type(TYPE)";
    my ($type) = @_;
    $type =~ s/\s+//g;
    if ($type =~ /^\d+$/) {
	return roman_type_default if $type == 0;
	return $type < 1 || $type > @roman_types ? undef : $type;
    } else {
	return exists $roman_types{$type} ? $roman_types{$type} : undef;
    }
}

sub roman_name {
    @_ == 1 or croak "Usage: roman_name(TYPE)";
    my ($type) = @_;
    $type = roman_type_default if $type == 0;
    return undef if $type < 1 || $type > @roman_types;
    return $roman_types[$type - 1][0];
}

sub read_number {
    @_ == 3 or croak "Usage: read_number(NUMBER, TYPE, FILEHANDLE)";
    my ($number, $type, $fh) = @_;
    my $rtype = roman_type($type);
    defined $rtype or faint(SP_ROMAN, $type);
    for my $line (&{$roman_types[$rtype - 1][1]}($number)) {
	$fh->read_text($line . "\n");
    }
}

sub roman {
    @_ == 2 or croak "Usage: read_number(NUMBER, TYPE)";
    my ($number, $type, $fh) = @_;
    my $rtype = roman_type($type);
    defined $rtype or faint(SP_ROMAN, $type);
    return &{$roman_types[$rtype - 1][1]}($number);
}

sub _roman_clc {
    my ($number) = @_;
    if ($number == 0) {
	return "NIHIL";
    }
    my $result = '';
    if ($number >= 4000000000) {
	my $val = lc(_numeral(int($number / 1000000000)));
	$val =~ s/(.)/\\$1/g;
	$result .= $val;
	$number %= 1000000000;
    }
    if ($number >= 4000000) {
	my $val = uc(_numeral(int($number / 1000000)));
	$val =~ s/(.)/\\$1/g;
	$result .= $val;
	$number %= 1000000;
    }
    if ($number >= 4000) {
	$result .= lc(_numeral(int($number / 1000)));
	$number %= 1000;
    }
    if ($number > 0) {
	$result .= uc(_numeral($number));
    }
    $result;
}

sub _roman_underline {
    my ($number) = @_;
    if ($number == 0) {
	return "NIHIL";
    }
    my $result = '';
    if ($number >= 4000000000) {
	my $val = lc(_numeral(int($number / 1000000000)));
	$val =~ s/(.)/_\b$1/g;
	$result .= $val;
	$number %= 1000000000;
    }
    if ($number >= 4000000) {
	my $val = uc(_numeral(int($number / 1000000)));
	$val =~ s/(.)/_\b$1/g;
	$result .= $val;
	$number %= 1000000;
    }
    if ($number >= 4000) {
	$result .= lc(_numeral(int($number / 1000)));
	$number %= 1000;
    }
    if ($number > 0) {
	$result .= uc(_numeral($number));
    }
    $result;
}

sub _roman_mediaeval {
    my ($number) = @_;
    if ($number == 0) {
	return "NIHIL";
    }
    my $first = '';
    my $second = '';
    if ($number >= 500000000) {
	my $val = uc(_m_numeral(int($number / 500000000) * 5));
	$first .= '  _  ' x length($val);
	$val =~ s/(.)/||$1||/g;
	$second .= $val;
	$number %= 500000000;
    }
    if ($number >= 5000000) {
	my $val = uc(_m_numeral(int($number / 5000000) * 5));
	$first .= ' _ ' x length($val);
	$val =~ s/(.)/|$1|/g;
	$second .= $val;
	$number %= 5000000;
    }
    if ($number >= 5000) {
	my $val = uc(_m_numeral(int($number / 5000) * 5));
	$first .= '_' x length($val);
	$second .= $val;
	$number %= 5000;
    }
    if ($number > 0) {
	my $val = uc(_m_numeral($number));
	$first .= ' ' x length($val);
	$second .= $val;
    }
    $first =~ s/\s+$//;
    $first ne '' ? ($first, $second) : ($second);
}

sub _roman_modern {
    my ($number) = @_;
    if ($number == 0) {
	return "NIHIL";
    }
    my $first = '';
    my $second = '';
    if ($number >= 100000000) {
	my $val = uc(_numeral(int($number / 100000000) * 10));
	$first .= '  _  ' x length($val);
	$val =~ s/(.)/||$1||/g;
	$second .= $val;
	$number %= 100000000;
    }
    if ($number >= 1000000) {
	my $val = uc(_numeral(int($number / 1000000) * 10));
	$first .= ' _ ' x length($val);
	$val =~ s/(.)/|$1|/g;
	$second .= $val;
	$number %= 1000000;
    }
    if ($number >= 1000) {
	my $val = uc(_numeral(int($number / 1000)));
	$first .= '_' x length($val);
	$second .= $val;
	$number %= 1000;
    }
    if ($number > 0) {
	my $val = uc(_numeral($number));
	$first .= ' ' x length($val);
	$second .= $val;
    }
    $first =~ s/\s+$//;
    $first ne '' ? ($first, $second) : ($second);
}

sub _roman_wimpmode {
    my ($number) = @_;
    $number + 0;
}

sub _roman_archaic {
    my ($number) = @_;
    if ($number == 0) {
	return "NIHIL";
    }
    my $result = '';
    if ($number >= 1000000000) {
	$result .= _a_numeral(7, int($number / 1000000000));
	$number %= 1000000000;
    }
    if ($number >= 100000000) {
	$result .= _a_numeral(6, int($number / 100000000));
	$number %= 100000000;
    }
    if ($number >= 10000000) {
	$result .= _a_numeral(5, int($number / 10000000));
	$number %= 10000000;
    }
    if ($number >= 1000000) {
	$result .= _a_numeral(4, int($number / 1000000));
	$number %= 1000000;
    }
    if ($number >= 100000) {
	$result .= _a_numeral(3, int($number / 100000));
	$number %= 100000;
    }
    if ($number >= 10000) {
	$result .= _a_numeral(2, int($number / 10000));
	$number %= 10000;
    }
    if ($number >= 1000) {
	$result .= _a_numeral(1, int($number / 1000));
	$number %= 1000;
    }
    if ($number >= 500) {
	$result .= 'I)';
	$number -= 500;
    }
    if ($number >= 1) {
	$result .= uc(_m_numeral($number));
    }
    $result;
}

sub _roman_1972 {
    my ($number) = @_;
    if ($number == 0) {
	return "_", " ";
    }
    my $first = '';
    my $second = '';
    if ($number >= 4000000000) {
	my $val = lc(_numeral(int($number / 1000000000)));
	$first .= '_' x length($val);
	$second .= $val;
	$number %= 1000000000;
    }
    if ($number >= 4000000) {
	my $val = lc(_numeral(int($number / 1000000)));
	$first .= ' ' x length($val);
	$second .= $val;
	$number %= 1000000;
    }
    if ($number >= 4000) {
	my $val = uc(_numeral(int($number / 1000)));
	$first .= '_' x length($val);
	$second .= $val;
	$number %= 1000;
    }
    if ($number > 0) {
	my $val = uc(_numeral($number));
	$first .= ' ' x length($val);
	$second .= $val;
    }
    $first =~ s/\s+$//;
    ($first, $second);
}

sub _numeral {
    my ($value) = @_;
    my $result = '';
    if ($value >= 1000) {
	$result .= 'M' x int($value / 1000);
	$value %= 1000;
    }
    if ($value >= 900) {
	$result .= 'CM';
	$value -= 900;
    }
    if ($value >= 500) {
	$result .= 'D';
	$value -= 500;
    }
    if ($value >= 400) {
	$result .= 'CD';
	$value -= 400;
    }
    if ($value >= 100) {
	$result .= 'C' x int($value / 100);
	$value %= 100;
    }
    if ($value >= 90) {
	$result .= 'XC';
	$value -= 90;
    }
    if ($value >= 50) {
	$result .= 'L';
	$value -= 50;
    }
    if ($value >= 40) {
	$result .= 'XL';
	$value -= 40;
    }
    if ($value >= 10) {
	$result .= 'X' x int($value / 10);
	$value %= 10;
    }
    if ($value >= 9) {
	$result .= 'IX';
	$value -= 9;
    }
    if ($value >= 5) {
	$result .= 'V';
	$value -= 5;
    }
    if ($value >= 4) {
	$result .= 'IV';
	$value -= 4;
    }
    if ($value >= 1) {
	$result .= 'I' x $value;
	$value %= 1;
    }
    $result;
}

sub _m_numeral {
    my ($value) = @_;
    my $result = '';
    if ($value >= 1000) {
	$result .= 'M' x int($value / 1000);
	$value %= 1000;
    }
    if ($value >= 500) {
	$result .= 'D';
	$value -= 500;
    }
    if ($value >= 100) {
	$result .= 'C' x int($value / 100);
	$value %= 100;
    }
    if ($value >= 50) {
	$result .= 'L';
	$value -= 50;
    }
    if ($value >= 10) {
	$result .= 'X' x int($value / 10);
	$value %= 10;
    }
    if ($value >= 5) {
	$result .= 'V';
	$value -= 5;
    }
    if ($value >= 1) {
	$result .= 'I' x $value;
	$value %= 1;
    }
    $result;
}

sub _a_numeral {
    my ($parens, $number) = @_;
    my $result = '';
    if ($number >= 5) {
	$result .= "I" . (")" x (1 + $parens));
	$number -= 5;
    }
    if ($number >= 1) {
	$result .= (("(" x $parens) . "I" . (")" x $parens)) x $number;
    }
    $result;
}

1;
