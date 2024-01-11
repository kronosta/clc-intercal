# test the options for intercalc

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/ICALC t/05intercalc-options.t 1.-94.-2.2

use IO::Handle;
require './t/run-calculator';

my @tests = (
    ['Base 2', 2, [], '1972', '#V6', 'VII #V6'],
    ['Base 3', 3, [], '1972', '#V6', 'VIII #V6'],
    ['Base 4', 4, [], '1972', '#V6', 'xxxiiDCCLXXIV #V6'],
    ['Base 5', 5, [], '1972', '#V6', 'MMMCXXXI #V6'],
    ['Base 6', 6, [], '1972', '#V6', 'VII #V6'],
    ['Base 7', 7, [], '1972', '#V6', 'xivCDXII #V6'],
    ['Bitwise divide 1', 2, ['bitwise-divide'], 'sick', '#-65535', 'I #-65535'],
    ['Bitwise divide 2', 2, [], 'sick', '#-65535', 'II #-65535'],
    ['Wimp', 2, ['wimp'], '1972', '#V6', '7 #V6'],
);

my $maxtest = 2 + @tests;
print "1..$maxtest\n";

my @l = map { "-I$_" } @INC;

my $testnum = 1;
my ($pid, $read, $write) = run_calculator('expr', '1972');
print $read "#1\n"; flush $read;
my $line = <$write>;
chomp $line;
while ($line =~ /loading compiler/i) {
    $line = <$write>;
    chomp $line;
}
print $line =~ /\sI\s*#1$/ ? "" : "not ", "ok ", $testnum++, "\n";

for my $test (@tests) {
    my ($name, $base, $option, $lang, $in, $out) = @$test;
    print $read "`l$lang+", join(' ', @$option), "\n";
    print $read "`b$base\n";
    print $read "$in\n";
    flush $read;
    $line = <$write>;
    defined $line or die "Calculator: end of input\n";
    chomp $line;
    my $dash = 0;
    while ($line =~ / changed to |Option .* has been |loading compiler/i
        || $line eq ''
	|| $line =~ /====/
	|| $dash)
    {
	$dash = ! $dash if $line =~ /====/;
	$line = <$write>;
	defined $line or die "Calculator: end of input\n";
	chomp $line;
    }
    my $ok = 1;
    $line =~ s/\s+/ /g;
    $line =~ s/^ //;
    $line =~ s/ $//;
    if ($out ne $line) {
	print STDERR "FAIL $name ($out ne $line)\n";
	$ok = 0;
    }
    print $ok ? '' : "not ", "ok ", $testnum++, "\n";
}

close $read;
$ok = 1;
while (<$write>) {
    chomp;
    next if $_ eq '' || / changed to |Option .* has been |loading compiler/i;
    print STDERR "FAIL (extra line $_)\n" if $ok;
    $ok = 0;
}
print $ok ? '' : "not ", "ok ", $testnum++, "\n";
close $write;

