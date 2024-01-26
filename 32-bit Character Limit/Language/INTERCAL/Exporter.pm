package Language::INTERCAL::Exporter;

# Like the standard Exporter, but understand INTERCAL (per)version numbers

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;
require Exporter;

use vars qw($VERSION $PERVERSION @EXPORT @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Exporter.pm 1.-94.-2.3") =~ /\s(\S+)$/;
@EXPORT = qw(import);
@EXPORT_OK = qw(is_intercal_number import require_version compare_version has_type is_object);

sub is_intercal_number {
    @_ == 1 or croak "Usage: is_intercal_number(STRING)";
    my ($s) = @_;
    $s =~ /^-?\d+(?:\.-?\d+)*$/;
}

sub import {
    if (@_ > 1) {
	if (is_intercal_number($_[1])) {
	    my ($req) = splice(@_, 1, 1);
	    require_version($_[0], $req);
	}
    }
    goto &Exporter::import;
}

sub require_version {
    my ($package, $required) = @_;
    $package = caller if ! defined $package;
    my $provided;
    {
	no strict 'refs';
	$provided = ((${"${package}::PERVERSION"} || '0') =~ /\s(\S+$)/)[0];
    }
    compare_version($required, $provided) <= 0
	or croak "$package perversion $provided is too old (required $required)";
}

# override UNIVERSAL::VERSION too
sub VERSION {
    my ($package, $required) = @_;
    $package = caller if ! defined $package;
    my $provided;
    {
	no strict 'refs';
	$provided = ((${"${package}::PERVERSION"} || '0') =~ /\s(\S+$)/)[0];
    }
    defined $required && compare_version($required, $provided) > 0
	and croak "$package perversion $provided is too old (required $required)";
    # supposed to return a string, never a number, according to the docs
    "$provided";
}

sub compare_version {
    @_ == 2 or croak "Usage: compare_version(NUM, NUM)";
    my ($a, $b) = @_;
    my @a = split(/\./, $a);
    my @b = split(/\./, $b);
    while (@a || @b) {
	$a = @a ? shift @a : 0;
	$b = @b ? shift @b : 0;
	return -1 if $a < $b;
	return 1 if $a > $b;
    }
    0;
}

# this does not belong here, but I'm too lazy to have a module just for this
# it works around the problem that UNIVERSAL::isa is deprecated in recent
# perl in favour of Scalar::Util but that's not available in an older perl

sub _has_type_old ($$) {
    my ($who, $type) = @_;
    eval { UNIVERSAL::isa($who, $type); }
}

sub _is_object_old ($) {
    my ($who) = @_;
    eval { UNIVERSAL::isa($who, 'UNIVERSAL'); }
}

sub _has_type_new ($$) {
    my ($who, $type) = @_;
    reftype($who) eq $type;
}

sub _is_object_new ($) {
    my ($who) = @_;
    defined blessed($who);
}

BEGIN {
    eval '
	die "boo\n";
	use Scalar::Util qw(reftype blessed);
	*has_type = \&_has_type_new;
	*is_object = \&_is_object_new;
	1;
    ' or do {
	*has_type = \&_has_type_old;
	*is_object = \&_is_object_old;
    };
}

1;
