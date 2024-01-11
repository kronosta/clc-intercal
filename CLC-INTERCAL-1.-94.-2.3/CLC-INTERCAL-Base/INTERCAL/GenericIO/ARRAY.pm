package Language::INTERCAL::GenericIO::ARRAY;

# Write/read data from/to Perl array

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/ARRAY.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::GenericIO '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

sub _new {
    @_ == 3 or croak
	"Usage: new Language::INTERCAL::GenericIO::ARRAY(MODE, DATA)";
    my ($object, $mode, $data) = @_;
    ref $data && 'ARRAY' eq ref $data or croak "DATA must be a array ref";
    $object->{filedata} = $data;
}

sub is_terminal { 0 }

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $string) = @_;
    push @{$object->{filedata}}, $string;
}

sub _write_code {
    my ($object, $size) = @_;
    my $data = $object->{filedata};
    return '' unless @$data;
    my $line = shift @$data;
    while (@$data && length($line) < $size) {
	$line .= shift @$data;
    }
    if (length($line) > $size) {
	unshift @$data, substr($line, $size);
	$line = substr($line, 0, $size);
    }
    $line;
}

sub _write_text_code {
    my ($object, $newline) = @_;
    my $data = $object->{filedata};
    return '' unless @$data;
    my $line = shift @$data;
    my $index = index($line, $newline);
    while (@$data && $index < 0) {
	$line .= shift @$data;
	$index = index($line, $newline);
    }
    if ($index >= 0) {
	$index += length $newline;
	unshift @$data, substr($line, $index);
	$line = substr($line, 0, $index);
    }
    $line;
}

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    return 'ARRAY';
}

1;
