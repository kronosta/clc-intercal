# Check that the compiler can cope with floatlib.i

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# Test our optimised version of floatlib.i, which we can find in floatlib.o.iasm
# somewhere in the sources; note that unlike floatlib.i, the optimised version
# does not rely on syslib.i, but it does rely on perl doing arithmetic

# PERVERSION: CLC-INTERCAL/Base t/19floatlib.o.t 1.-94.-2.2

require './t/compiler-test';

my @tests;

my $prevsrc = '';
open(TESTS, '<', 't/floatlib-tests') or die "floatlib-tests: $!\n";
while (<TESTS>) {
    chomp;
    /^\s*$/ || /^\s*#/ and next;
    s/^(\d{4})\s+// or die "Invalid line in floatlib-tests.$.: $_\n";
    my $label = $1;
    my $splat = undef;
    my @in = ('');
    my $prn = "$label";
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
	/\S/ and die "Invalid line in floatlib-tests.$.: $_\n";
    } elsif (s/^\*\s*//) {
	$splat = '';
	$out[0] = '*000|274';
	$prn .= '*';
    } else {
	die "Invalid line in floatlib-tests.$.: $_\n";
    }
    $prn =~ s/ $//;
    push @tests, [$prn, \@in, \@out, $splat, $source];
    defined $source and $prevsrc = $source;
}
close TESTS;

#$cobj->setoption(verbose => Language::INTERCAL::GenericIO->new('FILE', 'r', \*STDERR));
$cobj->setoption(optimise => 1);
# use the optimised syslib but build floatlib from sources - we aren't testing
# syslib here and the thing is slow enough as it is; we do this by pretending
# to be optimising, but specifying an invalid object for the optimised floatlib.i
# so the non-optimised one will be used as fallback
$cobj->setoption(library_rule => ['floatlib.i', 'floatlib.o.io', undef, undef, 2, undef]);

$iseq = \&iseq;
runtest('ick', 'DO GIVE UP', \@tests);

# floatlib.i doesn't seem to have great precision, so the results we get often
# differ in the least significant bits
sub iseq {
    my ($a, $b, $r, $name) = @_;
    # however conversions to integers have to be exact
    $r =~ /^\./ and return $a == $b;
    $name =~ /^50[78]0/ and return $a == $b;
    # exponential return random values on overflow and we
    # can't provide the exact same value
    $name =~ /^5120\/.* [23]$/ and return 1;
    $a < $b + 2 && $a > $b - 2;
}

