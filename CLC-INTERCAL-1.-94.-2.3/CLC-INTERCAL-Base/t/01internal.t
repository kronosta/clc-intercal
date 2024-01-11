# Test various aspects of the internals

# Copyright (c) 2013, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/01internal.t 1.-94.-2.1

use Language::INTERCAL::Exporter '1.-94.-2.1', qw(compare_version);

my @tests = (
    ['compare_version', \&compare_version, '1', '1.-94.-2.1', 1],
    ['compare_version', \&compare_version, '1.-94', '1.-94.-2.1', 1],
    ['compare_version', \&compare_version, '1.-94.-2', '1.-94.-2.1', -1],
    ['compare_version', \&compare_version, '1.-94.-2.1', '1.-94.-2.1', 0],
    ['compare_version', \&compare_version, '1.-94.-2.2', '1.-94.-2.1', 1],
    ['compare_version', \&compare_version, '1.-94.-2.2', '1.-94.-2', 1],
    ['compare_version', \&compare_version, '1.-94.-2.2', '1.-94', -1],
    ['compare_version', \&compare_version, '1.-94.-2.2', '1', -1],
);

print "1..", scalar(@tests), "\n";
$| = 1;

for my $test (@tests) {
    my ($name, $code, $arg1, $arg2, $expected) = @$test;
    my $result = $code->($arg1, $arg2);
    if ($expected eq $result) {
	print "ok\n";
    } else {
	print STDERR "$name($arg1, $arg2) returned $result instead of $expected\n";
	print "not ok\n";
    }
}

