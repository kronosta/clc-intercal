#!/usr/bin/perl -w

eval 'exec perl -S $0 ${1+"$@"}'
    if 0;

# This script will create the Makefile to build and install CLC-INTERCAL

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.
;
use Cwd 'cwd';
use File::Spec::Functions qw(catfile);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base Makefile.PL 1.-94.-2.3") =~ /\s(\S+)$/;

require (catfile(cwd(), qw(INTERCAL Exporter.pm)));
require (catfile(cwd(), qw(INTERCAL InstallModule.pm)));

import Language::INTERCAL::InstallModule $VERSION;
install Language::INTERCAL::InstallModule 'Base',
    prereq => {
	'Carp' => 0,
	'Cwd' => 0,
	'File::Basename' => 0,
	'File::Spec' => 0,
	'Getopt::Long' => 0,
	'IO::File' => 0,
	'IO::Handle' => 0,
    },
    generate => 1;

1;
