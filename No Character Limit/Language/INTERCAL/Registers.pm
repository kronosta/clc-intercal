package Language::INTERCAL::Registers;

# Bytecode sequences to encode registers and related functions

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.


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

$DATAVERSION = '1.-94.-2.3';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

use vars qw(@EXPORT_OK);
# for simplicity we re-export REG_* from RegTypes
@EXPORT_OK = qw(
    REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho
    reg_nametype reg_typename
    add_register reg_code reg_code2 reg_create reg_decode reg_list
    reg_name reg_translate
    DOS_AR DOS_AW DOS_BA DOS_CF DOS_CR DOS_CW DOS_DM DOS_ES DOS_FS DOS_GU
    DOS_IO DOS_IS DOS_JS DOS_OS DOS_PS DOS_RM DOS_RT DOS_SM DOS_SP DOS_SS
    DOS_TM DOS_WT
    SHF_AV SHF_EV
    WHP_OR WHP_ORFH WHP_OSFH WHP_OWFH WHP_SNFH WHP_TRFH
);

# these are duplicated from ByteCode.pm so we don't need a mutual dependency
# they are autongenerated from ByteCode.Data anywa
sub BC_CHO () { 71; }
sub BC_DOS () { 69; }
sub BC_HYB () { 67; }
sub BC_SHF () { 70; }
sub BC_SPO () { 64; }
sub BC_TAI () { 66; }
sub BC_TSP () { 65; }
sub BC_TYP () { 79; }
sub BC_WHP () { 68; }

my @reg_list = qw(
    AR AV AW BA CF CR CW DM ES EV FS GU IO IS JS OR ORFH OS OSFH OWFH PS RM
    RT SM SNFH SP SS TM TRFH WT
);

my %reg_list = (
    AR => ['spot', 0, BC_DOS, '%', 10],
    AW => ['spot', 0, BC_DOS, '%', 11],
    BA => ['base', 2, BC_DOS, '%', 4],
    CF => ['comefrom', 0, BC_DOS, '%', 5],
    CR => ['charset', 0, BC_DOS, '%', 6],
    CW => ['charset', 0, BC_DOS, '%', 7],
    DM => ['zeroone', 0, BC_DOS, '%', 18],
    ES => ['symbol', 'CALC_EXPR', BC_DOS, '%', 16],
    FS => ['symbol', 'CALC_FULL', BC_DOS, '%', 15],
    GU => ['zeroone', 0, BC_DOS, '%', 23],
    IO => ['iotype', 1, BC_DOS, '%', 3],
    IS => ['symbol', 0, BC_DOS, '%', 17],
    JS => ['symbol', 'END_JUNK', BC_DOS, '%', 12],
    OS => ['spot', 0, BC_DOS, '%', 8],
    PS => ['symbol', 'PROGRAM', BC_DOS, '%', 14],
    RM => ['zeroone', 0, BC_DOS, '%', 21],
    RT => ['roman', 1, BC_DOS, '%', 2],
    SM => ['zeroone', 1, BC_DOS, '%', 22],
    SP => ['splat', 1000, BC_DOS, '%', 19],
    SS => ['symbol', 'SPACE', BC_DOS, '%', 13],
    TM => ['zeroone', 0, BC_DOS, '%', 9],
    WT => ['zeroone', 0, BC_DOS, '%', 1],
    AV => ['vector', [], BC_SHF, '^', 1],
    EV => ['vector', [], BC_SHF, '^', 2],
    OR => ['whirlpool', undef, BC_WHP, '@', 0],
    ORFH => ['whirlpool', $stdread, BC_WHP, '@', 2],
    OSFH => ['whirlpool', $stdsplat, BC_WHP, '@', 3],
    OWFH => ['whirlpool', $stdwrite, BC_WHP, '@', 1],
    SNFH => ['whirlpool', $devnull, BC_WHP, '@', 7],
    TRFH => ['whirlpool', $stdsplat, BC_WHP, '@', 9],
);

my %reg_names = (
    '%1' => 'WT',
    '%2' => 'RT',
    '%3' => 'IO',
    '%4' => 'BA',
    '%5' => 'CF',
    '%6' => 'CR',
    '%7' => 'CW',
    '%8' => 'OS',
    '%9' => 'TM',
    '%10' => 'AR',
    '%11' => 'AW',
    '%12' => 'JS',
    '%13' => 'SS',
    '%14' => 'PS',
    '%15' => 'FS',
    '%16' => 'ES',
    '%17' => 'IS',
    '%18' => 'DM',
    '%19' => 'SP',
    '%21' => 'RM',
    '%22' => 'SM',
    '%23' => 'GU',
    '^1' => 'AV',
    '^2' => 'EV',
    '@0' => 'OR',
    '@1' => 'OWFH',
    '@2' => 'ORFH',
    '@3' => 'OSFH',
    '@7' => 'SNFH',
    '@9' => 'TRFH',
);

sub DOS_AR () { 10 }
sub DOS_AW () { 11 }
sub DOS_BA () { 4 }
sub DOS_CF () { 5 }
sub DOS_CR () { 6 }
sub DOS_CW () { 7 }
sub DOS_DM () { 18 }
sub DOS_ES () { 16 }
sub DOS_FS () { 15 }
sub DOS_GU () { 23 }
sub DOS_IO () { 3 }
sub DOS_IS () { 17 }
sub DOS_JS () { 12 }
sub DOS_OS () { 8 }
sub DOS_PS () { 14 }
sub DOS_RM () { 21 }
sub DOS_RT () { 2 }
sub DOS_SM () { 22 }
sub DOS_SP () { 19 }
sub DOS_SS () { 13 }
sub DOS_TM () { 9 }
sub DOS_WT () { 1 }
sub SHF_AV () { 1 }
sub SHF_EV () { 2 }
sub WHP_OR () { 0 }
sub WHP_ORFH () { 2 }
sub WHP_OSFH () { 3 }
sub WHP_OWFH () { 1 }
sub WHP_SNFH () { 7 }
sub WHP_TRFH () { 9 }

# line 69

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
