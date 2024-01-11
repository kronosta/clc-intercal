# test system call interface

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base t/13syscall.t 1.-94.-2.3") =~ /\s(\S+)$/;

my @all_tests = (
    ['No Operation (0)', '', '', undef, "(666) DO .1 <- #0"],
    ['Version Number (1)', '', "$VERSION\n", undef, "(666) DO .1 <- #1\nDO READ OUT ,1"],
    ['INTERCAL DIALECT (2)', '', "CLC-INTERCAL\n", undef, "(666) DO .1 <- #2\nDO READ OUT ,1"],
    # XXX file tests need to be written
);

require './t/compiler-test';

runtest(['sick', 'syscall'], 'DO GIVE UP', \@all_tests);

