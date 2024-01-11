package Language::INTERCAL::GenericIO::TCP;

# Write/read data from/to TCP socket

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO/TCP.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::GenericIO '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

sub _new {
    @_ == 4 or croak
	"Usage: new Language::INTERCAL::GenericIO::TCP(MODE, ADDR, SERVER)";
    my ($object, $mode, $data, $server) = @_;
    $data =~ s/:(\w+)$//
	or croak "DATA must be host:port when TYPE is $object->{type}";
    my $port = $1;
    my $host = $data;
    my $id = $server->tcp_socket($data, $port);
    $object->{filedata} = {
	server => $server,
	id => $id,
	host => $host,
	port => $port,
	progress => 1,
    };
}

sub is_terminal { 0 }

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $string) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    $server->read_binary($id, $string);
}

sub _write_code {
    my ($object, $size) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    my $progress = $object->{filedata}{progress};
    $server->write_binary($id, $size, $progress);
}

sub _write_text_code {
    my ($object, $newline) = @_;
    my $index = index($object->{buffer}, $newline);
    while ($index < 0) {
	my $data = $object->_write_code(1);
	if ($data ne '') {
	    $object->{buffer} .= $data;
	    $index = index($object->{buffer}, $newline);
	} else {
	    $index = length($object->{buffer});
	    last;
	}
    }
    substr($object->{buffer}, 0, $index, '');
}

sub DESTROY {
    my ($object) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    $server and eval { $server->tcp_socket_close($id); };
}

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    my ($object) = @_;
    my $host = $object->{filedata}{host};
    my $port = $object->{filedata}{port};
    my $type = $object->{type};
    return "$type($host:$port)";
}

1;
