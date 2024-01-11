package Language::INTERCAL::Registers;

# Bytecode sequences to encode registers and related functions

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

@@DATA ByteCode@@

use strict;
use Carp;
use vars qw($VERSION $PERVERSION $DATAVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Registers.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho reg_nametype reg_typename);
use Language::INTERCAL::Exporter '1.-94.-2', qw(import compare_version);
use Language::INTERCAL::GenericIO '1.-94.-2',
	qw($stdwrite $stdread $stdsplat $devnull);
use Language::INTERCAL::Splats '1.-94.-2.1', qw(faint SP_SPECIAL);
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(BC);
use Language::INTERCAL::DoubleOhSeven '1.-94.-2.2', qw(make_doubleohseven);
use Language::INTERCAL::SharkFin '1.-94.-2.2', qw(make_sharkfin);

$DATAVERSION = '@@VERSION@@';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

use vars qw(@EXPORT_OK);
# for simplicity we re-export REG_* from RegTypes
@EXPORT_OK = qw(
    REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho
    reg_nametype reg_typename
    add_register reg_code reg_code2 reg_create reg_decode reg_list
    reg_name reg_translate
    @@FILL DOUBLE_OH_SEVEN DOS_ NAME '' 76 ' '@@
    @@FILL SHARK_FIN SHF_ NAME '' 76 ' '@@
    @@FILL WHIRLPOOL WHP_ NAME '' 76 ' '@@
);

# these are duplicated from ByteCode.pm so we don't need a mutual dependency
# they are autongenerated from ByteCode.Data anywa
sub BC_@@ALL REGISTERS NAME@@ () { @@NUMBER@@; }

my @reg_list = qw(
    @@FILL SPECIAL '' NAME '' 76 ' '@@
);

my %reg_list = (
    @@ALL DOUBLE_OH_SEVEN NAME@@ => ['@@'CODE'@@', @@DEFAULT@@, BC_DOS, '%', @@NUMBER@@],
    @@ALL SHARK_FIN NAME@@ => ['@@'CODE'@@', @@DEFAULT@@, BC_SHF, '^', @@NUMBER@@],
    @@ALL WHIRLPOOL NAME@@ => ['@@'CODE'@@', @@DEFAULT@@, BC_WHP, '@', @@NUMBER@@],
);

my %reg_names = (
    '%@@ALL DOUBLE_OH_SEVEN NUMBER@@' => '@@NAME@@',
    '^@@ALL SHARK_FIN NUMBER@@' => '@@NAME@@',
    '@@@ALL WHIRLPOOL NUMBER@@' => '@@NAME@@',
);

sub DOS_@@ALL DOUBLE_OH_SEVEN NAME@@ () { @@NUMBER@@ }
sub SHF_@@ALL SHARK_FIN NAME@@ () { @@NUMBER@@ }
sub WHP_@@ALL WHIRLPOOL NAME@@ () { @@NUMBER@@ }

# line @@LINE@@

sub add_register {
    @_ == 5 or croak
	"Usage: add_register(NAME, TYPE, CODE, NUMBER, DEFAULT)";
    my ($name, $type, $code, $number, $default) = @_;
    my $op;
    if ($type eq '%') {
	$op = BC_DOS;
    } elsif ($type eq '^') {
	$op = BC_SHF;
    } elsif ($type eq '@') {
	$op = BC_WHP;
    } else {
	croak "Invalid TYPE $type";
    }
    $name = uc($name);
    exists $reg_list{$name}
	and croak "Duplicate register name: $name";
    $number += 0;
    exists $reg_names{$type . $number}
	and croak "Duplicate register number: $type$number";
    $reg_list{$name} = [$code, $default, $op, $type, $number];
    $reg_names{$type . $number} = $name;
    push @reg_list, $name;
}

sub reg_decode ($$;$) {
    my ($type, $number, $whp) = @_;
    my $typename = reg_typename($type) || "?$type/";
    my $rn = "$typename$number";
    $type == REG_dos || $type == REG_shf || ($whp && $type == REG_whp)
	or return $rn;
    exists $reg_names{$rn} or return $rn;
    $rn = $reg_names{$rn};
    $reg_list{$rn}[3] . $rn;
}

sub reg_create ($$$) {
    my ($type, $number, $object) = @_;
    if ($type == REG_dos) {
	if (exists $reg_names{"%$number"}) {
	    my $rn = $reg_names{"%$number"};
	    exists $reg_list{$rn}
		and return make_doubleohseven($reg_list{$rn}[0],
					      $object,
					      $reg_list{$rn}[1],
					      REG_spot);
	}
	faint(SP_SPECIAL, reg_decode($type, $number));
    }
    if ($type == REG_shf) {
	if (exists $reg_names{"^$number"}) {
	    my $rn = $reg_names{"^$number"};
	    exists $reg_list{$rn}
		and return make_sharkfin($reg_list{$rn}[0],
					 $object,
					 $reg_list{$rn}[1],
					 REG_tail);
	}
	faint(SP_SPECIAL, reg_decode($type, $number));
    }
    if ($type == REG_whp) {
	if (exists $reg_names{"\@$number"}) {
	    my $rn = $reg_names{"\@$number"};
	    exists $reg_list{$rn}
		and return ( { filehandle => $reg_list{$rn}[1] } );
	}
	return ( {} );
    }
    $type == REG_spot || $type == REG_twospot
	and return (0);
    $type == REG_tail || $type == REG_hybrid
	and return [];
    $type == REG_cho && ($number == 1 || $number == 2)
	and return ();
    faint(SP_SPECIAL, reg_decode($type, $number));
}

sub reg_list () {
    @reg_list;
}

sub reg_code ($) {
    my ($name) = @_;
    my ($type, $number) = reg_translate($name);
    reg_code2($type, $number);
}

sub reg_code2 ($$) {
    my ($type, $number) = @_;
    $type == REG_spot and return (BC_SPO, BC($number));
    $type == REG_twospot and return (BC_TSP, BC($number));
    $type == REG_tail and return (BC_TAI, BC($number));
    $type == REG_hybrid and return (BC_HYB, BC($number));
    $type == REG_whp and return (BC_WHP, BC($number));
    $type == REG_dos and return (BC_DOS, BC($number));
    $type == REG_shf and return (BC_SHF, BC($number));
    $type == REG_dos and return (BC_CHO, BC($number));
    undef;
}

sub reg_name ($) {
    my ($rn) = @_;
    exists $reg_list{$rn}
	and return $reg_list{$rn}[3] . $reg_list{$rn}[4];
    if (exists $reg_names{$rn}) {
	$rn = $reg_names{$rn};
	return $reg_list{$rn}[3] . $reg_list{$rn}[4];
    }
    $rn =~ /^([%^\@])(.*)$/ && exists $reg_list{$2} && $reg_list{$2}[3] eq $1
	and return $reg_list{$2}[3] . $reg_list{$2}[4];
    $rn =~ s/^([\.:,;\@^%])0*([^\D0]\d*)$/$1$2/ && $2 <= 0xffff and return $rn;
    $rn =~ /^\@0+$/ and return '@0';
    undef;
}

sub reg_translate ($) {
    my ($rn) = @_;
    $rn = $reg_names{$rn} if exists $reg_names{$rn};
    exists $reg_list{substr($rn, 1)} && $reg_list{substr($rn, 1)}[3] eq substr($rn, 0, 1)
	and $rn = substr($rn, 1);
    if (exists $reg_list{$rn}) {
	my $rt = $reg_list{$rn}[3];
	my $rv = $reg_list{$rn}[4];
	$rt eq '%' and return (REG_dos, $rv);
	$rt eq '^' and return (REG_shf, $rv);
	$rt eq '@' and return (REG_whp, $rv);
    }
    my $rt = substr($rn, 0, 1);
    my $rv = 0 + substr($rn, 1);
    $rv > 0 && $rv <= 0xffff or faint(SP_SPECIAL, $rn);
    $rt eq '.' and return (REG_spot, $rv);
    $rt eq ':' and return (REG_twospot, $rv);
    $rt eq ',' and return (REG_tail, $rv);
    $rt eq ';' and return (REG_hybrid, $rv);
    $rt eq '@' and return (REG_whp, $rv);
    $rt eq '_' and return (REG_cho, $rv);
    faint(SP_SPECIAL, $rn);
}

1;
