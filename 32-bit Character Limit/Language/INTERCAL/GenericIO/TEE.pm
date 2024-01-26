package Language::INTERCAL::GenericIO::TEE;

# Read data to multiple files

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/TEE.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::GenericIO '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

sub _new {
    @_ == 3 or croak
	"Usage: new Language::INTERCAL::GenericIO::TEE(MODE, LIST)";
    my ($object, $mode, $data) = @_;
    $mode =~ /[ar]/ or croak "MODE must be \"read\" when TYPE is TEE";
    ref $data && 'ARRAY' eq ref $data or croak "DATA must be a array ref";
    $object->{filedata} = $data;
}

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $string) = @_;
    for my $tee (@{$object->{filedata}}) {
	$tee->read_binary($string);
    }
    $object;
}

sub _write_code { return '' }
sub _write_text_code { return '' }

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    my ($object) = @_;
    return "TEE(" .
	   join(',', map { $_->describe } @{$object->{filedata}}) .
	   ")";
}

sub is_terminal {
    @_ == 1 or croak "Usage: IO->is_terminal";
    my ($object) = @_;
    # if any of the files is a terminal, the whole TEE is a terminal; the idea
    # is that is_terminal() is used to decide whether to produce prompts
    for my $f (@{$object->{filedata}}) {
	$f->is_terminal and return 1;
    }
    0;
}

1;
