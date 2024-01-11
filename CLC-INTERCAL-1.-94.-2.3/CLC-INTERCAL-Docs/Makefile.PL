#!/usr/bin/perl -w

eval 'exec perl -S $0 ${1+"$@"}'
    if 0;

# This script will create the Makefile to build CLC-INTERCAL's documentation

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

require 5.005;
use strict;
use File::Spec::Functions qw(catfile curdir updir catdir);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Docs Makefile.PL 1.-94.-2.3") =~ /\s(\S+)$/;

my $in_bundle = $ENV{CLC_INTERCAL_BUNDLE} && $ENV{CLC_INTERCAL_BUNDLE} eq '42' && $ENV{CLC_INTERCAL_ROOT};

for my $module (qw(InstallModule Exporter)) {
    if ($in_bundle) {
	eval {
	    require (catfile($ENV{CLC_INTERCAL_ROOT}, 'INTERCAL', "$module.pm"));
	    eval "import Language::INTERCAL::$module '$VERSION';";
	    die $@ if $@;
	};
    } else {
	eval "use Language::INTERCAL::$module '$VERSION';";
    }
    if ($@) {
	$@ =~ /can't locate/i and die "You don't appear to have CLC-INTERCAL installed:\n$@";
	die "Error loading the CLC-INTERCAL installer:\n$@";
    }
}

my $html_dir = 'doc/html';
my $html_suffix = 'html';
my $htmlgen_suffix = 'hgen';
my $examples_dir = 'doc/examples';

my @htmlcopy = ();
my @htmlgen = ();
my @examples = ();

Language::INTERCAL::InstallModule::add_extra(
    manifest  => \&manifest,
    constants => \&constants,
    postamble => \&postamble,
    usemodule => 'INET',
);

install Language::INTERCAL::InstallModule 'Docs',
    generate => 1;

sub manifest {
    if (s#^$html_dir/##o) {
	push @htmlcopy, $1 if /^(.*\.$html_suffix)$/o;
	push @htmlgen, $1 if /^(.*)\.$htmlgen_suffix$/o;
    }
    if (s#^$examples_dir/##o) {
	push @examples, $_;
    }
}

sub constants {
    my $i = '';
    $i .= "INST_HTMLDOC = blib/htmldoc\n";
    $i .= "INST_HTMLEX = blib/htmlexamples\n";
    $i;
}

sub postamble {
    my $i = '';
    $i .= <<EOI for @htmlcopy;
all :: \$(INST_HTMLDOC)/$_
	\$(NOECHO) \$(NOOP)

\$(INST_HTMLDOC)/$_ : \$(INST_HTMLDOC)/\$(DFSEP).exists $html_dir/$_
	\$(CP) $html_dir/$_ \$(INST_HTMLDOC)/$_

EOI

    $i .= <<EOI for @htmlgen;
all :: \$(INST_HTMLDOC)/$_.$html_suffix
	\$(NOECHO) \$(NOOP)

\$(INST_HTMLDOC)/$_.$html_suffix : \$(INST_HTMLDOC)/\$(DFSEP).exists $html_dir/$_.$htmlgen_suffix
	\$(PM_FILTER) $html_dir/$_.$htmlgen_suffix \$(INST_HTMLDOC)/$_.$html_suffix

EOI

    $i .= "\$(INST_HTMLDOC)/\$(DFSEP).exists :: Makefile.PL\n"
	. "\t\$(NOECHO) \$(MKPATH) \$(INST_HTMLDOC)\n"
	. "\t\$(NOECHO) \$(CHMOD) 755 \$(INST_HTMLDOC)\n"
	. "\t\$(NOECHO) \$(TOUCH) \$(INST_HTMLDOC)/\$(DFSEP).exists\n\n";

    if (@examples) {
	$i .= <<EOI;
all :: \$(INST_HTMLEX)/clc-intercal.css
	\$(NOECHO) \$(NOOP)

\$(INST_HTMLEX)/clc-intercal.css : \$(INST_HTMLEX)/.exists clc-intercal.css
	\$(CP) clc-intercal.css \$(INST_HTMLEX)/clc-intercal.css

EOI

	my %exdir = ();
	for my $ex (@examples) {
	    my $dir = '';
	    my $down = '';
	    (my $dst = $ex) =~ s|\.[^.]*$|.html|;
	    if ($ex =~ m|^(.*)/|) {
		my $count = "/$1";
		$dir = $count;
		(my $ep = $ex) =~ s|^.*/||;
		(my $dp = $dst) =~ s|^.*/||;
		push @{$exdir{$dir}}, [$ep, $dp];
		$down .= '../' while $count =~ s|^/[^/]+||;
	    } else {
		push @{$exdir{''}}, [$ex, $dst];
	    }
	    $i .= <<EOI;
all :: \$(INST_HTMLEX)/$dst
	\$(NOECHO) \$(NOOP)

\$(INST_HTMLEX)/$dst : \$(INST_HTMLEX)$dir/.exists $examples_dir/$ex
	\$(SICK) -lNone -Lhtml=${down}clc-intercal.css --output \$(INST_HTMLEX)/$dst $examples_dir/$ex

EOI
	}

	for my $ex (sort keys %exdir) {
	    my $parent = '';
	    $ex =~ m|^(.*)/[^/]*$| and $parent = "\$(INST_HTMLEX)/$1/.exists";
	    $i .= "\$(INST_HTMLEX)$ex/.exists :: $parent Makefile.PL\n"
		. "\t\$(NOECHO) \$(MKPATH) \$(INST_HTMLEX)$ex\n"
		. "\t\$(NOECHO) \$(CHMOD) 755 \$(INST_HTMLEX)$ex\n"
		. "\t\$(NOECHO) \$(TOUCH) \$(INST_HTMLEX)$ex/.exists\n\n";
	    my $deps = '';
	    my $srcs = '';
	    for my $fn (@{$exdir{$ex}}) {
		$deps .= " \\\n\t\t\$(INST_HTMLEX)$ex/$fn->[1]";
		$srcs .= " \\\n\t\t\$(INST_HTMLEX)$ex/$fn->[1] $fn->[0]";
	    }
	    my $up = $parent eq '' ? '0' : '1';
	    my $re = qr|^\Q$ex\E/([^/]+)$|;
	    for my $ed (sort keys %exdir) {
		$ed =~ $re and $up .= " $1";
	    }
	    $i .= "\$(INST_HTMLEX)$ex/index.html :: \$(INST_HTMLEX)$ex/.exists$deps Makefile.PL gettitle\n"
		. "\t\$(NOECHO) \$(PERL) gettitle /$ex $up -- $srcs > \$(INST_HTMLEX)$ex/index.html\n\n";
	    $i .= "all :: \$(INST_HTMLEX)$ex/index.html\n"
		. "\t\$(NOECHO) \$(NOOP)\n\n";
	}
    }

    $i;
}

1;
