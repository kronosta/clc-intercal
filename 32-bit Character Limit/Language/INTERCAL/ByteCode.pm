package Language::INTERCAL::ByteCode;

# Definitions of bytecode symbols etc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.


use strict;
use vars qw($VERSION $PERVERSION $DATAVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/ByteCode.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-3', qw(import compare_version);
use Language::INTERCAL::Splats '1.-94.-2.1',
	qw(faint SP_INTERNAL SP_BCMATCH SP_TODO);
use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho);

$DATAVERSION = '1.-94.-2.3';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

use constant BYTE_SIZE     => 8;      # number of bits per byte (must be == 8)
use constant NUM_OPCODES   => 0x80;   # number of virtual opcodes
use constant OPCODE_RANGE  => 1 << BYTE_SIZE;
use constant BYTE_SHIFT    => OPCODE_RANGE - NUM_OPCODES;

use vars qw(@EXPORT_OK %EXPORT_TAGS);
@EXPORT_OK = qw(
    bytecode bytedecode bytename bc_list BC BCget is_constant
    bc_skip bc_forall add_bytecode NUM_OPCODES
    BC_ABG BC_ABL BC_AWC BC_BIT BC_BLM BC_BUG BC_BUT BC_BWC BC_CFG BC_CFL
    BC_CHO BC_CON BC_CRE BC_CWB BC_DES BC_DIV BC_DOS BC_DSX BC_EBC BC_ECB
    BC_ENR BC_FIN BC_FLA BC_FOR BC_FRZ BC_GRA BC_GUP BC_HSN BC_HYB BC_IGN
    BC_INT BC_LAB BC_LEA BC_MKB BC_MSP BC_MUL BC_NLB BC_NOT BC_NUM BC_NXG
    BC_NXL BC_NXT BC_OSN BC_OVM BC_OVR BC_QUA BC_REG BC_REL BC_REM BC_REO
    BC_RES BC_RET BC_RIN BC_ROU BC_RSE BC_SEL BC_SHF BC_SPL BC_SPO BC_STA
    BC_STO BC_STR BC_STS BC_STU BC_SUB BC_SWA BC_SWB BC_SYS BC_TAI BC_TRD
    BC_TRU BC_TSP BC_TYP BC_UDV BC_UNA BC_UNE BC_UNS BC_WHP BC_WIN
);

%EXPORT_TAGS = (
    BC => [qw(
	BC_ABG BC_ABL BC_AWC BC_BIT BC_BLM BC_BUG BC_BUT BC_BWC BC_CFG
	BC_CFL BC_CHO BC_CON BC_CRE BC_CWB BC_DES BC_DIV BC_DOS BC_DSX
	BC_EBC BC_ECB BC_ENR BC_FIN BC_FLA BC_FOR BC_FRZ BC_GRA BC_GUP
	BC_HSN BC_HYB BC_IGN BC_INT BC_LAB BC_LEA BC_MKB BC_MSP BC_MUL
	BC_NLB BC_NOT BC_NUM BC_NXG BC_NXL BC_NXT BC_OSN BC_OVM BC_OVR
	BC_QUA BC_REG BC_REL BC_REM BC_REO BC_RES BC_RET BC_RIN BC_ROU
	BC_RSE BC_SEL BC_SHF BC_SPL BC_SPO BC_STA BC_STO BC_STR BC_STS
	BC_STU BC_SUB BC_SWA BC_SWB BC_SYS BC_TAI BC_TRD BC_TRU BC_TSP
	BC_TYP BC_UDV BC_UNA BC_UNE BC_UNS BC_WHP BC_WIN
    )],
);

my @bytecodes = (
    ['STart of Statement', 'S', 'STS', '###C(#)S', 0, 0], # 0
    ['STOre', 'S', 'STO', 'EA', 0, 0], # 1
    ['CREate', 'S', 'CRE', '#VC(<)C(>)', 0, 0], # 2
    ['DEStroy', 'S', 'DES', '#VC(<)', 0, 0], # 3
    ['Make SPlat', 'S', 'MSP', 'EC(V)', 0, 0], # 4
    ['Double-oh-Seven eXecution', 'S', 'DSX', 'ES', 0, 0], # 5
    ['NOT', 'S', 'NOT', 'S', 0, 0], # 6
    ['NeXT', 'S', 'NXT', 'E', 0, 0], # 7
    ['RESume', 'S', 'RES', 'E', 0, 0], # 8
    ['FORget', 'S', 'FOR', 'E', 0, 0], # 9
    ['STAsh', 'S', 'STA', 'C(R)', 0, 0], # 10
    ['RETrieve', 'S', 'RET', 'C(R)', 0, 0], # 11
    ['IGNore', 'S', 'IGN', 'C(R)', 0, 0], # 12
    ['REMember', 'S', 'REM', 'C(R)', 0, 0], # 13
    ['ABstain from Label', 'S', 'ABL', 'E', 0, 0], # 14
    ['ABstain from Gerund', 'S', 'ABG', 'C(O)', 0, 0], # 15
    ['REinstate Label', 'S', 'REL', 'E', 0, 0], # 16
    ['REinstate Gerund', 'S', 'REG', 'C(O)', 0, 0], # 17
    ['Give UP', 'S', 'GUP', '', 0, 0], # 18
    ['Write IN', 'S', 'WIN', 'C(A)', 0, 0], # 19
    ['Read OUt', 'S', 'ROU', 'C(E)', 0, 0], # 20
    ['LABel', 'S', 'LAB', 'ES', 0, 0], # 21
    ['Come From Label', 'S', 'CFL', 'E', 0, 0], # 22
    ['Come From Gerund', 'S', 'CFG', 'C(O)', 0, 0], # 23
    ['QUAntum statement', 'S', 'QUA', 'S', 0, 0], # 24
    ['loop: Condition While Body', 'S', 'CWB', 'SS', 0, 0], # 25
    ['loop: Body While Condition', 'S', 'BWC', 'SS', 0, 0], # 26
    ['MaKe Belong', 'S', 'MKB', 'RR', 0, 0], # 27
    ['No Longer Belong', 'S', 'NLB', 'RR', 0, 0], # 28
    ['STUdy', 'S', 'STU', 'EER', 0, 0], # 29
    ['ENRol', 'S', 'ENR', 'C(E)R', 0, 0], # 30
    ['LEArns', 'S', 'LEA', 'ER', 0, 0], # 31
    ['FINish lecture', 'S', 'FIN', '', 0, 0], # 32
    ['GRAduate', 'S', 'GRA', 'R', 0, 0], # 33
    ['Next From Label', 'S', 'NXL', 'E', 0, 0], # 34
    ['Next From Gerund', 'S', 'NXG', 'C(O)', 0, 0], # 35
    ['CONvert', 'S', 'CON', 'OO', 0, 0], # 36
    ['SWAp', 'S', 'SWA', 'OO', 0, 0], # 37
    ['compiler BUG', 'S', 'BUG', '#', 0, 0], # 38
    ['Install DIVersion', 'S', 'DIV', 'EEEE', 0, 0], # 39
    ['Event: Body while Condition', 'S', 'EBC', 'ES', 0, 0], # 40
    ['Event: Condition while Body', 'S', 'ECB', 'ES', 0, 0], # 41
    ['FReeZe', 'S', 'FRZ', '', 0, 0], # 42
    ['SYStem call', 'S', 'SYS', 'EC(S)', 0, 0], # 43
    ['UNdocumented Statement', 'S', 'UNS', '#EEC(E)', 0, 0], # 44
    undef, # 45
    undef, # 46
    undef, # 47
    ['TRickle Down', 'S', 'TRD', 'REC(R)', 0, 0], # 48
    ['TRUss up', 'S', 'TRU', 'C(R)', 0, 0], # 49
    undef, # 50
    undef, # 51
    undef, # 52
    undef, # 53
    undef, # 54
    undef, # 55
    undef, # 56
    undef, # 57
    undef, # 58
    undef, # 59
    ['UNdocumented Assignment', 'S', 'UNA', '#EEC(E)C(A)', 0, 0], # 60
    ['REOpen', 'S', 'REO', 'EE', 0, 0], # 61
    ['set statement BIT', 'S', 'BIT', 'O', 0, 0], # 62
    ['set object FLAg', 'S', 'FLA', '', 0, 0], # 63
    ['SPOt', 'R', 'SPO', 'E', 0, 1], # 64
    ['Two SPot', 'R', 'TSP', 'E', 0, 1], # 65
    ['TAIl', 'R', 'TAI', 'E', 0, 1], # 66
    ['HYBrid', 'R', 'HYB', 'E', 0, 1], # 67
    ['WHirlPool', 'R', 'WHP', 'E', 0, 1], # 68
    ['Double-Oh-Seven', 'R', 'DOS', 'E', 0, 1], # 69
    ['SHark Fin', 'R', 'SHF', 'E', 0, 1], # 70
    ['Crawling HOrror', 'R', 'CHO', 'E', 0, 1], # 71
    undef, # 72
    undef, # 73
    undef, # 74
    undef, # 75
    undef, # 76
    undef, # 77
    undef, # 78
    ['TYPe', 'R', 'TYP', 'RE', 0, 1], # 79
    ['OVerload Register', 'R', 'OVR', 'ER', 0, 1], # 80
    undef, # 81
    ['BeLong', 'R', 'BLM', 'ER', 0, 1], # 82
    ['SUBscript', 'R', 'SUB', 'ER', 0, 1], # 83
    undef, # 84
    undef, # 85
    undef, # 86
    undef, # 87
    undef, # 88
    undef, # 89
    undef, # 90
    undef, # 91
    undef, # 92
    undef, # 93
    undef, # 94
    undef, # 95
    ['MULtiple number', 'E', 'MUL', 'C(E)', 0, 0], # 96
    ['STRing', 'E', 'STR', 'C(N)', 0, 0], # 97
    ['unary BUT', 'E', 'BUT', '#E', 0, 1], # 98
    undef, # 99
    ['unary Subtract Without Borrow', 'E', 'SWB', 'E', 0, 1], # 100
    undef, # 101
    ['unary Add Without Carry', 'E', 'AWC', 'E', 0, 1], # 102
    undef, # 103
    ['SELect', 'E', 'SEL', 'EE', 0, 1], # 104
    ['INTerleave', 'E', 'INT', 'EE', 0, 1], # 105
    ['NUMber', 'E', 'NUM', 'R', 0, 1], # 106
    ['OVerload Many', 'E', 'OVM', 'EE', 0, 1], # 107
    undef, # 108
    ['SPLat', 'E', 'SPL', '', 0, 1], # 109
    ['Unary DiVide', 'E', 'UDV', 'E', 0, 1], # 110
    ['Reverse SElect', 'E', 'RSE', 'EE', 0, 1], # 111
    ['Reverse INterleave', 'E', 'RIN', 'EE', 0, 1], # 112
    ['UNdocumented Expression', 'E', 'UNE', 'EEC(E)', 0, 0], # 113
    undef, # 114
    undef, # 115
    undef, # 116
    undef, # 117
    undef, # 118
    undef, # 119
    undef, # 120
    undef, # 121
    undef, # 122
    undef, # 123
    undef, # 124
    undef, # 125
    ['Half Spot Number', '#', 'HSN', 'N', 1, 1], # 126
    ['One Spot Number', '#', 'OSN', 'NN', 1, 1], # 127
);

my %bytedecode = (
    ABG => 15,
    ABL => 14,
    AWC => 102,
    BIT => 62,
    BLM => 82,
    BUG => 38,
    BUT => 98,
    BWC => 26,
    CFG => 23,
    CFL => 22,
    CHO => 71,
    CON => 36,
    CRE => 2,
    CWB => 25,
    DES => 3,
    DIV => 39,
    DOS => 69,
    DSX => 5,
    EBC => 40,
    ECB => 41,
    ENR => 30,
    FIN => 32,
    FLA => 63,
    FOR => 9,
    FRZ => 42,
    GRA => 33,
    GUP => 18,
    HSN => 126,
    HYB => 67,
    IGN => 12,
    INT => 105,
    LAB => 21,
    LEA => 31,
    MKB => 27,
    MSP => 4,
    MUL => 96,
    NLB => 28,
    NOT => 6,
    NUM => 106,
    NXG => 35,
    NXL => 34,
    NXT => 7,
    OSN => 127,
    OVM => 107,
    OVR => 80,
    QUA => 24,
    REG => 17,
    REL => 16,
    REM => 13,
    REO => 61,
    RES => 8,
    RET => 11,
    RIN => 112,
    ROU => 20,
    RSE => 111,
    SEL => 104,
    SHF => 70,
    SPL => 109,
    SPO => 64,
    STA => 10,
    STO => 1,
    STR => 97,
    STS => 0,
    STU => 29,
    SUB => 83,
    SWA => 37,
    SWB => 100,
    SYS => 43,
    TAI => 66,
    TRD => 48,
    TRU => 49,
    TSP => 65,
    TYP => 79,
    UDV => 110,
    UNA => 60,
    UNE => 113,
    UNS => 44,
    WHP => 68,
    WIN => 19,
);

my @bc_list = qw(
    ABG ABL AWC BIT BLM BUG BUT BWC CFG CFL CHO CON CRE CWB DES DIV DOS DSX
    EBC ECB ENR FIN FLA FOR FRZ GRA GUP HSN HYB IGN INT LAB LEA MKB MSP MUL
    NLB NOT NUM NXG NXL NXT OSN OVM OVR QUA REG REL REM REO RES RET RIN ROU
    RSE SEL SHF SPL SPO STA STO STR STS STU SUB SWA SWB SYS TAI TRD TRU TSP
    TYP UDV UNA UNE UNS WHP WIN
);

sub BC_ABG () { 15; }
sub BC_ABL () { 14; }
sub BC_AWC () { 102; }
sub BC_BIT () { 62; }
sub BC_BLM () { 82; }
sub BC_BUG () { 38; }
sub BC_BUT () { 98; }
sub BC_BWC () { 26; }
sub BC_CFG () { 23; }
sub BC_CFL () { 22; }
sub BC_CHO () { 71; }
sub BC_CON () { 36; }
sub BC_CRE () { 2; }
sub BC_CWB () { 25; }
sub BC_DES () { 3; }
sub BC_DIV () { 39; }
sub BC_DOS () { 69; }
sub BC_DSX () { 5; }
sub BC_EBC () { 40; }
sub BC_ECB () { 41; }
sub BC_ENR () { 30; }
sub BC_FIN () { 32; }
sub BC_FLA () { 63; }
sub BC_FOR () { 9; }
sub BC_FRZ () { 42; }
sub BC_GRA () { 33; }
sub BC_GUP () { 18; }
sub BC_HSN () { 126; }
sub BC_HYB () { 67; }
sub BC_IGN () { 12; }
sub BC_INT () { 105; }
sub BC_LAB () { 21; }
sub BC_LEA () { 31; }
sub BC_MKB () { 27; }
sub BC_MSP () { 4; }
sub BC_MUL () { 96; }
sub BC_NLB () { 28; }
sub BC_NOT () { 6; }
sub BC_NUM () { 106; }
sub BC_NXG () { 35; }
sub BC_NXL () { 34; }
sub BC_NXT () { 7; }
sub BC_OSN () { 127; }
sub BC_OVM () { 107; }
sub BC_OVR () { 80; }
sub BC_QUA () { 24; }
sub BC_REG () { 17; }
sub BC_REL () { 16; }
sub BC_REM () { 13; }
sub BC_REO () { 61; }
sub BC_RES () { 8; }
sub BC_RET () { 11; }
sub BC_RIN () { 112; }
sub BC_ROU () { 20; }
sub BC_RSE () { 111; }
sub BC_SEL () { 104; }
sub BC_SHF () { 70; }
sub BC_SPL () { 109; }
sub BC_SPO () { 64; }
sub BC_STA () { 10; }
sub BC_STO () { 1; }
sub BC_STR () { 97; }
sub BC_STS () { 0; }
sub BC_STU () { 29; }
sub BC_SUB () { 83; }
sub BC_SWA () { 37; }
sub BC_SWB () { 100; }
sub BC_SYS () { 43; }
sub BC_TAI () { 66; }
sub BC_TRD () { 48; }
sub BC_TRU () { 49; }
sub BC_TSP () { 65; }
sub BC_TYP () { 79; }
sub BC_UDV () { 110; }
sub BC_UNA () { 60; }
sub BC_UNE () { 113; }
sub BC_UNS () { 44; }
sub BC_WHP () { 68; }
sub BC_WIN () { 19; }

# line 62

sub add_bytecode {
    @_ == 5 or croak
	"Usage: add_bytecode(NAME, DESCR, TYPE, NUMBER, ARGS)";
    my ($name, $descr, $type, $number, $args) = @_;
    my ($const, $assign);
    $type = uc($type);
    if ($type eq 'S' || $type eq 'E') {
	$const = $assign = 0;
    } elsif ($type eq 'A') {
	$const = 0;
	$assign = 1;
	$type = 'E';
    } elsif ($type eq 'R') {
	$const = 0;
	$assign = 1;
    } elsif ($type eq 'C') {
	$const = 1;
	$assign = 1;
	$type = '#';
    } else {
	croak "Invalid TYPE: $type";
    }
    $name = uc($name);
    $number += 0;
    $number < 0 || $number >= NUM_OPCODES
	and croak "Invalid bytecode number: $number";
    $bytecodes[$number]
	and croak "Duplicate bytecode number: $number";
    exists $bytedecode{$name}
	and croak "Duplicate bytecode name: $name";
    $bytedecode{$name} = $number;
    $bytecodes[$number] = [$descr, $type, $name, $args, $const, $assign];
    push @bc_list, $name;
    push @EXPORT_OK, "BC_$name";
    push @{$EXPORT_TAGS{BC}}, "BC_$name";
    no strict;
    *{"BC_$name"} = sub { $number };
}

sub bc_list () {
    @bc_list;
}

sub BC ($) {
    my ($val) = @_;
    croak "Invalid undefined value" unless defined $val;
    my $orig = $val;
    $val < BYTE_SHIFT
	and return ($val + NUM_OPCODES);
    $val < OPCODE_RANGE
	and return (BC_HSN, $val);
    my $div = int($val / OPCODE_RANGE);
    $div < OPCODE_RANGE
	and return (BC_OSN, $div, $val % OPCODE_RANGE);
    croak "Invalid value $orig: does not fit in one spot";
}

sub bytecode ($) {
    my ($name) = @_;
    $name =~ /^\d+$/ && $name < BYTE_SHIFT ? ($name + NUM_OPCODES)
					   : $bytedecode{$name};
}

# convert bytecode to name, or in list context to:
# (name, description, type, opcode, pattern, is_constant?, is_assignable?)
#     0            1     2       3        4             5               6
sub bytedecode ($) {
    my ($b) = @_;
    if ($b >= NUM_OPCODES) {
	my $n = $b - NUM_OPCODES;
	return () if $n >= BYTE_SHIFT;
	return "#$n" unless wantarray;
	return ("#$n", 'Constant', '#', $b, '', 1, 1);
    } else {
	return () unless $bytecodes[$b];
	my $p = $bytecodes[$b];
	return $p->[2] unless wantarray;
	return ($p->[2], $p->[0], $p->[1], $b, $p->[3], $p->[4], $p->[5]);
    }
}

sub bytename ($) {
    my ($b) = @_;
    if ($b >= NUM_OPCODES) {
	my $n = $b - NUM_OPCODES;
	return () if $n >= BYTE_SHIFT;
	return "#$n";
    } else {
	return () unless $bytecodes[$b];
	my $p = $bytecodes[$b];
	return $p->[2];
    }
}

sub BCget ($$$) {
    # don't make a copy of $_[0], it's likely to be a long string and we only want
    # at most 3 bytes from it
    my ($cp, $ep) = @_[1, 2];
    $$cp >= $ep and faint(SP_INTERNAL, 'BCget called after end of code');
    my $byte = vec($_[0], $$cp++, 8);
    if ($byte >= NUM_OPCODES) {
	return $byte - NUM_OPCODES;
    }
    if ($byte == BC_HSN) {
	$$cp >= $ep and faint(SP_INTERNAL, 'BCget: missing constant after HSN');
	return vec($_[0], $$cp++, 8);
    }
    if ($byte == BC_OSN) {
	$$cp + 1 >= $ep and faint(SP_INTERNAL, 'BCget: missing constant after OSN');
	my $nx = vec($_[0], $$cp++, 8) << 8;
	return $nx | vec($_[0], $$cp++, 8);
    }
    faint(SP_INTERNAL, sprintf("BCget: unknown opcode 0x%02x", $byte));
}

sub is_constant ($) {
    my ($byte) = @_;
    return 1 if $byte >= NUM_OPCODES ||
		$byte == BC_HSN ||
		$byte == BC_OSN;
    return 0;
}

sub _skip {
    my ($start, $end, $args) = @_; # $_[3] is code but we don't want to copy it
    my $pos = 0;
    while ($pos < length $args) {
	my $e = substr($args, $pos++, 1);
	if ($e eq '#' || $e eq 'C') {
	    # constant, optionally followed by (submatch)
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    if ($pos < length $args && substr($args, $pos, 1) eq '(') {
		my $subarg = ++$pos;
		my $level = 1;
		my $parend = $subarg;
		while ($level > 0) {
		    $pos >= length $args and return undef;
		    my $c = substr($args, $pos++, 1);
		    if ($c eq '(') {
			$level++;
		    } elsif ($c eq ')') {
			$level--;
		    }
		}
		if ($byte >= NUM_OPCODES) {
		    $byte -= NUM_OPCODES;
		} elsif ($byte == BC_HSN) {
		    $$start >= $end and return undef;
		    $byte = vec($_[3], $$start++, 8);
		} elsif ($byte == BC_OSN) {
		    $$start + 1 >= $end and return undef;
		    # can't use vec(..., 16) because it may not be 16-bit aligned
		    $byte = vec($_[3], $$start++, 8) << 8;
		    $byte |= vec($_[3], $$start++, 8);
		} else {
		    return undef;
		}
		$byte or next;
		$subarg = substr($args, $subarg, $pos - $subarg - 1);
		while ($byte-- > 0) {
		    _skip($start, $end, $subarg, $_[3]) or return undef;
		}
	    } else {
		$byte >= NUM_OPCODES and next;
		if ($byte == BC_HSN) {
		    $$start >= $end and return undef;
		    $$start++;
		    next;
		}
		if ($byte == BC_OSN) {
		    $$start += 2;
		    $$start > $end and return undef;
		    next;
		}
		return undef;
	    }
	    next;
	}
	if ($e eq 'S' || $e eq 'E' || $e eq 'R' || $e eq 'A' || $e eq 'V') {
	    # statment, expression, register, asignable or symbol: they
	    # all match a generic bytecode sequence
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    $byte >= NUM_OPCODES and next;
	    $bytecodes[$byte] or return undef;
	    _skip($start, $end, $bytecodes[$byte][3], $_[3]) or return undef;
	    next;
	}
	if ($e eq 'O') {
	    # gerund or similar symbol: anything other than HSN or OSN means
	    # a 1-byte constant
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    if ($byte == BC_HSN) {
		$$start >= $end and return undef;
		$$start++;
		next;
	    }
	    if ($byte == BC_OSN) {
		$$start += 2;
		$$start > $end and return undef;
		next;
	    }
	    next;
	}
	if ($e eq 'N') {
	    # any byte
	    $$start >= $end and return undef;
	    $$start++;
	    next;
	}
	if ($e eq '<') {
	    # left grammar rule: count, position, symbol or string
	    _skip($start, $end, '##E', $_[3]) or return undef;
	    next;
	}
	if ($e eq '>') {
	    # right grammar rule: a constant follows determining what's next
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    if ($byte == NUM_OPCODES || $byte == NUM_OPCODES + 1 || $byte == NUM_OPCODES + 3 || $byte == NUM_OPCODES + 6) {
		# position, symbol / number
		_skip($start, $end, 'EE', $_[3]) or return undef;
		next;
	    }
	    if ($byte == NUM_OPCODES + 4) {
		# length; block of bytecode
		$$start >= $end and return undef;
		$byte = vec($_[3], $$start++, 8);
		if ($byte >= NUM_OPCODES) {
		    $byte -= NUM_OPCODES;
		} elsif ($byte == BC_HSN) {
		    $$start >= $end and return undef;
		    $byte = vec($_[3], $$start++, 8);
		} elsif ($byte == BC_OSN) {
		    $$start + 1 >= $end and return undef;
		    $byte = vec($_[3], $$start++, 8) << 8;
		    $byte |= vec($_[3], $$start++, 8);
		} else {
		    return undef;
		}
		$$start += $byte;
		$$start > $end and return undef;
		next;
	    }
	    if ($byte == NUM_OPCODES + 15) {
		# "splat", no other data
		next;
	    }
	    # unknown type
	    return undef;
	}
    }
    return 1;
}

sub bc_skip ($$$) {
    my (undef, $start, $end) = @_;
    $$start >= $end and return undef;
    my $byte = vec($_[0], $$start++, 8);
    $byte >= NUM_OPCODES and return 1;
    $bytecodes[$byte] or return undef;
    _skip($start, $end, $bytecodes[$byte][3], $_[0]);
}

sub bc_forall {
    @_ == 5
	or croak "Usage: bc_forall(PATTERN, CODE, START, END, CLOSURE)";
    my ($pattern, undef, $start, $end, $closure) = @_;
    $start ||= 0;
    $end = length($_[1]) if not defined $end;
    return undef if $start >= $end || $start < 0;
    my $np = '';
    while ($pattern =~ s/^(.*?)C\(/(/) {
	my $a = $1;
	$a =~ s/(.)/$1\x01/g;
	$np .= $a . 'C';
	$np .= '(' . _args('forall', \$pattern) . ')';
	$np .= "\01";
    }
    $pattern =~ s/(.)/$1\x01/g;
    $pattern = "\x01" if $pattern eq '';
    $np .= $pattern;
    _forall($np, $_[1], $start, $end, $closure);
}

my %typemap = (
    'S' => { 'S' => 0 },
    'O' => { 'S' => 0 },
    'E' => { 'E' => 0, 'R' => 0, '#' => 0 },
    'A' => { 'E' => 0, 'R' => 0, '#' => 0 },
    'R' => { 'R' => 0 },
    'V' => { 'R' => 0, 'V' => 0 },
    '#' => { '#' => 0 },
    'C' => { '#' => 0 },
    'Z' => { 'S' => 0, 'E' => 0, 'R' => 0, '#' => 0 },
    '*' => { 'S' => 0, 'E' => 0, 'R' => 0, '#' => 0 },
);

sub _args {
    my ($name, $pattern) = @_;
    faint(SP_BCMATCH, $name, 'Missing (') if $$pattern !~ s/^\(//;
    my $count = 1;
    my $result = '';
    while ($count > 0) {
	$$pattern =~ s/^([^\(\)]*)([\(\)])//
	    or faint(SP_BCMATCH, $name, 'Missing )');
	$count++ if $2 eq '(';
	$count-- if $2 eq ')';
	$result .= $1 . ($count ? $2 : '');
    }
    $result;
}

sub _forall {
    my ($pattern, undef, $sc, $ep, $closure) = @_;
    my $osc = $sc;
    MATCH: while ($pattern ne '') {
	my $e = substr($pattern, 0, 1, '');
	if ($e eq "\x00") {
	    $closure->(undef, '>') if $closure;
	    next MATCH;
	}
	if ($e eq "\x01") {
	    $closure->($sc, undef) if $closure;
	    next MATCH;
	}
	faint(SP_INTERNAL, '_forall: reading past end of code') if $sc >= $ep;
	my $v = vec($_[1], $sc, 8);
	if (exists $typemap{$e}) {
	    # check next opcode is correct type
	    my ($op, $type, $args, $const);
	    if ($v >= NUM_OPCODES && $e ne 'O') {
		$op = '#' . ($v - NUM_OPCODES);
		$type = '#';
		$args = '';
		$const = 1;
	    } else {
		$v %= NUM_OPCODES; # so gerunds can be small constants as well as opcodes
		$bytecodes[$v] or faint(SP_INTERNAL, "_forall: $e: invalid gerund $v");
		my $p = $bytecodes[$v];
		$op = $p->[2];
		$type = $p->[1];
		$args = $p->[3];
		$const = $p->[4];
	    }
	    faint(SP_INTERNAL, "_forall: $e: unknown type $type")
		unless exists $typemap{$e}{$type} ||
		       (($v == BC_MUL || $v == BC_STR) && exists $typemap{$e}{V});
	    if ($e eq 'O' && $const) {
		# inlining a stripped-down version of BCget because this is like
		# the inner loop of an inner loop
		if ($v < NUM_OPCODES) {
		    if ($v == BC_HSN) {
			$sc < $ep or return ();
			$sc++;
		    } elsif ($v == BC_OSN) {
			$sc += 2;
			$sc <= $ep or return ();
		    } else {
			return ();
		    }
		}
	    } elsif ($type eq '#' && $e ne '*') {
		my $num = BCget($_[1], \$sc, $ep);
		$closure->($v, "#$num") if $closure;
		if ($e eq 'C') {
		    $args = _args('count', \$pattern) x $num;
		    $args .= "\x00";
		    $closure->(undef, '<') if $closure;
		} else {
		    $args = '';
		}
	    } else {
		$sc++;
		$args = '' if $e eq 'O' || $e eq '*';
		$closure->($v, $op) if $closure;
	    }
	    $pattern = $args . $pattern;
	    next MATCH;
	} elsif ($e eq 'N') {
	    # any number
	    $closure->($v, "N$v") if $closure;
	    $sc++;
	} elsif ($e eq '<') {
	    # left grammar element
	    my $count = BCget($_[1], \$sc, $ep);
	    my $num = BCget($_[1], \$sc, $ep);
	    if ($num == 0) {
		$closure->(undef, '?<') if $closure;
	    } elsif ($num == 1 || $num == 2) {
		$closure->(undef, ',<') if $closure;
	    } else {
		$closure->(undef, ',!<') if $closure;
	    }
	    if ($count && $closure) {
		$closure->(undef, $count == 65535 ? '*' : $count);
	    }
	    $pattern = "E\x00" . $pattern;
	    next MATCH;
	} elsif ($e eq '>') {
	    # right grammar element
	    my $num = BCget($_[1], \$sc, $ep);
	    if ($num == 0 || $num == 6) {
		my $count = BCget($_[1], \$sc, $ep);
		if ($count && $closure) {
		    $closure->(undef, $count);
		}
		$closure->($v, $num ? '!<' : '?<') if $closure;
		$pattern = "E\x00" . $pattern;
		next MATCH;
	    }
	    if ($num == 1 || $num == 2) {
		$closure->($v, ',<') if $closure;
		my $count = BCget($_[1], \$sc, $ep);
		if ($count && $closure) {
		    $closure->(undef, $count);
		}
		$pattern = "E\x00" . $pattern;
		next MATCH;
	    }
	    if ($num == 3 || $num == 7) {
		$closure->($v, ',!<') if $closure;
		my $count = BCget($_[1], \$sc, $ep);
		if ($count && $closure) {
		    $closure->(undef, $count);
		}
		$pattern = "E\x00" . $pattern;
		next MATCH;
	    }
	    if ($num == 4) {
		$num = BCget($_[1], \$sc, $ep);
		my $se = $sc + $num;
		$se <= $ep
		    or faint(SP_INTERNAL, '_forall: end of code reached in nested call');
		if ($closure) {
		    $closure->(undef, '=<');
		    while ($sc < $se) {
			$sc += _forall('*', $_[1], $sc, $se, $closure);
		    }
		    $closure->(undef, '>');
		} else {
		    $sc = $se;
		}
		next MATCH;
	    }
	    if ($num == 15) {
		$closure->($v, '*') if $closure;
		next MATCH;
	    }
	    faint(SP_INTERNAL, $num, "_forall: invalid nested call parameter $num");
	} elsif ($e eq '[') {
	    # XXX left optimise element
	    faint(SP_TODO, 'match on [');
	} elsif ($e eq ']') {
	    # XXX right optimise element
	    faint(SP_TODO, 'match on ]');
	} else {
	    faint(SP_BCMATCH, 'type', $e);
	}
    }
    $sc - $osc;
}

1;

__END__

=pod

=head1 NAME

Language::INTERCAL::Bytecode - intermediate language

=head1 DESCRIPTION

The CLC-INTERCAL compiler works by producing bytecode from the
program source; this bytecode can be interpreted to execute the
program immediately; alternatively, a backend can produce something
else from the bytecode, for example C or Perl source code which can
then be compiled to your computer's native object format.

The compiler itself is just some more bytecode. Thus, to produce the
compiler you need a compiler compiler, and to produce that you need
a compiler compiler compiler; to produce the latter you would need
a compiler compiler compiler compiler, and so on to infinity. To
simplify the programmer's life (eh?), the compiler compiler is able
to compile itself, and is therefore identical to the compiler compiler
compiler (etcetera).

The programmer can start the process because a pre-compiled compiler
compiler, in the form of bytecode, is provided with the CLC-INTERCAL
distribution; this compiler compiler then is able to compile all
other compilers, as well as to rebuild itself if need be.

See the online manual or the HTML documentation included with the
distribution for more information about this.

=head1 SEE ALSO

A qualified psychiatrist

=head1 AUTHOR

Claudio Calvelli - compiler (whirlpool) intercal.org.uk
(Please include the word INTERLEAVING in the subject when emailing that
address, or the email may be ignored)

