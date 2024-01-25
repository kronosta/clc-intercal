package Language::INTERCAL::Interface::None;

# pseudo user interface which never enters interactive mode

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Interface/None.pm 1.-94.-2.1") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::GenericIO '1.-94.-2.1', qw($stdread $stdwrite);

sub new {
    @_ == 2 or croak "Usage: Language::INTERCAL::Interface::None->new(SERVER)";
    my ($class, $server) = @_;
    my $none = bless {
	server => $server,
	line => '',
	end => 0,
	convert => $stdwrite->write_convert,
    }, $class;
    $| = 1;
    if ($server) {
	STDIN->blocking(0);
	$server->file_listen(fileno(STDIN),
			     sub {
				 my $l;
				 if (sysread STDIN, $l, 1024) {
				     $none->{line} .= $l;
				 } else {
				     $none->{end} = 1;
				     $server->file_listen_close(fileno(STDIN));
				 }
			     });
    }
    $none;
}

sub has_window { 0 }
sub is_interactive { 0 }

sub is_terminal {
    $stdwrite->is_terminal;
}

sub run {
    croak "Non interactive interface should never enter run()";
}

sub start {
    croak "Non interactive interface should never enter start()";
}

sub stdread {
    $stdread;
}

sub getline {
    @_ == 2 or croak "Usage: NONE->getline(PROMPT)";
    my ($none, $prompt) = @_;
    $stdread->read_text($prompt);
    my $timeout = 0;
    while (1) {
	$none->{server}->progress($timeout);
	$timeout = undef;
	$none->{line} =~ s/^(.*?\n)// and return $none->{convert}->($1);
	$none->{end} or next;
	my $l = $none->{line};
	$none->{line} = undef;
	return $l;
    }
}

sub complete {
    @_ == 1 || @_ == 2 or croak "Usage: NONE->complete [(CALLBACK)]";
    my ($none, $code) = @_;
    $none;
}

1;
