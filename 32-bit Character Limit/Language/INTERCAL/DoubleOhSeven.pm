package Language::INTERCAL::DoubleOhSeven;

# Functions to manage contents of "Double-Oh-Seven" registers.

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/DoubleOhSeven.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::Splats '1.-94.-2.2', qw(
    faint splatname SP_BASE SP_CHARSET SP_CONTEXT SP_INVSPLAT SP_IOTYPE
    SP_ISSPECIAL SP_NOASSIGN SP_NUMBER SP_ROMAN SP_SPECIAL SP_SPOTS SP_SYMBOL
);
use Language::INTERCAL::ReadNumbers '1.-94.-2', qw(roman_type roman_name);
use Language::INTERCAL::Charset '1.-94.-2', qw(charset charset_name);
use Language::INTERCAL::ArrayIO '1.-94.-2', qw(iotype iotype_name);
use Language::INTERCAL::RegTypes '1.-94.-2.2', qw(REG_spot REG_twospot REG_tail REG_hybrid);
use Language::INTERCAL::Arrays '1.-94.-2.2', qw(make_list);

use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(make_doubleohseven print_doubleohseven);

my %types = (
    base        => [   2, \&_code_base,        \&_decode_spot],
    charset     => [   0, \&_code_charset,     \&_decode_charset],
    comefrom    => [   0, \&_code_comefrom,    \&_decode_spot],
    crawlhorror => [   1, \&_code_crawlhorror, \&_decode_spot],
    iotype      => [   0, \&_code_iotype,      \&_decode_iotype],
    roman       => [   0, \&_code_roman,       \&_decode_roman],
    splat       => [1000, \&_code_splat,       \&_decode_splat],
    spot        => [   0, \&_code_spot,        \&_decode_spot],
    symbol      => [   0, \&_code_symbol,      \&_decode_symbol],
    zeroone     => [   0, \&_code_zeroone,     \&_decode_spot],
);

sub make_doubleohseven ($$$$) {
    my ($type, $object, $value, $vtype) = @_;
    exists $types{$type} or faint(SP_SPECIAL, "(type $type)");
    my ($default, $convert, $decode) = @{$types{$type}};
    $value = $convert->($object, $value, $vtype);
    ($value, $convert, $decode, $type);
}

sub print_doubleohseven ($$$) {
    my ($type, $object, $value) = @_;
    exists $types{$type} or faint(SP_SPECIAL, "(type $type)");
    my ($default, $convert, $decode) = @{$types{$type}};
    $decode->($object, $value);
}

sub _get_number {
    my ($value, $type, $translate, $splat) = @_;
    faint(SP_NOASSIGN, '(undef)', 'Not a number') if ! defined $value;
    if ($type == REG_spot || $type == REG_twospot) {
	$value =~ /^\d+$/ and return $value;
    } elsif ($type == REG_tail || $type == REG_hybrid) {
	$value = pack('C*', make_list($value));
    } else {
	faint(SP_ISSPECIAL);
    }
    $translate or faint(SP_NUMBER, "(type $value)", 'Not a number');
    my $t = &{$translate}($value);
    defined $t or faint($splat, $value);
    return $t;
}

sub _decode {
    my ($value, $code) = @_;
    my $nv = $code->($value);
    return "?$nv" if defined $nv && $nv ne '';
    "#$value";
}

sub _code_spot {
    my ($object, $value, $type) = @_;
    $value = _get_number($value, $type);
    $value < 0 || $value > 0xffff
	and faint(SP_SPOTS, $value, 'double-oh-seven');
    $value;
}

sub _decode_spot {
    my ($object, $value) = @_;
    "#$value";
}

sub _code_base {
    my ($object, $value, $type) = @_;
    $value = _get_number($value, $type);
    $value < 2 || $value > 7
	and faint(SP_BASE, $value);
    $value;
}

sub _code_charset {
    my ($object, $value, $type) = @_;
    _get_number($value, $type, \&charset, SP_CHARSET);
}

sub _decode_charset {
    my ($object, $value) = @_;
    _decode($value, \&charset_name);
}

sub _code_comefrom {
    my ($object, $value, $type) = @_;
    $value = _get_number($value, $type);
    $value < 0 || $value > 3
	and faint(SP_NOASSIGN, $value,
		  'come from value must be between 0 and 3');
    $value;
}

sub _code_crawlhorror {
    my ($object, $value, $type) = @_;
    $object or faint(SP_CONTEXT, 'missing grammar');
    my $c = _get_number($value, $type);
    $c < 1 || $c > $object->num_parsers
	and faint(SP_NOASSIGN, $value, 'grammar number out of range');
    $c;
}

sub _code_iotype {
    my ($object, $value, $type) = @_;
    _get_number($value, $type, \&iotype, SP_IOTYPE);
}

sub _decode_iotype {
    my ($object, $value, $type) = @_;
    _decode($value, \&iotype_name);
}

sub _code_roman {
    my ($object, $value, $type) = @_;
    _get_number($value, $type, \&roman_type, SP_ROMAN);
}

sub _decode_roman {
    my ($object, $value) = @_;
    _decode($value, \&roman_name);
}

sub _code_splat {
    my ($object, $value, $type) = @_;
    _get_number($value, $type, \&_splat_type, SP_INVSPLAT);
}

sub _splat_type {
    my ($code) = @_;
    defined splatname($code) ? $code : 1000;
}

sub _decode_splat {
    my ($object, $value) = @_;
    $value < 1000 ? $value : undef;
}

sub _code_symbol {
    my ($object, $value, $type) = @_;
    $object or faint(SP_CONTEXT, 'symbol without grammar');
    _get_number($value, $type, sub { $object->symboltable->find(@_) }, SP_SYMBOL);
}

sub _decode_symbol {
    my ($object, $value) = @_;
    _decode($value, sub { $object->symboltable->symbol(@_) } );
}

sub _code_zeroone {
    my ($object, $value, $type) = @_;
    $value = _get_number($value, $type);
    $value < 0 || $value > 1
	and faint(SP_NOASSIGN, $value, 'value must be 0 or 1');
    $value;
}

1;
