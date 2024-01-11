package Language::INTERCAL::SharkFin;

# Functions to manage contents of "Shark Fin" registers.

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/SharkFin.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_SPECIAL SP_SPOTS SP_NOARRAY);
use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_shf);
use Language::INTERCAL::Arrays '1.-94.-2.2', qw(make_list);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(make_sharkfin print_sharkfin);

my %types = (
    vector => [\&_code_vector, \&_decode_vector],
);

sub make_sharkfin ($$$$) {
    my ($type, $object, $value, $vtype) = @_;
    exists $types{$type} or faint(SP_SPECIAL, "(type $type)");
    my ($code, $decode) = @{$types{$type}};
    $value = $code->($object, $value, $vtype);
    ($value, $code, $decode, $type);
}

sub print_sharkfin ($$$) {
    my ($type, $object, $value) = @_;
    exists $types{$type} or faint(SP_SPECIAL, "(type $type)");
    my ($code, $decode) = @{$types{$type}};
    $decode->($object, $value);
}

sub _code_vector {
    my ($object, $value, $type) = @_;
    if ($type == REG_spot || $type == REG_twospot) {
	$value > 0xffff and faint(SP_SPOTS, $value, 'Shark fin');
	$value = [$value];
    } elsif ($type == REG_tail || $type == REG_hybrid) {
	my @big = grep { $_ > 0xffff } @$value;
	@big and faint(SP_SPOTS, $big[0], 'Shark fin');
    } elsif ($type == REG_shf) {
	# special value used to pass lists of strings, which gets stored
	# as a list of 0-terminated numbers
	$value = [map { (unpack('C*', $_), 0) } @$value];
    } else {
	faint(SP_NOARRAY, 'Not an array');
    }
    $value;
}

sub _decode_vector {
    my ($object, $value) = @_;
    my @list = make_list($value);
    pop @list while @list && $list[-1] == 0;
    my $list = pack('C*', @list);
    $list =~ s/([\\'])/\\$1/g;
    $list = "'$list'" if $list =~ /['\s\\]/;
    $list;
}

1;
