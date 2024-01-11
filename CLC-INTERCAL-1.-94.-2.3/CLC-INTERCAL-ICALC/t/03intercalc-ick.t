# test the calculator in ick mode

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/ICALC t/03intercalc-ick.t 1.-94.-2.2

require './t/run-calculator';

my @expr_tests = (
    ['#1', 'I'],
    ['.1 <- #V2', 'OK'],
    ['.1', 'III'],
    ['.V1', 'xxxiiDCCLXXI'],
    ['.&1', 'I'],
    ['.V-1', 'xxxiiDCCLXX'],
    ['.?1', 'xxxiiDCCLXX'],
    [':1 <- #V2', 'OK'],
    [':1', 'III'],
    [':V1', '\M\M\C\X\L\V\I\IcdlxxxiiiDCLI'],
    [':&1', 'I'],
    [':V-1', '\M\M\C\X\L\V\I\IcdlxxxiiiDCL'],
    [':?1', '\M\M\C\X\L\V\I\IcdlxxxiiiDCL'],
    ['.2 <- #1', 'OK'],
    ['.1C/.2', 'XI'],
    ['.1$.2', 'XI'],
    [':1~.1', 'III'],
    [':1~.2', 'I'],
    # XXX more tests are necessary
);

my @full_tests = (
    ['DO .1 <- #V2', 'OK'],
    ['DO .2 <- .V1', 'OK'],
    ['.1', 'III'],
    ['.2', 'xxxiiDCCLXXI'],
    ['PLEASE IGNORE .2', 'OK'],
    ['DO .2 <- #666', 'OK'],
    ['.2', 'xxxiiDCCLXXI'],
    ['PLEASE REMEMBER .2', 'OK'],
    ['DO .2 <- #666', 'OK'],
    ['.2', 'DCLXVI'],
    ['DO ABSTAIN FROM CALCULATING', 'OK'],
    ['DO .2 <- .V1', 'OK'],
    ['.2', 'DCLXVI'],
    ['DO REINSTATE CALCULATING', 'OK'],
    ['DO ABSTAIN FROM (1)', 'OK'],
    ['DO .2 <- .V1', 'OK'],
    ['(1) DO .2 <- #1', 'OK'],
    ['.2', 'xxxiiDCCLXXI'],
    ['DO REINSTATE (1)', 'OK'],
    ['(1) DO .2 <- #1', 'OK'],
    ['.2', 'I'],
    # XXX more tests are necessary
);

my $maxtest = 1 + @expr_tests + @full_tests;
print "1..$maxtest\n";

my ($pid, $read, $write) = run_calculator('expr', 'ick');

my $testnum = 1;
for my $test (@expr_tests) {
    my ($cmd, $res) = @$test;
    print $read "$cmd\n";
    my $line = <$write>;
    defined $line or die "Calculator: end of input\n";
    chomp $line;
    while ($line =~ /loading compiler/i) {
	$line = <$write>;
	defined $line or die "Calculator: end of input\n";
	chomp $line;
    }
    $line =~ s/^\s+//;
    my ($gr, $gc) = split(/\s+/, $line, 2);
    my $not = 'not ';
    if ($gr ne $res) {
	print STDERR "FAIL $testnum res ($gr ne $res)\n";
    } else {
	$not = '';
    }
    print "${not}ok ", $testnum++, "\n";
}

print $read "`mfull\n";
my $line = <$write>;
print $line =~ /mode changed/i ? '' : 'not ', "ok ", $testnum++, "\n";

for my $test (@full_tests) {
    my ($cmd, $res) = @$test;
    print $read "$cmd\n";
    my $line = <$write>;
    defined $line or die "Calculator: end of input\n";
    chomp $line;
    while ($line =~ /loading compiler/i) {
	$line = <$write>;
	defined $line or die "Calculator: end of input\n";
	chomp $line;
    }
    $line =~ s/^\s+//;
    my ($gr, $gc) = split(/\s+/, $line, 2);
    my $not = 'not ';
    if ($gr ne $res) {
	print STDERR "FAIL $testnum res ($gr ne $res)\n";
    } else {
	$not = '';
    }
    print "${not}ok ", $testnum++, "\n";
}

