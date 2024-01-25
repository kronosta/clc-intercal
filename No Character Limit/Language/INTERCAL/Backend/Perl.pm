package Language::INTERCAL::Backend::Perl;

# Produce a Perl executable

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# same as Object backend, with a different file extension

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend/Perl.pm 1.-94.-2") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Backend::Object '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::Backend::Object);

use constant default_suffix => 'pl';

1;
