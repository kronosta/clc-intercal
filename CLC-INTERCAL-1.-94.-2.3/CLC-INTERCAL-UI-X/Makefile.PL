#!/usr/bin/perl -w

eval 'exec perl -S $0 ${1+"$@"}'
    if 0;

# This script will create the Makefile to build and install a graphical
# user interface for CLC-INTERCAL

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

require 5.005;
use strict;
use File::Spec::Functions qw(catfile);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/UI-X Makefile.PL 1.-94.-2.3") =~ /\s(\S+)$/;

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

my $Gtk;
BEGIN {
    eval {
	require Gtk3;
	import Gtk3;
	$Gtk = 'Gtk3';
    };
    defined $Gtk or eval {
	require Gtk2;
	import Gtk2;
	$Gtk = 'Gtk2';
    };
};
defined $Gtk or $Gtk = 'Gtk3'; # make the warning message request Gtk3

install Language::INTERCAL::InstallModule 'UI-X',
    prereq => {
	$Gtk => 0,
    };

1;
