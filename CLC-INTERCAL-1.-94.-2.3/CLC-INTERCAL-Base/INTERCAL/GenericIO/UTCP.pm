package Language::INTERCAL::GenericIO::UTCP;

# Write/read data from/to TCP socket (without calls to INTERCAL::Server)

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/UTCP.pm 1.-94.-2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::GenericIO::TCP '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO::TCP);

sub _new {
    @_ == 4 or croak
	"Usage: new Language::INTERCAL::GenericIO::UTCP(MODE, ADDR, SERVER)";
    my ($object, $mode, $data, $server) = @_;
    $object->SUPER::_new($mode, $data, $server);
    $object->{filedata}{progress} = 0;
}

1;
