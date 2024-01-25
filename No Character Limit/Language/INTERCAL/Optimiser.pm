package Language::INTERCAL::Optimiser;

# Optimiser for INTERCAL bytecode; see also "optimise.iacc"

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# The plan for this is to have optimisers defined by INTERCAL programs,
# by introducing a new OPTIMISE statement or else a suitable modification
# of CREATE.  However the current version will just have a few predefined
# rules so that we can implement the mechanism behind the optimiser.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Optimiser.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::Splats '1.-94.-2.2', qw(faint SP_INTERNAL SP_TODO);
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(bc_skip bytedecode BC_INT BC_RIN BC_RSE BC_SEL);

use constant match_bytecode   => 0;
# match_statement to match_constant MUST have four consecutive values. Because I say so
use constant match_statement  => 1;
use constant match_expression => 2;
use constant match_assignable => 3;
use constant match_register   => 4;
use constant match_constant   => 5;

use constant rewrite_bytecode => 0;
use constant rewrite_match    => 1;
use constant rewrite_eval     => 2;

# bytecode types acceptable for matches
my @types;
$types[match_statement] = { map { ($_ => undef) } qw(S) };
$types[match_expression] = { map { ($_ => undef) } qw(E A R C), '#' };
$types[match_assignable] = { map { ($_ => undef) } qw(A R C), '#' };
$types[match_register] = { map { ($_ => undef) } qw(R) };
$types[match_constant] = { map { ($_ => undef) } qw(C), '#' };

sub new {
    @_ == 1 or croak "Usage: new Language::INTERCAL::Optimiser";
    my ($class) = @_;
    my @opt;
    $opt[BC_RIN] = [[[[match_expression], [match_expression]],
		     [[rewrite_bytecode, pack('C*', BC_INT)], [rewrite_match, 1], [rewrite_match, 0]]]];
    $opt[BC_RSE] = [[[[match_expression], [match_expression]],
		     [[rewrite_bytecode, pack('C*', BC_SEL)], [rewrite_match, 1], [rewrite_match, 0]]]];
    bless \@opt, $class;
}

sub add {
    @_ == 4 or croak "Usage: OPTIMISER->add(OPCODE, PATTERN, REWRITE)";
    my ($opt, $opcode, $pattern, $rewrite) = @_;
    faint(SP_TODO, "Optimiser::add");
    #XXX parse and verify $pattern and $rewrite
    #push @{$opt->[$opcode]}, [$pattern, $rewrite];
    #$opt;
}

sub optimise {
    @_ == 2 or croak "Usage: OPTIMISER->optimise(CODE)";
    my ($opt, $code) = @_;
    _optimise($opt, 0, length $code, $code);
}

sub read {
    @_ == 2 or croak "Usage: OPTIMISER->read(FILEHANDLE)";
    my ($opt, $fh) = @_;
    $fh->read_binary(pack('vv', 0, 0));
}

sub write {
    @_ == 2 or croak "Usage: Language::INTERCAL::Optimiser->write(FILEHANDLE)";
    my ($class, $fh) = @_;
    $fh->write_binary(4);
    $class->new();
}

sub _optimise {
    my ($opt, $pos, $end) = @_;
    my $byte = vec($_[3], $pos, 8);
    if ($opt->[$byte] && $pos + 1 < $end) {
	# see if a rule applies
    RULE:
	for my $rule (@{$opt->[$byte]}) {
	    my ($pattern, $rewrite) = @$rule;
	    my @match;
	    my $start = $pos + 1;
	    for my $item (@$pattern) {
		my $match = $item->[0];
		if ($match == match_bytecode) {
		    my $bc = $item->[1];
		    substr($_[3], $start, length $bc) eq $bc or next RULE;
		    my $length = length $bc;
		    push @match, [$start, $start + $length];
		    $start += $length;
		} elsif ($match >= match_statement && $match <= match_constant) {
		    $start < $end or next RULE;
		    $byte = vec($_[3], $start, 8);
		    my $type = (bytedecode $byte)[2];
		    defined $type && exists $types[$match]{$type} or next RULE;
		    my $orig = $start;
		    bc_skip($_[3], \$start, $end) or next RULE;
		    push @match, [$orig, $start];
		} else {
		    # how on Earth did we get here?
		    faint(SP_INTERNAL, "Invalid encoded pattern in optimiser");
		}
	    }
	    # this rule matches, now see how we rewrite it
	    my $newcode = '';
	    for my $item (@$rewrite) {
		my $action = $item->[0];
		if ($action == rewrite_bytecode) {
		    $newcode .= $item->[1];
		} elsif ($action == rewrite_match) {
		    my $mn = $item->[1];
		    $mn >= 0 && $mn < @match or faint(SP_INTERNAL, "Invalid match in optimiser");
		    $newcode .= _optimise($opt, @{$match[$mn]}, $_[3]);
		} elsif ($action == rewrite_eval) {
		    faint(SP_TODO, "rewrite_eval");
		} else {
		    # how on Earth did we get here?
		    faint(SP_INTERNAL, "Invalid encoded rewrite in optimiser");
		}
	    }
	    $start < $end and $newcode .= _optimise($opt, $start, $end, $_[3]);
	    return $newcode;
	}
    }
    # no rule matched, check sub-sequences
    my $start = $pos;
    bc_skip($_[3], \$pos, $end) or return $_[3];
    $start == $pos and return $_[3]; # can't imagine that actually happening but anyway
    my $newcode = substr($_[3], $start++, 1);
    while ($start < $pos) {
	my $substart = $start;
	bc_skip($_[3], \$start, $pos) or return $_[3];
	$substart == $start and return $_[3];
	$start > $pos and return $_[3];
	$newcode .= _optimise($opt, $substart, $start, $_[3]);
    }
    $pos < $end and $newcode .= _optimise($opt, $pos, $end, $_[3]);
    return $newcode;
}

1;
