package Language::INTERCAL::Arrays;

# Tails and hybrids; this implementation is possibly subject to change, so
# other modules need to make sure to always use the functions here

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Arrays.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::Splats '1.-94.-2.2',
    qw(faint SP_ARRAY SP_INVARRAY SP_NODIM SP_NUMBER SP_SPOTS SP_SUBSCRIPT SP_SUBSIZE);
use Language::INTERCAL::RegTypes '1.-94.-2.2', qw(REG_spot REG_twospot REG_hybrid);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(
    make_array replace_array partial_replace_array forall_elements
    make_list list_subscripts
    make_sparse_list expand_sparse_list
    get_element set_element array_elements
);

sub make_list ($);

sub make_list ($) {
    my ($list) = @_;
    defined $list or return (0);
    ref $list or return ($list);
    ref $list eq 'ARRAY' or faint(SP_INVARRAY);
    map { make_list($_) } @$list;
}

sub make_array ($) {
    my ($list) = @_;
    defined $list or return [];
    ref $list or return [(0) x $list];
    ref $list eq 'ARRAY' or faint(SP_INVARRAY);
    @$list or return [];
    _array(@$list);
}

sub _array {
    my ($first, @rest) = @_;
    @rest or return [(0) x $first];
    [map { _array(@rest) } (1..$first) ];
}

sub forall_elements ($&) {
    my ($list, $code) = @_;
    $list && ref $list && ref $list eq 'ARRAY' or faint(SP_INVARRAY);
    _forall($list, $code);
}

sub _forall {
    my ($list, $code, @subscripts) = @_;
    if (ref $list) {
	for (my $n = 0; $n < @$list; $n++) {
	    _forall($list->[$n], $code, @subscripts, $n + 1);
	}
    } else {
	$code->($list, @subscripts);
    }
}

sub make_sparse_list (@) {
    my (@list) = @_;
    my @sparse;
    my $tail0 = 0;
    while (@list) {
	my $run = 0;
	while ($run < @list && $list[$run] == 0) {
	    $run++;
	}
	splice(@list, 0, $run);
	push @sparse, $run;
	$tail0 = 1;
	@list or last;
	$run = 0;
	while ($run < @list && $list[$run] != 0) {
	    $run++;
	}
	push @sparse, $run, splice(@list, 0, $run);
	$tail0 = 0;
    }
    $tail0 and pop @sparse;
    @sparse;
}

sub list_subscripts ($) {
    my ($list) = @_;
    $list && ref $list && ref $list eq 'ARRAY' or faint(SP_INVARRAY);
    my @sub;
    while (ref $list) {
	push @sub, scalar(@$list);
	$list = $list->[0];
    }
    @sub;
}

sub get_element ($@) {
    my ($array, @subscripts) = @_;
    @subscripts or faint(SP_INVARRAY);
    while (@subscripts) {
	ref $array or faint(SP_SUBSIZE, 1, 0);
	my $first = shift @subscripts;
	$first < 1 and faint(SP_SUBSCRIPT, $first, 'is less than 1');
	$first > @$array and faint(SP_SUBSCRIPT, $first, 'is greater than ' . scalar(@$array));
	$array = $array->[$first - 1];
    }
    ref $array and faint(SP_SUBSIZE, 0, 1);
    $array;
}

sub set_element ($$$$@) {
    my ($array, $type, $assign, $atype, @subscripts) = @_;
    $atype == REG_spot || $atype == REG_twospot or faint(SP_NUMBER, "Not a spot or twospot value");
    @subscripts or faint(SP_INVARRAY);
    my $last = pop @subscripts;
    ref $array or faint(SP_SUBSIZE, 1, 0);
    while (@subscripts) {
	my $first = shift @subscripts;
	$first < 1 and faint(SP_SUBSCRIPT, $first, 'is less than 1');
	$first > @$array and faint(SP_SUBSCRIPT, $first, 'is greater than ' . scalar(@$array));
	$array = $array->[$first - 1];
	ref $array or faint(SP_SUBSIZE, 1, 0);
    }
    $last < 1 and faint(SP_SUBSCRIPT, $last, 'is less than 1');
    $last > @$array and faint(SP_SUBSCRIPT, $last, 'is greater than ' . scalar(@$array));
    ref $array->[$last - 1] and faint(SP_SUBSIZE, 0, 1);
    if ($type == REG_twospot || $type == REG_hybrid) {
	$assign > 0xffffffff and faint(SP_SPOTS, $assign, 'two spots');
    } else {
	$assign > 0xffff and faint(SP_SPOTS, $assign, 'one spot');
    }
    $array->[$last - 1] = $assign;
}

sub array_elements ($) {
    my ($list) = @_;
    $list && ref $list && ref $list eq 'ARRAY' && @$list or return 0;
    my $mul = 1;
    while (ref $list) {
	$mul *= @$list;
	$list = $list->[0];
    }
    $mul;
}

sub replace_array ($$@) {
    my ($list, $type, @data) = @_;
    $list && ref $list && ref $list eq 'ARRAY' && @$list or faint(SP_NODIM);
    _replace($list, ($type == REG_hybrid || $type == REG_twospot) ? 0xffffffff : 0xfffff, \@data);
    @data and faint(SP_ARRAY, "Too many elements");
}

sub _replace {
    my ($list, $maxval, $data) = @_;
    if (ref $list->[0]) {
	for my $down (@$list) {
	    _replace($down, $maxval, $data);
	}
    } else {
	my @add = splice(@$data, 0, @$list);
	for my $a (@add) {
	    $a > $maxval and faint(SP_SPOTS, $a, $maxval > 0xffff ? 'two spots' : 'one spot');
	}
	@add < @$list and push @add, (0) x (@$list - @add);
	@$list = @add;
    }
}

sub partial_replace_array ($$$) {
    my ($list, $type, $data) = @_;
    $list && ref $list && ref $list eq 'ARRAY' && @$list or faint(SP_NODIM);
    _partial_replace($list, ($type == REG_hybrid || $type == REG_twospot) ? 0xffffffff : 0xffff, $data);
}

sub _partial_replace {
    my ($list, $maxval, $data) = @_;
    if (ref $list->[0]) {
	for my $down (@$list) {
	    _partial_replace($down, $maxval, $data);
	}
    } else {
	@$data or return;
	my @add = splice(@$data, 0, @$list);
	for my $a (@add) {
	    $a > $maxval and faint(SP_SPOTS, $a, $maxval > 0xffff ? 'two spots' : 'one spot');
	}
	if (@add < @$list) {
	    splice(@$list, 0, scalar(@add), @add);
	} else {
	    @$list = @add;
	}
    }
}

sub expand_sparse_list (@) {
    my (@data) = @_;
    my @list;
    while (@data) {
	my $run = shift @data;
	push @list, (0) x $run;
	@data or last;
	$run = shift @data;
	$run <= @data or faint(SP_INVARRAY);
	push @list, splice(@data, 0, $run);
    }
    @list;
}

1;
