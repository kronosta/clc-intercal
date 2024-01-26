package Language::INTERCAL::GenericIO::OBJECT;

# Write/read data from/to Perl object

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/OBJECT.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import is_object);
use Language::INTERCAL::GenericIO '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

sub _new {
    @_ == 3 or croak
	"Usage: new Language::INTERCAL::GenericIO::OBJECT(MODE, OBJECT)";
    my ($object, $mode, $data) = @_;
    ref $data or croak "DATA must be a reference";
    is_object($data) or croak "DATA must be an object";
    $object->{filedata} = $data;
}

sub is_terminal { 0 }

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $string) = @_;
    $object->{filedata}->read($string);
}

sub _write_code {
    my ($object, $size) = @_;
    $object->{filedata}->write($size);
}

sub _write_text_code {
    my ($object, $newline) = @_;
    my $data = $object->{filedata};
    my $line = $object->{filedata}->write(1);
    defined $line && $line ne '' or return '';
    my $index = index($line, $newline);
    while ($index < 0) {
	my $add = $object->{filedata}->write(1);
	defined $add && $add ne '' or return '';
	$line .= $add;
	$index = index($line, $newline);
    }
    $line;
}

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    return 'OBJECT';
}

1;
