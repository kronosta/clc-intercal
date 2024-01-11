# Check that the compiler can cope with floatlib.i

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# This is the same as 19floatlib.o.t however it only runs if environment
# variable $ICK_SYSLIB_DIR points to a directory containing C-INTERCAL's
# floatlib.i; if the variable is unset or empty, this test is skipped

# PERVERSION: CLC-INTERCAL/Base t/20floatlib.i.t 1.-94.-2.2

if (! ($ENV{ICK_SYSLIB_DIR} && -d $ENV{ICK_SYSLIB_DIR})) {
    print "1..0 # skipped: see the documentation to run this test\n";
    exit 0;
}

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
$cobj->setoption(library_rule => ['syslib.i', 'syslib.o.io', undef, undef, 2, undef]);
$cobj->setoption(library_rule => ['floatlib.i', '', undef, undef, 2, undef]);
$cobj->setoption(library_search => $ENV{ICK_SYSLIB_DIR});

$| = 1;
runtest('ick', 'DO GIVE UP', \@tests);

