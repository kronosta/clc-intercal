# test bytecode interpreter - registers

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/02bytecode-registers.t 1.-94.-2.2

use Language::INTERCAL::GenericIO '1.-94.-2', qw($devnull);
use Language::INTERCAL::Interpreter '1.-94.-2.2';
use Language::INTERCAL::Registers '1.-94.-2.2', qw(REG_spot REG_whp reg_code);
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(:BC BC);
use Language::INTERCAL::Splats '1.-94.-2.2', qw(
    SP_BASE SP_CHARSET SP_FALL_OFF SP_IOTYPE SP_ISARRAY
    SP_NOARRAY SP_NOASSIGN SP_NODIM SP_NUMBER SP_ROMAN
);
use Language::INTERCAL::ReadNumbers '1.-94.-2', qw(roman_type);
use Language::INTERCAL::ArrayIO '1.-94.-2', qw(iotype);
use Language::INTERCAL::Charset '1.-94.-2', qw(charset);
use Language::INTERCAL::Arrays '1.-94.-2.2', qw(make_list);

*_check_number = \&Language::INTERCAL::Interpreter::_check_number;

my @all_tests = (
    ["Spot 1", { '.1' => 1234 }, { '.1' => 5678 }, undef, undef,
	[BC_STO, BC(5678), BC_SPO, BC(1)]],
    ["Spot 2", { }, { }, undef, SP_NOARRAY,
	[BC_STO, BC(666), BC_SUB, BC(6), BC_SPO, BC(1)]],
    ["Spot 3", { }, { }, undef, SP_ISARRAY,
	[BC_STO, BC_MUL, BC(3), BC(1), BC(2), BC(3), BC_SPO, BC(1)]],
    ["Two Spot 1", { ':1' => 1234 }, { ':1' => 5678 }, undef, undef,
	[BC_STO, BC(5678), BC_TSP, BC(1)]],
    ["Two spot 2", { }, { }, undef, SP_NOARRAY,
	[BC_STO, BC(666), BC_SUB, BC(6), BC_TSP, BC(1)]],
    ["Two spot 3", { }, { }, undef, SP_ISARRAY,
	[BC_STO, BC_MUL, BC(3), BC(1), BC(2), BC(3), BC_TSP, BC(1)]],
    ["Tail 1", { }, { }, undef, SP_NODIM,
	[BC_STO, BC(666), BC_SUB, BC(6), BC_TAI, BC(1)]],
    ["Tail 2", { }, { ',1' => [8, 9, 12, 1, 69, 666] }, undef, undef,
	[BC_STO, BC(6), BC_TAI, BC(1)],
	[BC_STO, BC(8), BC_SUB, BC(1), BC_TAI, BC(1)],
	[BC_STO, BC(9), BC_SUB, BC(2), BC_TAI, BC(1)],
	[BC_STO, BC(12), BC_SUB, BC(3), BC_TAI, BC(1)],
	[BC_STO, BC(1), BC_SUB, BC(4), BC_TAI, BC(1)],
	[BC_STO, BC(69), BC_SUB, BC(5), BC_TAI, BC(1)],
	[BC_STO, BC(666), BC_SUB, BC(6), BC_TAI, BC(1)]],
    ["Tail 3", { }, { ',1' => [8, 9, 12, 1, 69, 666] }, undef, undef,
	[BC_STO, BC_MUL, BC(2), BC(2), BC(3), BC_TAI, BC(1)],
	[BC_STO, BC(8), BC_SUB, BC(1), BC_SUB, BC(1), BC_TAI, BC(1)],
	[BC_STO, BC(9), BC_SUB, BC(2), BC_SUB, BC(1), BC_TAI, BC(1)],
	[BC_STO, BC(12), BC_SUB, BC(3), BC_SUB, BC(1), BC_TAI, BC(1)],
	[BC_STO, BC(1), BC_SUB, BC(1), BC_SUB, BC(2), BC_TAI, BC(1)],
	[BC_STO, BC(69), BC_SUB, BC(2), BC_SUB, BC(2), BC_TAI, BC(1)],
	[BC_STO, BC(666), BC_SUB, BC(3), BC_SUB, BC(2), BC_TAI, BC(1)]],
    ["Tail 4", { }, { ',1' => [8, 9, 42], '.1' => 8, '.2' => 9, '.3' => 42 }, undef, undef,
	[BC_STO, BC(3), BC_TAI, BC(1)],
	[BC_STO, BC(8), BC_SUB, BC(1), BC_TAI, BC(1)],
	[BC_STO, BC(9), BC_SUB, BC(2), BC_TAI, BC(1)],
	[BC_STO, BC(42), BC_SUB, BC(3),BC_TAI, BC(1)],
	[BC_STO, BC_SUB, BC(1), BC_TAI, BC(1), BC_SPO, BC(1)],
	[BC_STO, BC_SUB, BC(2), BC_TAI, BC(1), BC_SPO, BC(2)],
	[BC_STO, BC_SUB, BC(3), BC_TAI, BC(1), BC_SPO, BC(3)]],
    ["Hybrid 1", { }, { }, undef, SP_NODIM,
	[BC_STO, BC(666), BC_SUB, BC(6), BC_HYB, BC(1)]],
    ["Hybrid 2", { }, { ';1' => [8, 9, 12, 1, 69, 666] }, undef, undef,
	[BC_STO, BC(6), BC_HYB, BC(1)],
	[BC_STO, BC(8), BC_SUB, BC(1), BC_HYB, BC(1)],
	[BC_STO, BC(9), BC_SUB, BC(2), BC_HYB, BC(1)],
	[BC_STO, BC(12), BC_SUB, BC(3), BC_HYB, BC(1)],
	[BC_STO, BC(1), BC_SUB, BC(4), BC_HYB, BC(1)],
	[BC_STO, BC(69), BC_SUB, BC(5), BC_HYB, BC(1)],
	[BC_STO, BC(666), BC_SUB, BC(6), BC_HYB, BC(1)]],
    ["Hybrid 3", { }, { ';1' => [8, 9, 12, 1, 69, 666] }, undef, undef,
	[BC_STO, BC_MUL, BC(2), BC(2), BC(3), BC_HYB, BC(1)],
	[BC_STO, BC(8), BC_SUB, BC(1), BC_SUB, BC(1), BC_HYB, BC(1)],
	[BC_STO, BC(9), BC_SUB, BC(2), BC_SUB, BC(1), BC_HYB, BC(1)],
	[BC_STO, BC(12), BC_SUB, BC(3), BC_SUB, BC(1), BC_HYB, BC(1)],
	[BC_STO, BC(1), BC_SUB, BC(1), BC_SUB, BC(2), BC_HYB, BC(1)],
	[BC_STO, BC(69), BC_SUB, BC(2), BC_SUB, BC(2), BC_HYB, BC(1)],
	[BC_STO, BC(666), BC_SUB, BC(3), BC_SUB, BC(2), BC_HYB, BC(1)]],
    ["Hybrid 4", { }, { ';1' => [8, 9, 42], ':1' => 8, ':2' => 9, ':3' => 42 }, undef, undef,
	[BC_STO, BC(3), BC_HYB, BC(1)],
	[BC_STO, BC(8), BC_SUB, BC(1), BC_HYB, BC(1)],
	[BC_STO, BC(9), BC_SUB, BC(2), BC_HYB, BC(1)],
	[BC_STO, BC(42), BC_SUB, BC(3),BC_HYB, BC(1)],
	[BC_STO, BC_SUB, BC(1), BC_HYB, BC(1), BC_TSP, BC(1)],
	[BC_STO, BC_SUB, BC(2), BC_HYB, BC(1), BC_TSP, BC(2)],
	[BC_STO, BC_SUB, BC(3), BC_HYB, BC(1), BC_TSP, BC(3)]],
    ["%WT 0", { }, { '%WT' => 0 }, undef, undef,
	[BC_STO, BC(0), reg_code('%WT')]],
    ["%WT 1", { }, { '%WT' => 1 }, undef, undef,
	[BC_STO, BC(1), reg_code('%WT')]],
    ["%WT 2", { }, { }, undef, SP_NOASSIGN,
	[BC_STO, BC(2), reg_code('%WT')]],
    ["%RT CLC", { }, { '%RT' => roman_type('CLC') }, undef, undef,
	[BC_STO, _str('CLC'), reg_code('%RT')]],
    ["%RT UNDERLINE", { }, { '%RT' => roman_type('UNDERLINE') }, undef, undef,
	[BC_STO, _str('UNDERLINE'), reg_code('%RT')]],
    ["%RT ARCHAIC", { }, { '%RT' => roman_type('ARCHAIC') }, undef, undef,
	[BC_STO, _str('ARCHAIC'), reg_code('%RT')]],
    ["%RT MEDIAEVAL", { }, { '%RT' => roman_type('MEDIAEVAL') }, undef, undef,
	[BC_STO, _str('MEDIAEVAL'), reg_code('%RT')]],
    ["%RT MODERN", { }, { '%RT' => roman_type('MODERN') }, undef, undef,
	[BC_STO, _str('MODERN'), reg_code('%RT')]],
    ["%RT TRADITIONAL", { }, { '%RT' => roman_type('TRADITIONAL') }, undef, undef,
	[BC_STO, _str('TRADITIONAL'), reg_code('%RT')]],
    ["%RT WIMPMODE", { }, { '%RT' => roman_type('WIMPMODE') }, undef, undef,
	[BC_STO, _str('WIMPMODE'), reg_code('%RT')]],
    ["%RT INVALID", { }, { }, undef, SP_ROMAN,
	[BC_STO, _str('INVALID'), reg_code('%RT')]],
    ["%IO CLC", { }, { '%IO' => iotype('CLC') }, undef, undef,
	[BC_STO, _str('CLC'), reg_code('%IO')]],
    ["%IO C", { }, { '%IO' => iotype('C') }, undef, undef,
	[BC_STO, _str('C'), reg_code('%IO')]],
    ["%IO 1972", { }, { '%IO' => iotype('1972') }, undef, undef,
	[BC_STO, _str('1972'), reg_code('%IO')]],
    ["%IO INVALID", { }, { }, undef, SP_IOTYPE,
	[BC_STO, _str('INVALID'), reg_code('%IO')]],
    ["%BA 1", { }, { }, undef, SP_BASE,
	[BC_STO, BC(1), reg_code('%BA')]],
    ["%BA 2", { }, { '%BA' => 2 }, undef, undef,
	[BC_STO, BC(2), reg_code('%BA')]],
    ["%BA 3", { }, { '%BA' => 3 }, undef, undef,
	[BC_STO, BC(3), reg_code('%BA')]],
    ["%BA 4", { }, { '%BA' => 4 }, undef, undef,
	[BC_STO, BC(4), reg_code('%BA')]],
    ["%BA 5", { }, { '%BA' => 5 }, undef, undef,
	[BC_STO, BC(5), reg_code('%BA')]],
    ["%BA 6", { }, { '%BA' => 6 }, undef, undef,
	[BC_STO, BC(6), reg_code('%BA')]],
    ["%BA 7", { }, { '%BA' => 7 }, undef, undef,
	[BC_STO, BC(7), reg_code('%BA')]],
    ["%BA 8", { }, { }, undef, SP_BASE,
	[BC_STO, BC(8), reg_code('%BA')]],
    ["%CF 0", { }, { '%CF' => 0 }, undef, undef,
	[BC_STO, BC(0), reg_code('%CF')]],
    ["%CF 1", { }, { '%CF' => 1 }, undef, undef,
	[BC_STO, BC(1), reg_code('%CF')]],
    ["%CF 2", { }, { '%CF' => 2 }, undef, undef,
	[BC_STO, BC(2), reg_code('%CF')]],
    ["%CF 3", { }, { '%CF' => 3 }, undef, undef,
	[BC_STO, BC(3), reg_code('%CF')]],
    ["%CF 4", { }, { }, undef, SP_NOASSIGN,
	[BC_STO, BC(4), reg_code('%CF')]],
    ["%CR ASCII", { }, { '%CR' => charset('ASCII') }, undef, undef,
	[BC_STO, _str('ASCII'), reg_code('%CR')]],
    ["%CR Baudot", { }, { '%CR' => charset('Baudot') }, undef, undef,
	[BC_STO, _str('Baudot'), reg_code('%CR')]],
    ["%CR EBCDIC", { }, { '%CR' => charset('EBCDIC') }, undef, undef,
	[BC_STO, _str('EBCDIC'), reg_code('%CR')]],
    ["%CR Hollerith", { }, { '%CR' => charset('Hollerith') }, undef, undef,
	[BC_STO, _str('Hollerith'), reg_code('%CR')]],
    ["%CR INVALID", { }, { }, undef, SP_CHARSET,
	[BC_STO, _str('INVALID'), reg_code('%CR')]],
    ["%CW ASCII", { }, { '%CW' => charset('ASCII') }, undef, undef,
	[BC_STO, _str('ASCII'), reg_code('%CW')]],
    ["%CW Baudot", { }, { '%CW' => charset('Baudot') }, undef, undef,
	[BC_STO, _str('Baudot'), reg_code('%CW')]],
    ["%CW EBCDIC", { }, { '%CW' => charset('EBCDIC') }, undef, undef,
	[BC_STO, _str('EBCDIC'), reg_code('%CW')]],
    ["%CW Hollerith", { }, { '%CW' => charset('Hollerith') }, undef, undef,
	[BC_STO, _str('Hollerith'), reg_code('%CW')]],
    ["%CW INVALID", { }, { }, undef, SP_CHARSET,
	[BC_STO, _str('INVALID'), reg_code('%CW')]],
    ["%OS 1", { '%OS' => 1234 }, { '%OS' => 5678 }, undef, undef,
	[BC_STO, BC(5678), reg_code('%OS')]],
    ["%OS 2", { }, { }, undef, SP_NOARRAY,
	[BC_STO, BC(666), BC_SUB, BC(6), reg_code('%OS')]],
    ["%OS 3", { }, { }, undef, SP_NUMBER,
	[BC_STO, BC_MUL, BC(3), BC(1), BC(2), BC(3), reg_code('%OS')]],
    ["%TM 0", { }, { '%TM' => 0 }, undef, undef,
	[BC_STO, BC(0), reg_code('%TM')]],
    ["%TM 1", { }, { '%TM' => 1 }, undef, undef,
	[BC_STO, BC(1), reg_code('%TM')]],
    ["%TM 2", { }, { }, undef, SP_NOASSIGN,
	[BC_STO, BC(2), reg_code('%TM')]],
    ["%AR 1", { '%AR' => 1234 }, { '%AR' => 5678 }, undef, undef,
	[BC_STO, BC(5678), reg_code('%AR')]],
    ["%AR 2", { }, { }, undef, SP_NOARRAY,
	[BC_STO, BC(666), BC_SUB, BC(6), reg_code('%AR')]],
    ["%AR 3", { }, { }, undef, SP_NUMBER,
	[BC_STO, BC_MUL, BC(3), BC(1), BC(2), BC(3), reg_code('%AR')]],
    ["%AW 1", { '%AW' => 1234 }, { '%AW' => 5678 }, undef, undef,
	[BC_STO, BC(5678), reg_code('%AW')]],
    ["%AW 2", { }, { }, undef, SP_NOARRAY,
	[BC_STO, BC(666), BC_SUB, BC(6), reg_code('%AW')]],
    ["%AW 3", { }, { }, undef, SP_NUMBER,
	[BC_STO, BC_MUL, BC(3), BC(1), BC(2), BC(3), reg_code('%AW')]],
    ["%JS", { }, { '%JS' => 3 }, undef, SP_FALL_OFF, # it causes recompile, but there's no source
	[BC_STO, _str('JUNK'), reg_code('%JS')]],
    ["%SS", { }, { '%SS' => 4 }, undef, undef,
	[BC_STO, _str('SPACE'), reg_code('%SS')]],
    ["%PS", { }, { '%PS' => 1 }, undef, SP_FALL_OFF, # it causes recompile, but there's no source
	[BC_STO, _str('CONSTANT'), reg_code('%PS')]],
    ["%FS", { }, { '%FS' => 2 }, undef, undef,
	[BC_STO, _str('SYMBOL'), reg_code('%FS')]],
    ["%ES", { }, { '%ES' => 1 }, undef, undef,
	[BC_STO, _str('CONSTANT'), reg_code('%ES')]],
    ["%IS", { }, { '%IS' => 2 }, undef, SP_FALL_OFF, # it causes recompile, but there's no source
	[BC_STO, _str('SYMBOL'), reg_code('%IS')]],
    ["%DM 0", { }, { '%DM' => 0 }, undef, undef,
	[BC_STO, BC(0), reg_code('%DM')]],
    ["%DM 1", { }, { '%DM' => 1 }, undef, undef,
	[BC_STO, BC(1), reg_code('%DM')]],
    ["%DM 2", { }, { }, undef, SP_NOASSIGN,
	[BC_STO, BC(2), reg_code('%DM')]],
    ["^AV", { }, { '^AV' => 'The wee cute INTERCAL compiler produced ugly Perl' }, undef, undef,
	[BC_STO, _str('The wee cute INTERCAL compiler produced ugly Perl'), reg_code('^AV')]],
    ["^EV", { }, { '^EV' => 'The big ugly gcc produced even uglier objects' }, undef, undef,
	[BC_STO, _str('The big ugly gcc produced even uglier objects'), reg_code('^EV')]],
    ["Indirect 1", { }, { '.1' => 5678 }, undef, undef,
	[BC_STO, BC(5678), BC_TYP, BC_SPO, BC(2), BC(1)]],
    ["Indirect 2", { }, { '.1' => 5678 }, undef, undef,
	[BC_STO, BC(5678), BC_SPO, BC_NUM, BC_CHO, BC(1)]],
    ["Indirect 3", { }, { '.1' => 5678 }, undef, undef,
	[BC_STO, BC(5678), BC_TYP, BC_SPO, BC(3), BC_NUM, BC_CHO, BC(1)]],
    ["Overload Register 1", { '.1' => 1234, '.2' => 5678 }, { '.1' => 1234, '.2' => 1234, '.3' => 5678 }, undef, undef,
	[BC_STO, BC_OVR, BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)]],
    ["Overload Register 2", { '.1' => 1234, '.2' => 5678 }, { '.1' => 1234, '.2' => 5678, '.3' => 5678 }, undef, undef,
	[BC_STO, BC_OVR, BC_SPO, BC(2), BC_SPO, BC(2), BC_SPO, BC(3)]],
    ["Overload Register 3", { '.1' => 1234, '.2' => 5678 }, { '.1' => 9, '.2' => 9, '.3' => 5678 }, undef, undef,
	[BC_STO, BC_OVR, BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)],
	[BC_STO, BC(9), BC_SPO, BC(2)]],
    ["Overload Register 4", { '.1' => 1234, '.2' => 5678 }, { '.1' => 9, '.2' => 9, '.3' => 5678 }, undef, undef,
	[BC_STO, BC_OVR, BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)],
	[BC_STO, BC(9), BC_SPO, BC(1)]],
    ["Overload Register 5", { '.1' => 1234, '.2' => 5678 }, { '.1' => 1234, '.2' => 5678, '.3' => 5678 }, undef, undef,
	[BC_STO, BC_OVR, BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)],
	[BC_STO, BC_OVR, BC_SPO, BC(2), BC_SPO, BC(2), BC_SPO, BC(3)]],
    ["Overload Register 6", { '.1' => 1234, '.2' => 5678 }, { '.1' => 1234, '@2' => 1234 }, undef, undef,
	[BC_STO, BC_OVR, BC_SPO, BC(1), BC_WHP, BC(2), BC_WHP, BC(3)]],
    ["Overload Register 7", { '.1' => 1234, '.2' => 5678 },
			    { '.1' => 5678, '.2' => 36178089, ':1' => 5678, ':2' => 36178089 }, undef, undef,
	# do .1 <- .2 / '$@0 ¢ #1' -- the overload code executes as .1 ¢ #1
	[BC_STO, BC_OVR, BC_INT, BC_BLM, BC(1), BC_WHP, BC(0), BC(1), BC_SPO, BC(2), BC_SPO, BC(1)],
	[BC_STO, BC_SPO, BC(1), BC_TSP, BC(1)],
	[BC_STO, BC_SPO, BC(2), BC_TSP, BC(2)]],
    ["Overload Many 1", { '.1' => 1234, '.2' => 5678 },
	    { '.1' => 1234, '.2' => 1234, '.3' => 6, ';1' => 1234, ',2' => 1234 }, undef, undef,
	[BC_STO, BC_OVM, BC_SPO, BC(1), BC(6), BC_SPO, BC(3)]],
    ["Overload Many 2", { '.1' => 1234, '.2' => 5678 }, { '.1' => 5678, '.2' => 5678, '.3' => 6 }, undef, undef,
	[BC_STO, BC_OVM, BC_SPO, BC(2), BC(6), BC_SPO, BC(3)]],
    ["Overload Many 3", { '.1' => 1234, '.2' => 5678 }, { '.1' => 9, '.2' => 9, '.3' => 6 }, undef, undef,
	[BC_STO, BC_OVM, BC_SPO, BC(1), BC(6), BC_SPO, BC(3)],
	[BC_STO, BC(9), BC_SPO, BC(2)]],
    ["Overload Many 4", { '.1' => 1234, '.2' => 5678 }, { '.1' => 9, '.2' => 9, '.3' => 6 }, undef, undef,
	[BC_STO, BC_OVM, BC_SPO, BC(1), BC(6), BC_SPO, BC(3)],
	[BC_STO, BC(9), BC_SPO, BC(1)]],
    ["Overload Many 5", { '.1' => 1234, '.2' => 5678 }, { '.1' => 1234, '.2' => 5678, '.3' => 6 }, undef, undef,
	[BC_STO, BC_OVM, BC_SPO, BC(1), BC(6), BC_SPO, BC(3)],
	[BC_STO, BC_OVM, BC_BLM, BC(1), BC_WHP, BC(0), BC(6), BC_SPO, BC(3)]],
    ["Overload Many 7", { '.1' => 1234, '.2' => 5678 },
			{ '.1' => 13, '.2' => 36178089, '.3' => 1, ':1' => 36178089, ':3' => 1 }, undef, undef,
	# do .1 <- #13 \ '$@0 ¢ #1' -- the overload code executes as REG ¢ #1 for REG in 2..3
	# a side effect of running this is that #1 can change value and therefore $@0 can mean
	# some other register which @0 belongs to rather than the first... I haven't written a
	# test for it becuase I'm still trying to figure out what's supposed to happen
	[BC_STO, BC_OVM, BC_INT, BC_BLM, BC(1), BC_WHP, BC(0), BC(1), BC(13), BC_SPO, BC(1)],
	[BC_STO, BC_SPO, BC(2), BC_TSP, BC(1)],
	[BC_STO, BC_SPO, BC(3), BC_TSP, BC(3)]],
    ["Belongs TO 1", { '.1' => 1234, '.2' => 5678 }, { '.3' => 1234, '.4' => 5678 }, undef, undef,
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(1)],
	[BC_MKB, BC_SPO, BC(6), BC_SPO, BC(2)],
	[BC_STO, BC_BLM, BC(1), BC_SPO, BC(5), BC_SPO, BC(3)],
	[BC_STO, BC_BLM, BC(1), BC_SPO, BC(6), BC_SPO, BC(4)]],
    ["Belongs TO 2", { '.1' => 1234, '.2' => 5678 }, { '.3' => 1234, '.4' => 5678 }, undef, undef,
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(3)],
	[BC_MKB, BC_SPO, BC(6), BC_SPO, BC(4)],
	[BC_STO, BC_SPO, BC(1), BC_BLM, BC(1), BC_SPO, BC(5)],
	[BC_STO, BC_SPO, BC(2), BC_BLM, BC(1), BC_SPO, BC(6)]],
    ["Belongs TO 3", { '.1' => 1234, '.2' => 5678 }, { '.3' => 1234, '.4' => 5678 }, undef, undef,
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(1)],
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(2)],
	[BC_STO, BC_BLM, BC(2), BC_SPO, BC(5), BC_SPO, BC(3)],
	[BC_STO, BC_BLM, BC(1), BC_SPO, BC(5), BC_SPO, BC(4)]],
    ["Belongs TO 4", { '.1' => 1234, '.2' => 5678 }, { '.3' => 1234, '.4' => 5678 }, undef, undef,
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(3)],
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(4)],
	[BC_STO, BC_SPO, BC(1), BC_BLM, BC(2), BC_SPO, BC(5)],
	[BC_STO, BC_SPO, BC(2), BC_BLM, BC(1), BC_SPO, BC(5)]],
    ["Belongs TO 5", { '.1' => 1234, '.2' => 5678 }, { '.3' => 5678, '.4' => 5678 }, undef, undef,
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(1)],
	[BC_MKB, BC_SPO, BC(1), BC_SPO, BC(2)],
	[BC_STO, BC_BLM, BC(1), BC_BLM, BC(1), BC_SPO, BC(5), BC_SPO, BC(3)],
	[BC_STO, BC_BLM, BC(1), BC_SPO, BC(1), BC_SPO, BC(4)]],
    ["Belongs TO 6", { '.1' => 1234, '.2' => 5678 }, { '.3' => 1234, '.4' => 5678 }, undef, undef,
	[BC_MKB, BC_SPO, BC(5), BC_SPO, BC(3)],
	[BC_MKB, BC_SPO, BC(3), BC_SPO, BC(4)],
	[BC_STO, BC_SPO, BC(1), BC_BLM, BC(1), BC_SPO, BC(5)],
	[BC_STO, BC_SPO, BC(2), BC_BLM, BC(1), BC_BLM, BC(1), BC_SPO, BC(5)]],
);

$| = 1;

my $maxtest = 0;
for my $counter (@all_tests) {
    my $nt = 3;
    for my $r (values %{$counter->[2]}) {
	$nt ++;
	$nt += scalar @$r if ref $r;
    }
    $counter->[3] = $nt;
    $maxtest += $nt;
}
print "1..$maxtest\n";

my $testnum = 1;
for my $tester (@all_tests) {
    my ($name, $in, $out, $nt, $splat, @code) = @$tester;
    my $obj = new Language::INTERCAL::Interpreter();
    $obj->object->setbug(0, 0);
    my $cp = 0;
    my @c = map {
	pack('C*', BC_STS, BC($cp++), BC(1), BC(0), BC(0), @$_);
    } (@code, [BC_GUP]);
    eval {
	$obj->object->clear_code;
	$obj->object->unit_code(0, 'x', 1, \@c);
    };
    if ($@) {
	print "not ok ", $testnum++, "\n" for (1..$nt);
	next;
    }
    print "ok ", $testnum++, "\n";
    eval {
	for my $r (keys %$in) {
	    $obj->setreg($r, $in->{$r}, REG_spot);
	}
	$obj->setreg('@OSFH', $devnull, REG_whp);
	$obj->setreg('@TRFH', $devnull, REG_whp);
    };
    if ($@) {
	print "not ok ", $testnum++, "\n" for (2..$nt);
	print STDERR "Failed $name\n$@";
	next;
    }
    print "ok ", $testnum++, "\n";
    eval {
	$obj->start()->run()->stop();
    };
    if ($@) {
	print "not ok ", $testnum++, "\n" for (3..$nt);
	print STDERR "Failed $name\n$@";
	next;
    }
    my $os = $obj->splat;
    if (defined $os) {
	print defined $splat && $os == $splat ? "" : "not ", "ok ", $testnum++, "\n";
	print STDERR "Failed $name (*$os)\n" unless defined $splat && $os == $splat;
    } else {
	print defined $splat ? "not " : "", "ok ", $testnum++, "\n";
	print STDERR "Failed $name (no splat)\n" if defined $splat;
    }
    for my $r (sort keys %$out) {
	my ($v, $t) = eval { $obj->getreg($r) };
	my $e = $out->{$r};
	if ($@) {
	    print STDERR "Failed $name\: $r\: $@";
	    print "not ok ", $testnum++, "\n";
	    if (ref $e) {
		print "not ok ", $testnum++, "\n" for @$e;
	    }
	    next;
	}
	if (ref $e) {
	    my @v = eval { make_list($v) };
	    if (@v != @$e) {
		print STDERR "Failed $name\: $r\: $@";
		print "not ok ", $testnum++, "\n";
		print "not ok ", $testnum++, "\n" for @$e;
		next;
	    }
	    print "ok ", $testnum++, "\n";
	    for (my $i = 0; $i < @v; $i++) {
		print $v[$i] == $e->[$i] ? '' : "not ", "ok ", $testnum++, "\n";
		print STDERR "Failed $name\: $r\[$i\]: $v[$i] != $c->[$i]\n" if $v[$i] != $e->[$i];
	    }
	} else {
	    my ($ok, $n);
	    if ($e =~ /^\d+$/) {
		$n = eval { _check_number($t); $v; } || 0;
		$ok = $e == $n;
	    } else {
		$n = pack('C*', eval { make_list($v) });
		$ok = $e eq $n;
		$ok or $n = '(' , join(' ', unpack('C*', $n)) . ')';
	    }
	    print $ok ? '' : 'not ', "ok ", $testnum++, "\n";
	    print STDERR "Failed $name\: $r\: $e != $n\n" unless $ok;
	}
    }
}

sub _str {
    my ($str) = @_;
    return (BC_STR, BC(length $str), unpack('C*', $str));
}

