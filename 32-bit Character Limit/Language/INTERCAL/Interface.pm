package Language::INTERCAL::Interface;

# User interface for sick and intercalc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Interface.pm 1.-94.-2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';

sub new {
    @_ >= 3 or croak "Usage: Language::INTERCAL::Interface->new"
		   . "(SERVER, PREFER, TRY_LIST)";
    my $class = shift;
    my $server = shift;
    my $prefer = shift;
    my $lasterr = "Could not load user interface";
    for my $name ($prefer || @_) {
	my $modname = "Language::INTERCAL::Interface::$name";
	eval "require $modname";
	if ($@) {
	    $lasterr = $@;
	    next;
	}
	my $obj = eval { $modname->new($server) };
	return $obj if $obj && ref $obj;
	$lasterr = $@ if $@;
    };
    $lasterr .= "\n" if $lasterr !~ /\n$/;
    die $lasterr;
}

1;

