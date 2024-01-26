package Language::INTERCAL::Backend::Run;

# Back end to run object in memory

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend/Run.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.1';

use constant default_suffix => undef; # means we don't want a file
use constant default_mode   => undef; # means we don't want a file

sub generate {
    @_ == 5 or croak "Usage: BACKEND->generate(INTERPRETER, NAME, HANDLE, OPTIONS)";
    my ($class, $int, $name, $filehandle, $options) = @_;
    $int->start()->run()->stop();
}

1;
