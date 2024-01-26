package Language::INTERCAL::GenericIO::STRING;

# Write/read data from/to Perl string

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/STRING.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use IO::File;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_IOERR);
use Language::INTERCAL::GenericIO '1.-94.-2';
use Language::INTERCAL::GenericIO::FILE '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO::FILE Language::INTERCAL::GenericIO);

sub _new {
    @_ == 3 or croak
	"Usage: new Language::INTERCAL::GenericIO::STRING(MODE, DATA)";
    my ($object, $mode, $data) = @_;
    ref $data && 'SCALAR' eq ref $data or croak "DATA must be a scalar ref";
    my $fh;
    open($fh, '+<', $data) or faint(SP_IOERR, '(string)', $!);
    $mode =~ /w/ or seek $fh, 0, SEEK_END;
    $object->{filedata}{handle} = $fh;
}

sub is_terminal { 0 }

1
