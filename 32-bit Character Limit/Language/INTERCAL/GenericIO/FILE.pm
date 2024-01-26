package Language::INTERCAL::GenericIO::FILE;

# Write/read data from/to file

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/FILE.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use IO::File;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import has_type);
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_IOERR);
use Language::INTERCAL::GenericIO '1.-94.-2.1';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

my $stdio_seen_utf8 = 0;

sub _new {
    @_ == 3 or croak
	"Usage: new Language::INTERCAL::GenericIO::FILE(MODE, NAME)";
    my ($object, $mode, $data) = @_;
    my $filemode = $mode;
    $filemode =~ tr/rw/wr/;
    $filemode = 'r+' if $filemode =~ /u/;
    $object->{filedata} = {};
    my $fh;
    if (ref $data && has_type($data, 'GLOB')) {
	$fh = $data;
	$fh == \*STDIN || $fh == \*STDOUT || $fh == \*STDERR
	    and $object->set_utf8_hack(\$stdio_seen_utf8);
    } elsif ($data eq '-' || $data eq '-1') {
	$fh = $mode =~ /r/ ? \*STDOUT : \*STDIN;
	$object->set_utf8_hack(\$stdio_seen_utf8);
    } elsif ($data eq '-2') {
	$fh = \*STDERR;
	$object->set_utf8_hack(\$stdio_seen_utf8);
    } else {
	$fh = new IO::File($data, $filemode) or faint(SP_IOERR, $data, $!);
	# $fh->autoflush(1);
	$object->{filedata}{to_close} = $fh;
    }
    $object->{filedata}{handle} = $fh;
}

sub is_terminal { 
    @_ == 1 or croak "Usage: IO->is_terminal";
    my ($object) = @_;
    -t $object->{filedata}{handle};
}

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $data) = @_;
    print { $object->{filedata}{handle} } $data
	or faint(SP_IOERR, $object->{data}[0], $!);
}

sub _write_code {
    my ($object, $size) = @_;
    my $data = '';
    read $object->{filedata}{handle}, $data, $size;
    $data;
}

sub _write_text_code {
    my ($object, $newline) = @_;
    local $/ = $newline;
    my $fh = $object->{filedata}{handle};
    my $data = <$fh>;
    defined $data ? $data : '';
}

sub tell {
    @_ == 1 or croak "Usage: IO->tell";
    my ($object) = @_;
    tell($object->{filedata}{handle});
}

sub reset {
    @_ == 1 or croak "Usage: IO->reset";
    my ($object) = @_;
    seek($object->{filedata}{handle}, 0, SEEK_SET);
    $object->{buffer} = '';
    $object;
}

sub seek {
    @_ == 2 || @_ == 3
	or croak "Usage: IO->seek(POS [, RELATIVE_TO])";
    my ($object, $pos, $rel) = @_;
    $rel = SEEK_SET if ! defined $rel;
    seek($object->{filedata}{handle}, $pos, $rel);
    $object->{buffer} = '';
    $object;
}

sub DESTROY {
    my ($object) = @_;
    $object->{filedata}{to_close} and $object->{filedata}{to_close}->close();
}

1;
