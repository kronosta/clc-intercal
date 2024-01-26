package Language::INTERCAL::GenericIO::COUNT;

# Pseudo-file, behaves like a write-only INTERCAL GenericIO object but does not
# store the data anywhere, only the data size.

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/COUNT.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::GenericIO '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

sub _new {
    @_ == 3 or croak
	"Usage: new Language::INTERCAL::GenericIO::COUNT(MODE, DATA)";
    my ($object, $mode, $data) = @_;
    $mode =~ /[ar]/ or croak "MODE must be \"read\" when TYPE is COUNT";
    ref $data && 'SCALAR' eq ref $data or croak "DATA must be a scalar ref";
    $object->{filedata} = $data;
}

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $string) = @_;
    ${$object->{filedata}} += length($string);
    $object;
}

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    my ($object) = @_;
    my $data = $object->{filedata};
    return "COUNT($$data)";
}

sub is_terminal { 0 }

1;
