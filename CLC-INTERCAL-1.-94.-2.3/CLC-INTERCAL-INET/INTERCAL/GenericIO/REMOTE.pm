package Language::INTERCAL::GenericIO::REMOTE;

# Write/read data from/to remote file

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/INET INTERCAL/GenericIO/REMOTE.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use IO::File;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2.2', qw(faint SP_INTERNET SP_SEEKERR);
use Language::INTERCAL::GenericIO '1.-94.-2';
use vars qw(@ISA);
@ISA = qw(Language::INTERCAL::GenericIO);

sub _new {
    @_ == 4 or croak
	"Usage: new Language::INTERCAL::GenericIO::REMOTE(MODE, ADDR, SERVER)";
    my ($object, $mode, $data, $server) = @_;
    $data =~ s/:(\w+)$//
	or croak "DATA must be host:port when TYPE is REMOTE";
    my $port = $1;
    my $host = $data;
    my $id = $server->tcp_socket($data, $port);
    my $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2/ or faint(SP_INTERNET, $host, $line);
    $object->{filedata} = {
	id => $id,
	server => $server,
	host => $host,
	port => $port,
    };
}

sub is_terminal {
    @_ == 1 or croak "Usage: IO->is_terminal";
    my ($object) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    $server->read_out($id, "ISTERM");
    my $line = $server->write_in($id, 1);
    my $host = $object->{filedata}{host};
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2/ or faint(SP_INTERNET, $host, $line);
    $line =~ /^285/ and return 1;
    0;
}

sub read_binary {
    @_ == 2 or croak "Usage: IO->read_binary(DATA)";
    my ($object, $data) = @_;
    my $len = length $data;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    my $host = $object->{filedata}{host};
    $server->read_out($id, "READ $len");
    my $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^3/ or faint(SP_INTERNET, $host, $line);
    $server->read_binary($id, $data);
    $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2/ or faint(SP_INTERNET, $host, $line);
    $object;
}

sub _write_code {
    my ($object, $size) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    my $host = $object->{filedata}{host};
    $server->read_out($id, "WRITE $size");
    my $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2\d+\s+(\d+)/ or faint(SP_INTERNET, $host, $line);
    my $len = $1;
    my $data = $server->write_binary($id, $len);
    defined $data or faint(SP_INTERNET, $host, 'Lost connection');
    length($data) == $len or faint(SP_INTERNET, $host, "Invalid data");
    $data;
}

sub _write_text_code {
    my ($object, $newline) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    my $host = $object->{filedata}{host};
    $newline =~ s/(\W)/sprintf("!%03d", ord($1))/ge;
    $server->read_out($id, "WRITE TEXT /$newline/");
    my $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2\d+\s+(\d+)/ or faint(SP_INTERNET, $host, $line);
    my $len = $1;
    my $data = $server->write_binary($id, $len);
    defined $data or faint(SP_INTERNET, $host, 'Lost connection');
    length($data) == $len or faint(SP_INTERNET, $host, "Invalid data");
    $data;
}

sub tell {
    @_ == 1 or croak "Usage: IO->tell";
    my ($object) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    my $host = $object->{filedata}{host};
    $server->read_out($id, 'TELL');
    my $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2\d+\s+(\d+)/ or faint(SP_INTERNET, $host, $line);
    return $1;
}

sub reset {
    @_ == 1 or croak "Usage: IO->reset";
    my ($object) = @_;
    $object->seek(0, SEEK_SET);
}

sub seek {
    @_ == 2 || @_ == 3
	or croak "Usage: IO->seek(POS [, RELATIVE_TO])";
    my ($object, $pos, $rel) = @_;
    if ($rel == SEEK_SET) {
	$rel = 'SET';
    } elsif ($rel == SEEK_CUR) {
	$rel = 'CUR';
    } elsif ($rel == SEEK_END) {
	$rel = 'END';
    } else {
	faint(SP_SEEKERR, "Invalid file position $rel");
    }
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    my $host = $object->{filedata}{host};
    $server->read_out($id, "SEEK $pos $rel");
    my $line = $server->write_in($id, 1);
    defined $line or faint(SP_INTERNET, $host, 'Lost connection');
    $line =~ /^2/ or faint(SP_INTERNET, $host, $line);
    $object->{buffer} = '';
    $object;
}

sub DESTROY {
    my ($object) = @_;
    my $server = $object->{filedata}{server};
    my $id = $object->{filedata}{id};
    eval { $server->tcp_socket_close($id); }
}

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    my ($object) = @_;
    my $host = $object->{filedata}{host};
    my $port = $object->{filedata}{port};
    return "REMOTE($host:$port)";
}

1;
