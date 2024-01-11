# test CLC-INTERCAL compiler

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/11compiler-sick.t 1.-94.-2.1

my @all_tests = (
    ['Comment', '', "*000 COMMENT\n", 0, "COMMENT"],
    ['READ OUT', '', "XII\n", undef, "DO .1 <- #12\nPLEASE READ OUT .1"],
    ['NOT', '', "XII\n", undef, "DO .1 <- #12\nDO NOT .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 1', '', "XII\n", undef, "DO .1 <- #12\nDO %0 .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 2', '', "XXIV\n", undef, "DO .1 <- #12\nDO %100 .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 3', '', "XXIV\n", undef, "DO .1 <- #100\nDO %.1 .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 4', '', "NIHIL\n", undef, "DO .1 <- #0\nDO %.1 .1 <- #24\nPLEASE READ OUT .1"],
    ['NOT DOUBLE_OH_SEVEN 1', '', "XII\n", undef, "DO .1 <- #12\nDO NOT %0 .1 <- #24\nPLEASE READ OUT .1"],
    ['NOT DOUBLE_OH_SEVEN 2', '', "XII\n", undef, "DO .1 <- #12\nDO NOT %100 .1 <- #24\nPLEASE READ OUT .1"],
    ['NOT DOUBLE_OH_SEVEN 3', '', "C\n", undef, "DO .1 <- #100\nDO NOT %.1 .1 <- #24\nPLEASE READ OUT .1"],
    ['NOT DOUBLE_OH_SEVEN 4', '', "NIHIL\n", undef, "DO .1 <- #0\nDO NOT %.1 .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 1 NOT', '', "XII\n", undef, "DO .1 <- #12\nDO %0 NOT .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 2 NOT', '', "XII\n", undef, "DO .1 <- #12\nDO %100 NOT .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 3 NOT', '', "C\n", undef, "DO .1 <- #100\nDO %.1 NOT .1 <- #24\nPLEASE READ OUT .1"],
    ['DOUBLE_OH_SEVEN 4 NOT', '', "NIHIL\n", undef, "DO .1 <- #0\nDO %.1 NOT .1 <- #24\nPLEASE READ OUT .1"],
    # as mentioned in alt.lang.intercal as "undocumented": we can make
    # "JUNK" recognised as a statement without "DO" and/or "PLEASE"
    ['Create 1', '', "II\n", undef,
     "DO CREATE ?END_JUNK ,JUNK, AS ,, " .
     "DO CREATE ?STATEMENT ,JUNK, ?EXPRESSION AS STS + ** + ROU + #1 + ?EXPRESSION #1 " .
     "JUNK #2"],
    # as mentioned in alt.lang.intercal as: we can make #1000000 a valid thing,
    # parsed as #10000 00 -- here we have a postfix unary division; note that
    # we can't use ?EXPRESSION where we say ?NONUNARIES because that would
    # be circular reasoning
    ['Create 2', '', "II\n", undef,
     "DO CREATE ?EXPRESSION ?NONUNARIES ,00, AS UDV + ?NONUNARIES #1 " .
     "DO READ OUT #1000000"],
    # XXX more tests would be nice
);

require 't/compiler-test';

runtest('sick', 'DO GIVE UP', \@all_tests);

