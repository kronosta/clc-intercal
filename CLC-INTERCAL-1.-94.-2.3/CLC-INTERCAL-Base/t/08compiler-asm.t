# test intercal assembler

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/08compiler-asm.t 1.-94.-2

my @all_tests = (
    ['Comment 1', '', "*000 C\n", 0, "[ MSP #0 [ MUL { #67 } ] ]"],
    ['Comment 2', '', '', undef, "PLEASE NOTE: EMPTY PROGRAM"],
    ['Splat', '', "*456 No splat\n", 456, "[ MSP #456 #0 ]"],
    ['READ OUT', '', "XII\nVI\n", undef,
     "[ STO #6 SPO #1 ]\n[ STO #12 TSP #1 ]\n" .
     "[ STO MUL { #67 #76 #67 } %RT ]\n[ ROU [ TSP #1 + SPO #1 ] ]"],
    # XXX more tests would be nice
);

require 't/compiler-test';

runtest('asm', '[ GUP ]', \@all_tests);

