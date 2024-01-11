# test iacc compiler compiler

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/07compiler-iacc.t 1.-94.-2

my @all_tests = (
    ['Comment', '', "*000 COMMENT\n", 0, "COMMENT"],
    # the following statements are taken from sick.iacc so they better be valid!
    ['Create 1', '', "", undef, "DO CREATE _2 ?EMPTY ,, AS ,,"],
    ['Create 2', '', "", undef,
     "DO CREATE _2 ?QUALIFIERS ,#37, ?CONSTANT ?QUALIFIERS AS DSX + ?CONSTANT #1 + ?QUALIFIERS #1"],
    ['Create 3', '', "", undef,
     "DO CREATE _2 ?WVERB ?VERB ,WHILE, ?VERB AS CWB + ?VERB #1 + ?VERB #2"],
    # XXX more tests would be nice
);

require 't/compiler-test';

runtest('iacc', 'DO GIVE UP', \@all_tests);

