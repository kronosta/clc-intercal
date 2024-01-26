package Language::INTERCAL::RegTypes;

# Constants used to identify registers, and function to translate to/from
# the standard INTERCAL register names

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# This module is used by just about every other module, so it must not depend
# on any of them. It is also used during the build bootstrap, so it cannot
# use generated tables (like ByteCode does)

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/RegTypes.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2', qw(import);

use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(
    REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho
    reg_nametype reg_typename
);

# Identifiers to represent all register types; the first 4 are also used to
# represent data types in the Interpreter
use constant REG_spot     => 1; # this MUST have value 1
use constant REG_twospot  => 2; # this MUST have value 2
use constant REG_tail     => 3;
use constant REG_hybrid   => 4;
use constant REG_dos      => 5; # Double-oh-seven, special "spot" registers
use constant REG_whp      => 6; # Whirlpool, class and filehandles
use constant REG_shf      => 7; # Shark fin, special "tail" registers
use constant REG_cho      => 8; # Crawling horror, special register for grammars

sub reg_typename ($) {
    my ($type) = @_;
    $type == REG_spot and return '.';
    $type == REG_twospot and return ':';
    $type == REG_tail and return ',';
    $type == REG_hybrid and return ';';
    $type == REG_dos and return '%';
    $type == REG_shf and return '^';
    $type == REG_whp and return '@';
    $type == REG_cho and return '_';
    undef;
}

sub reg_nametype ($) {
    my ($name) = @_;
    $name eq  '.' and return REG_spot;
    $name eq  ':' and return REG_twospot;
    $name eq  ',' and return REG_tail;
    $name eq  ';' and return REG_hybrid;
    $name eq  '%' and return REG_dos;
    $name eq  '^' and return REG_shf;
    $name eq  '@' and return REG_whp;
    $name eq  '_' and return REG_cho;
    undef;
}

1;
