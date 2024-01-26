package Language::INTERCAL;

# Embed INTERCAL programs in Perl source code

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;
use Filter::Simple;

use Language::INTERCAL::Rcfile '1.-94.-2.1';
use Language::INTERCAL::Sick '1.-94.-2.2';
use Language::INTERCAL::Exporter '1.-94.-2.1', qw(require_version is_intercal_number);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL.pm 1.-94.-2.2") =~ /\s(\S+)$/;

my $count = 0;

# use Language::INTERCAL option => 'value', ...; INTERCAL source
sub import {
    my $class = shift;
    if (@_ && is_intercal_number($_[0])) {
	my $required = shift;
	require_version($required);
    }
    @_ % 2 == 0 or croak "Usage: Language::INTERCAL->import [VERSION,] [option => 'value']...";
    my $them = caller();
    my $rc = Language::INTERCAL::Rcfile->new;
    my $sick = Language::INTERCAL::Sick->new($rc);
    # if they don't specify a suffix, assume .i
    $sick->setoption(suffix => '.i');
    my %options = (
	quick    => 0,
	escape   => undef,
	debug    => 0,
    );
    while (@_) {
	my $option = shift;
	my $value = shift;
	if ($option =~ s/^-//) {
	    $rc->setoption($option, $value);
	} elsif (exists $options{$option}) {
	    $options{$option} = $value;
	} else {
	    $sick->setoption($option, $value);
	}
    }
    # force backend to be Run
    $sick->setoption(backend => 'Run');
    $rc->load(delete $options{quick});
    $sick->setoption('default_charset', $_) for $rc->getitem('WRITE');
    $sick->setoption('default_suffix', $_) for $rc->getitem('UNDERSTAND');
    $count++;
    no strict 'refs';
    ${"${them}::__intercal__compiler_$count"} = $sick;
    for my $opt (keys %options) {
	${"${them}::__intercal__${opt}_$count"} = $options{$opt};
    }
    1;
}

FILTER {
    my $depth = 0;
    my ($them) = caller($depth);
    while (defined $them && $them eq 'Filter::Simple') {
	($them) = caller(++$depth);
    }
    defined $them or return;
    my ($sick, $escape, $debug, $write, $read, $splat);
    {
	no strict 'refs';
	$sick = ${"${them}::__intercal__compiler_$count"};
	$escape = ${"${them}::__intercal__escape_$count"};
	$debug = ${"${them}::__intercal__debug_$count"};
    }
    if ($debug) {
	for my $line (split(/\n/, $_)) {
	    print STDERR "<<< $line\n";
	}
	print STDERR "\n";
    }
    my $perl = "\$${them}::__intercal__compiler_$count->save_objects(1);\n";
    if (defined $escape && $_ =~ $escape) {
	my $intercal = substr($_, 0, $-[0]);
	$sick->source_string($intercal);
	substr($_, 0, $+[0]) = $perl;
    } else {
	$sick->source_string($_);
	$_ = $perl;
    }
    if ($debug) {
	for my $line (split(/\n/, $_)) {
	    print STDERR ">>> $line\n";
	}
	print STDERR "\n";
    }
} 0;

1
