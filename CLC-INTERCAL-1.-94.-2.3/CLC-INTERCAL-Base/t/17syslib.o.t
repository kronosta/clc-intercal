# Check the "optimised" syslib.o.iasm

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# This test uses a lot of data generated using "ick" and its own syslib*.*i
# and we compare the results with what we get by running "sick" instead;
# this not only tests the optimised syslib.o.iasm but also gives a further
# test to the runtime and other mechanisms

# PERVERSION: CLC-INTERCAL/Base t/17syslib.o.t 1.-94.-2.2

require './t/compiler-test';

my @tests = (0, 0, [], [], [], [], [], []);

my $prevsrc = '';
open(TESTS, '<', 't/syslib-tests') or die "syslib-tests: $!\n";
while (<TESTS>) {
    chomp;
    /^\s*$/ || /^\s*#/ and next;
    s/^([2-7])\s+(\d{4})\s+// or die "Invalid line in syslib-tests.$.: $_\n";
    my ($base, $label) = ($1, $2);
    my $splat = undef;
    my @in = ('');
    my $prn = "$base/$label";
    my $sep = '/';
    my @out = ('');
    my $source = '';
    while (s/^([\.:]\d)=(\d+)\s+//) {
	push @in, [$1, $2];
	$prn .= "$sep$2";
	$sep = ' ';
    }
    $source .= "PLEASE DO ($label) NEXT\n";
    $source eq $prevsrc and $source = undef;
    $sep = '/';
    if (s/^=>\s+//) {
	$_ .= ' ';
	while (s/^([\.:]\d)=(\d+)\s+//) {
	    push @out, [$1, $2];
	    $prn .= "$sep$2";
	    $sep = ' ';
	}
	/\S/ and die "Invalid line in syslib-tests.$.: $_\n";
    } elsif (s/^\*\s*//) {
	$splat = '';
	$out[0] = '*274';
	$prn .= '*';
    } else {
	die "Invalid line in syslib-tests.$.: $_\n";
    }
    $prn =~ s/ $//;
    push @{$tests[$base]}, [$prn, \@in, \@out, $splat, $source];
    defined $source and $prevsrc = $source;
}
close TESTS;

#$cobj->setoption(verbose => Language::INTERCAL::GenericIO->new('FILE', 'r', \*STDERR));
$cobj->setoption(optimise => 1);
$cobj->setoption(library_rule => ['syslib.i', 'syslib.o.io', undef, undef, 2, undef]);
$cobj->setoption(library_rule => ['syslib@.@i', 'syslib.o.io', undef, undef, '@', 2]);

my $maxtest = 0;
runlist(\$maxtest, undef, undef, $tests[$_]) for (2..7);
print "1..$maxtest\n";
my $numtest = 0;
for my $base (2..7) {
    runlist(\$numtest, ['ick', $base], 'DO GIVE UP', $tests[$base]);
}

