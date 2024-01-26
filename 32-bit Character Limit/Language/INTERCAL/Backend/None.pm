package Language::INTERCAL::Backend::None;

# No-op backend: this doesn't do anything

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend/None.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.3';

use constant default_suffix => undef; # means we don't want a file
use constant default_mode   => undef; # means we don't want a file

sub generate { 1; } # not much to do for a no-op

1;
