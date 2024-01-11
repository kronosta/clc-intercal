# test C-INTERCAL compiler

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/10compiler-ick.t 1.-94.-2

my @all_tests = (
    ['Comment', '', "*000 COMMENT\n", 0, "COMMENT"],
    ['READ OUT', '', "\nXII\n", undef, "DO .1 <- #12\nPLEASE READ OUT .1"],
    # XXX more tests would be nice
);

require 't/compiler-test';

runtest('ick', 'DO GIVE UP', \@all_tests);

