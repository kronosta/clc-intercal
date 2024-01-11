# test the calculator in OIC mode

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/ICALC t/01intercalc-oic.t 1.-94.-2.2

require './t/run-calculator';

my @tests = (
    ['0-1-1m00', 'm00', '-1', '(0 - -1) / -1'],
    ['-7.5.5-2m01', 'm01', '4', '(-7.5 - .5) / -2'],
    ['m1m0.5m2', 'm02', '10', '(m01 - m00) / .5'],
    ['m2m1m1m3', 'm03', '1.5', '(m02 - m01) / m01'],
    ['6m012m4', 'm04', '1', '(6 - m01) / 2'],
    ['.5m3-2m5', 'm05', 0.5, '(.5 - m03) / -2'],
    # XXX more tests are necessary
);

my $maxtest = @tests;
print "1..$maxtest\n";

my ($pid, $read, $write) = run_calculator('oic');

my $testnum = 1;
for my $test (@tests) {
    my ($cmd, $mem, $res, $calc) = @$test;
    print $read "$cmd\n";
    my $line = <$write>;
    defined $line or die "Calculator: end of input\n";
    chomp $line;
    while ($line =~ /loading compiler/i) {
	$line = <$write>;
	defined $line or die "Calculator: end of input\n";
	chomp $line;
    }
    my ($gm, $gr, $gc) = split(/\s+/, $line, 3);
    my $not = 'not ';
    if ($gm ne $mem) {
	print STDERR "FAIL $testnum mem ($gm ne $mem)\n";
    } elsif ($gr ne $res) {
	print STDERR "FAIL $testnum res ($gr ne $res)\n";
    } elsif ($gc ne $calc) {
	print STDERR "FAIL $testnum res ($gc ne $calc)\n";
    } else {
	$not = '';
    }
    print "${not}ok ", $testnum++, "\n";
}

