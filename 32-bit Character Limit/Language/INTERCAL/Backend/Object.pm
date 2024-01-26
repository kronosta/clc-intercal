package Language::INTERCAL::Backend::Object;

# Back end to write object to a filehandle

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend/Object.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';

use constant default_suffix => 'io';
use constant default_mode => 0777; # objects are not now executable

sub generate {
    @_ == 5 or croak "Usage: BACKEND->generate(INTERPRETER, NAME, HANDLE, OPTIONS)";
    my ($class, $int, $name, $filehandle, $options) = @_;
    $int->read($filehandle, $options->{build} ? 0 : 1);
}

1;
