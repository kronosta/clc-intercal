#!/usr/bin/perl -w

# This script runs one or more tests; it is meant to be called by all_tests.pl

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Cwd;

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL build/run_test.pl 1.-94.-2.3") =~ /\s(\S+)$/;

my $top = getcwd;

for my $test (@ARGV) {
    # XXX we could use File::Spec for portability
    my @test = split(/\/+/, $test);
    my $name = pop @test; # name of test
    $test[-1] eq 't' or die "Invalid path to test program: $test\n";
    pop @test; # "t" directory
    my $libs = join('/', $top, @test);
    chdir $libs or die "$libs: $!\n";
    my @libs;
    if (@test) {
	@libs = ("-I$libs/blib/lib", "-I$libs/blib/arch");
	if ($test[-1] =~ s/CLC-INTERCAL-(.*)$/CLC-INTERCAL-Base/) {
	    my $sublibs = join('/', $top, @test);
	    push @libs, ("-I$sublibs/blib/lib", "-I$sublibs/blib/arch");
	}
    } else {
	    push @libs, ("-ICLC-INTERCAL-Base/blib/lib", "-ICLC-INTERCAL-Base/blib/arch");
    }
    push @libs, "-I$libs";
    if (system($^X, @libs, "./t/$name", 'toplevel') != 0) {
	$? == -1 and die "Cannot run $test: $!\n";
	$? & 0x7f and die "$test exited with signal " . ($? & 0x7f) . "\n";
	die "$test exited with status " . ($? >> 8);
    }
}
exit 0;

