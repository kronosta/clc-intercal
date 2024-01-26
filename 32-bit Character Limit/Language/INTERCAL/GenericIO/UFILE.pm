package Language::INTERCAL::GenericIO::UFILE;

# Write/read data from/to file (using sysread, syswrite, etc)

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/UFILE.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use IO::File;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_IOERR);
use Language::INTERCAL::GenericIO::FILE '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO::FILE);

# just override as much of Language::INTERCAL::GenericIO::FILE as
# necessary

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $data) = @_;
    while ($data ne '') {
	my $done = $object->{filedata}{handle}->syswrite($data);
	$done or faint(SP_IOERR, $object->{data}, $!);
	substr($data, 0, $done) = '';
    }
    $object;
}

sub _write_code {
    my ($object, $size) = @_;
    my $data = '';
    $object->{filedata}{handle}->sysread($data, $size);
    $data;
}

sub _write_text_code {
    my ($object, $newline) = @_;
    my $index = index($object->{buffer}, $newline);
    my $diff = length($newline);
    while ($index < 0) {
	my $data = '';
	if ($object->{filedata}{handle}->sysread($data, 1024)) {
	    $object->{buffer} .= $data;
	    $index = index($object->{buffer}, $newline);
	} else {
	    $index = length($object->{buffer});
	    $diff = 0;
	    last;
	}
    }
    substr($object->{buffer}, 0, $index + $diff, '');
}

sub tell {
    @_ == 1 or croak "Usage: IO->tell";
    my ($object) = @_;
    sysseek($object->{filedata}{handle}, 0, SEEK_CUR);
}

sub seek {
    @_ == 2 || @_ == 3
	or croak "Usage: IO->seek(POS [, RELATIVE_TO])";
    my ($object, $pos, $rel) = @_;
    sysseek($object->{filedata}{handle}, $pos, $rel);
    $object->{buffer} = '';
    $object;
}

sub reset {
    @_ == 1 or croak "Usage: IO->reset";
    my ($object) = @_;
    sysseek($object->{filedata}{handle}, 0, SEEK_SET);
    $object->{buffer} = '';
    $object;
}

1;
