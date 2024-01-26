package Language::INTERCAL::Distribute;

# Create dd/sh distribution

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
my $preversion;
($preversion, $VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Distribute.pm 1.-94.-2.3") =~ /^(.*\s)(\S+)$/;

sub use_test {
    my ($package, @depend) = @_;
    for my $d (@depend) {
	eval "require $d";
	$@ or next;
	print "1..0 # skipped: dependency $d not installed\n";
	exit 0;
    }

    $package eq '' or $package = "/$package";

    open(MANIFEST, 'MANIFEST') or do { print "1..0 # skipped: no MANIFEST?\n"; exit 0; };

    my @module_tests = ();
    my @script_tests = ();
    my @perl_tests = ();
    my @misc_tests = ();
    my %links = ();
    while (<MANIFEST>) {
	chomp;
	my $orig = $_;
	if (m#^(INTERCAL/\S+)\.pm\s+(\S+)$#) {
	    my ($mod, $perv) = ($1, $2);
	    $orig =~ s/\s+\S+$//;
	    push @module_tests, [$mod, $perv, $orig];
	    next;
	}
	if (m#^(links/\S+\.pm)\s+(\S+)$#) {
	    my ($mod, $perv) = ($1, $2);
	    $orig =~ s/\s+\S+$//;
	    $links{$mod} = $perv;
	    next;
	}
	if (m#^bin/(\S+)\s+(\S+)$#) {
	    push @script_tests, [$1, "bin/$1", $2];
	    next;
	}
	if (m#^(\S+\.p[lm]|aux/mk\S*|Generate|t/00use\.t)\s+(\S+)$#i) {
	    push @perl_tests, [$1, $2];
	    next;
	}
	if (m#^(\S+)\s+(\S+)$#) {
	    push @misc_tests, [$1, $2];
	    next;
	}
    }
    close MANIFEST;

    if (open(MAKEFILE, 'Makefile')) {
	while (<MAKEFILE>) {
	    /^##+\s+(?:XS|PM)\s+##+\s+(\S+)\s+##+\s+(\S+\.pm)\s+#/ or next;
	    my ($from, $to) = ($1, $2);
	    exists $links{$from} or next;
	    my $perv = delete $links{$from};
	    push @perl_tests, [$from, $perv];
	}
	close MAKEFILE;
    }

    $| = 1;
    my $testno = 3 * (@module_tests + @script_tests + @perl_tests) + @misc_tests;

    print "1..$testno\n";

    $testno = 1;
    for my $m (@module_tests) {
	my ($mfile, $perv, $ofile) = @$m;
	my $mname = $mfile;
	$mname =~ s#/+#::#g;
	$mname =~ s#^/*#Language::#;
	mtest($package, $testno, $mname, $perv, $mfile, $ofile);
	$testno += 2;
	vtest($testno, $ofile, $perv);
	$testno++
    }

    for my $s (@script_tests) {
	my ($sfile, $ofile, $perv) = @$s;
	my $src = -f "blib/script/$sfile" ? "blib/script/$sfile" : "bin/$sfile";
	stest($package, $testno, $ofile, $src, $perv);
	$testno += 2;
	vtest($testno, $ofile, $perv);
	$testno++
    }

    for my $s (@perl_tests) {
	my ($sfile, $perv) = @$s;
	stest($package, $testno, $sfile, $sfile, $perv);
	$testno += 2;
	vtest($testno, $sfile, $perv);
	$testno++
    }

    for my $m (@misc_tests) {
	my ($sfile, $perv) = @$m;
	xtest($package, $testno, $sfile, $perv);
	$testno++
    }

    return 0;
}

sub etest {
    my ($test, $eval, $err) = @_;
    eval $eval;
    if ($@) {
	$err ||= $eval;
	print STDERR "$err: $@";
	print 'not ';
    }
    print "ok $test\n";
}

sub mtest {
    my ($package, $test, $module, $perv, $mfile, $ofile) = @_;
    etest($test, "require $module; import $module '$perv'");
    my $ok = eval "defined \$${module}::PERVERSION";
    my $regex = qr/^CLC-INTERCAL\Q$package\E\s+\Q$ofile $perv\E$/;
    $ok &&= eval("\$${module}::PERVERSION") =~ $regex;
    etest($test + 1, $ok ? '1' : 'die("PerVersion string mismatch\n")',
	  "Check Perversion Number ($module)");
}

sub stest {
    my ($package, $test, $script, $src, $perv) = @_;
    if (open(SCRIPT, '<', $src)) {
	my $text = '';
	my $pervcode = undef;
	my $in_string = undef;
	while (<SCRIPT>) {
	    last if ! defined $in_string && /^__(?:END|DATA)__$/;
	    $text .= $_;
	    if (defined $in_string) {
		if (substr($_, 0, length $in_string) eq $in_string) {
		    $in_string = undef;
		}
	    } elsif (/<<\s*(\w+)/) {
		$in_string = $1;
	    }
	    next if defined $pervcode || ! /PERVERSION\s*=/;
	    chomp;
	    $pervcode = $_;
	}
	close SCRIPT;
	eval "local \$^W = 0; no strict; no warnings; sub SUB$test { $text }";
	if ($@) {
	    print STDERR "$script: $@";
	    print "not ok ", $test++, "\n";
	    print "not ok ", $test++, "\n";
	} else {
	    undef &{"SUB$test"};
	    print "ok ", $test++, "\n";
	    if (defined $pervcode) {
		my $perversion = eval "$pervcode; \$PERVERSION";
		if ($@) {
		    print STDERR $@;
		    print "not ok ", $test++, "\n";
		} elsif ( $perversion =~ /^CLC-INTERCAL\Q$package\E\s+\Q$script $perv\E$/) {
		    print "ok ", $test++, "\n";
		} else {
		    print STDERR "$script: perversion string mismatch ($perversion)\n";
		    print "not ok ", $test++, "\n";
		}
	    } else {
		print STDERR "$script: perversion not defined\n";
		print "not ok ", $test++, "\n";
	    }
	}
    } else {
	print STDERR "$src: $!\n";
	print "not ok ", $test++, "\n";
	print "not ok ", $test++, "\n";
    }
}

sub vtest {
    # check that $ofile has a version number in a way we understand
    my ($test, $ofile, $perv) = @_;
    eval {
	my $v;
	open (my $fh, '<', $ofile);
	while (<$fh>) {
	    /PERVERSION\s*=/ or next;
	    local ($VERSION, $PERVERSION);
	    eval "{ $_ } \$v = \$VERSION";
	    last;
	}
	close $fh;
	$v eq $perv or die "$ofile: inconsistent version number (parsed: $v, expected: $perv)\n";
    };
    if ($@) {
	print STDERR $@;
	print "not ok $test\n";
    } else {
	print "ok $test\n";
    }
}

sub xtest {
    # check that $ofile has a version number in a comment somewhere
    my ($package, $test, $ofile, $perv) = @_;
    eval {
	my $qr = qr#\bPERVERSION\b.*\bCLC-INTERCAL\Q$package\E\s+\Q$ofile\E\s+(\S+)\b#;
	my $v;
	open (my $fh, '<', $ofile);
	while (<$fh>) {
	    chomp; # for some reason without this the regexp match fails on the test scripts
	    $_ =~ $qr or next;
	    $v = $1;
	    last;
	}
	close $fh;
	$v eq $perv or die "$ofile: inconsistent version number (parsed: $v, expected: $perv)\n";
    };
    if ($@) {
	print STDERR $@;
	print "not ok $test\n";
    } else {
	print "ok $test\n";
    }
}

1;
