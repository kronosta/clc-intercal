#!/usr/bin/perl -w

# This script runs all tests defined for CLC-INTERCAL

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use TAP::Harness;

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL build/all_tests.pl 1.-94.-2.3") =~ /\s(\S+)$/;

$ENV{LC_COLLATE} = 'C'; # to get repeatable sorts
$ENV{PERL_DL_NONLAZY} = 1;

my $base = undef;
my @dirs = ();
my @tests = ();
open(MF, '<', 'MANIFEST') or die "MANIFEST: $!\n";
{
    my @progs;
    while (<MF>) {
	chomp;
	if (s/^t\///) {
	    s/\b\s.*$//s;
	    /\.t$/ or next;
	    -f "t/$_" or die "t/$_: $!\n";
	    push @progs, $_;
	    next;
	}
	if (s/^#SICK\s+\S+\.tar\.gz\s+\b//) {
	    if (/CLC-INTERCAL-Base/) {
		defined $base and die "Multiple Base directories?\n";
		$base = $_;
	    } else {
		push @dirs, $_;
	    }
	    next;
	}
    }
    push @tests, map { "t/$_" } sort @progs;
}
close MF;
defined $base or die "No Base directory found\n";
@dirs = ($base, sort @dirs);

for my $ent (@dirs) {
    open(MF, '<', "$ent/MANIFEST") or die "$ent/MANIFEST\n";
    my @progs;
    while (<MF>) {
	s/^t\/// or next;
	s/\b\s.*$//s;
	/\.t$/ or next;
	-f "$ent/t/$_" or die "$ent/t/$_: $!\n";
	push @progs, $_;
    }
    close MF;
    push @tests, map { "$ent/t/$_" } sort @progs;
}

my $harness = TAP::Harness->new({
    verbosity => $ENV{TEST_VERBOSE} || 0,
    failures  => 1,
    exec      => [$^X, './build/run_test.pl'],
});
my $aggregator = $harness->runtests(@tests);
exit ($aggregator->all_passed ? 0 : 1);

