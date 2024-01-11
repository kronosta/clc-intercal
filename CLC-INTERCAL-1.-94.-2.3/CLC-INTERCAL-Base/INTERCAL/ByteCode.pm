package Language::INTERCAL::ByteCode;

# Definitions of bytecode symbols etc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

@@DATA ByteCode@@

use strict;
use vars qw($VERSION $PERVERSION $DATAVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/ByteCode.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-3', qw(import compare_version);
use Language::INTERCAL::Splats '1.-94.-2.1',
	qw(faint SP_INTERNAL SP_BCMATCH SP_TODO);
use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho);

$DATAVERSION = '@@VERSION@@';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

use constant BYTE_SIZE     => 8;      # number of bits per byte (must be == 8)
use constant NUM_OPCODES   => 0x80;   # number of virtual opcodes
use constant OPCODE_RANGE  => 1 << BYTE_SIZE;
use constant BYTE_SHIFT    => OPCODE_RANGE - NUM_OPCODES;

use vars qw(@EXPORT_OK %EXPORT_TAGS);
@EXPORT_OK = qw(
    bytecode bytedecode bytename bc_list BC BCget is_constant
    bc_skip bc_forall add_bytecode NUM_OPCODES
    @@FILL OPCODES BC_ NAME '' 76 ' '@@
);

%EXPORT_TAGS = (
    BC => [qw(
	@@FILL OPCODES BC_ NAME '' 76 ' '@@
    )],
);

my @bytecodes = (
    ['@@'DESCR'@@', '@@TYPE@@', '@@NAME@@', '@@ARGS@@', @@CONST@@, @@ASSIGNABLE@@], # @@ARRAY OPCODES NUMBER@@
    undef, # @@NUMBER@@
);

my %bytedecode = (
    @@ALL OPCODES NAME@@ => @@NUMBER@@,
);

my @bc_list = qw(
    @@FILL OPCODES '' NAME '' 76 ' '@@
);

sub BC_@@ALL OPCODES NAME@@ () { @@NUMBER@@; }

# line @@LINE@@

sub add_bytecode {
    @_ == 5 or croak
	"Usage: add_bytecode(NAME, DESCR, TYPE, NUMBER, ARGS)";
    my ($name, $descr, $type, $number, $args) = @_;
    my ($const, $assign);
    $type = uc($type);
    if ($type eq 'S' || $type eq 'E') {
	$const = $assign = 0;
    } elsif ($type eq 'A') {
	$const = 0;
	$assign = 1;
	$type = 'E';
    } elsif ($type eq 'R') {
	$const = 0;
	$assign = 1;
    } elsif ($type eq 'C') {
	$const = 1;
	$assign = 1;
	$type = '#';
    } else {
	croak "Invalid TYPE: $type";
    }
    $name = uc($name);
    $number += 0;
    $number < 0 || $number >= NUM_OPCODES
	and croak "Invalid bytecode number: $number";
    $bytecodes[$number]
	and croak "Duplicate bytecode number: $number";
    exists $bytedecode{$name}
	and croak "Duplicate bytecode name: $name";
    $bytedecode{$name} = $number;
    $bytecodes[$number] = [$descr, $type, $name, $args, $const, $assign];
    push @bc_list, $name;
    push @EXPORT_OK, "BC_$name";
    push @{$EXPORT_TAGS{BC}}, "BC_$name";
    no strict;
    *{"BC_$name"} = sub { $number };
}

sub bc_list () {
    @bc_list;
}

sub BC ($) {
    my ($val) = @_;
    croak "Invalid undefined value" unless defined $val;
    my $orig = $val;
    $val < BYTE_SHIFT
	and return ($val + NUM_OPCODES);
    $val < OPCODE_RANGE
	and return (BC_HSN, $val);
    my $div = int($val / OPCODE_RANGE);
    $div < OPCODE_RANGE
	and return (BC_OSN, $div, $val % OPCODE_RANGE);
    croak "Invalid value $orig: does not fit in one spot";
}

sub bytecode ($) {
    my ($name) = @_;
    $name =~ /^\d+$/ && $name < BYTE_SHIFT ? ($name + NUM_OPCODES)
					   : $bytedecode{$name};
}

# convert bytecode to name, or in list context to:
# (name, description, type, opcode, pattern, is_constant?, is_assignable?)
#     0            1     2       3        4             5               6
sub bytedecode ($) {
    my ($b) = @_;
    if ($b >= NUM_OPCODES) {
	my $n = $b - NUM_OPCODES;
	return () if $n >= BYTE_SHIFT;
	return "#$n" unless wantarray;
	return ("#$n", 'Constant', '#', $b, '', 1, 1);
    } else {
	return () unless $bytecodes[$b];
	my $p = $bytecodes[$b];
	return $p->[2] unless wantarray;
	return ($p->[2], $p->[0], $p->[1], $b, $p->[3], $p->[4], $p->[5]);
    }
}

sub bytename ($) {
    my ($b) = @_;
    if ($b >= NUM_OPCODES) {
	my $n = $b - NUM_OPCODES;
	return () if $n >= BYTE_SHIFT;
	return "#$n";
    } else {
	return () unless $bytecodes[$b];
	my $p = $bytecodes[$b];
	return $p->[2];
    }
}

sub BCget ($$$) {
    # don't make a copy of $_[0], it's likely to be a long string and we only want
    # at most 3 bytes from it
    my ($cp, $ep) = @_[1, 2];
    $$cp >= $ep and faint(SP_INTERNAL, 'BCget called after end of code');
    my $byte = vec($_[0], $$cp++, 8);
    if ($byte >= NUM_OPCODES) {
	return $byte - NUM_OPCODES;
    }
    if ($byte == BC_HSN) {
	$$cp >= $ep and faint(SP_INTERNAL, 'BCget: missing constant after HSN');
	return vec($_[0], $$cp++, 8);
    }
    if ($byte == BC_OSN) {
	$$cp + 1 >= $ep and faint(SP_INTERNAL, 'BCget: missing constant after OSN');
	my $nx = vec($_[0], $$cp++, 8) << 8;
	return $nx | vec($_[0], $$cp++, 8);
    }
    faint(SP_INTERNAL, sprintf("BCget: unknown opcode 0x%02x", $byte));
}

sub is_constant ($) {
    my ($byte) = @_;
    return 1 if $byte >= NUM_OPCODES ||
		$byte == BC_HSN ||
		$byte == BC_OSN;
    return 0;
}

sub _skip {
    my ($start, $end, $args) = @_; # $_[3] is code but we don't want to copy it
    my $pos = 0;
    while ($pos < length $args) {
	my $e = substr($args, $pos++, 1);
	if ($e eq '#' || $e eq 'C') {
	    # constant, optionally followed by (submatch)
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    if ($pos < length $args && substr($args, $pos, 1) eq '(') {
		my $subarg = ++$pos;
		my $level = 1;
		my $parend = $subarg;
		while ($level > 0) {
		    $pos >= length $args and return undef;
		    my $c = substr($args, $pos++, 1);
		    if ($c eq '(') {
			$level++;
		    } elsif ($c eq ')') {
			$level--;
		    }
		}
		if ($byte >= NUM_OPCODES) {
		    $byte -= NUM_OPCODES;
		} elsif ($byte == BC_HSN) {
		    $$start >= $end and return undef;
		    $byte = vec($_[3], $$start++, 8);
		} elsif ($byte == BC_OSN) {
		    $$start + 1 >= $end and return undef;
		    # can't use vec(..., 16) because it may not be 16-bit aligned
		    $byte = vec($_[3], $$start++, 8) << 8;
		    $byte |= vec($_[3], $$start++, 8);
		} else {
		    return undef;
		}
		$byte or next;
		$subarg = substr($args, $subarg, $pos - $subarg - 1);
		while ($byte-- > 0) {
		    _skip($start, $end, $subarg, $_[3]) or return undef;
		}
	    } else {
		$byte >= NUM_OPCODES and next;
		if ($byte == BC_HSN) {
		    $$start >= $end and return undef;
		    $$start++;
		    next;
		}
		if ($byte == BC_OSN) {
		    $$start += 2;
		    $$start > $end and return undef;
		    next;
		}
		return undef;
	    }
	    next;
	}
	if ($e eq 'S' || $e eq 'E' || $e eq 'R' || $e eq 'A' || $e eq 'V') {
	    # statment, expression, register, asignable or symbol: they
	    # all match a generic bytecode sequence
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    $byte >= NUM_OPCODES and next;
	    $bytecodes[$byte] or return undef;
	    _skip($start, $end, $bytecodes[$byte][3], $_[3]) or return undef;
	    next;
	}
	if ($e eq 'O') {
	    # gerund or similar symbol: anything other than HSN or OSN means
	    # a 1-byte constant
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    if ($byte == BC_HSN) {
		$$start >= $end and return undef;
		$$start++;
		next;
	    }
	    if ($byte == BC_OSN) {
		$$start += 2;
		$$start > $end and return undef;
		next;
	    }
	    next;
	}
	if ($e eq 'N') {
	    # any byte
	    $$start >= $end and return undef;
	    $$start++;
	    next;
	}
	if ($e eq '<') {
	    # left grammar rule: count, position, symbol or string
	    _skip($start, $end, '##E', $_[3]) or return undef;
	    next;
	}
	if ($e eq '>') {
	    # right grammar rule: a constant follows determining what's next
	    $$start >= $end and return undef;
	    my $byte = vec($_[3], $$start++, 8);
	    if ($byte == NUM_OPCODES || $byte == NUM_OPCODES + 1 || $byte == NUM_OPCODES + 3 || $byte == NUM_OPCODES + 6) {
		# position, symbol / number
		_skip($start, $end, 'EE', $_[3]) or return undef;
		next;
	    }
	    if ($byte == NUM_OPCODES + 4) {
		# length; block of bytecode
		$$start >= $end and return undef;
		$byte = vec($_[3], $$start++, 8);
		if ($byte >= NUM_OPCODES) {
		    $byte -= NUM_OPCODES;
		} elsif ($byte == BC_HSN) {
		    $$start >= $end and return undef;
		    $byte = vec($_[3], $$start++, 8);
		} elsif ($byte == BC_OSN) {
		    $$start + 1 >= $end and return undef;
		    $byte = vec($_[3], $$start++, 8) << 8;
		    $byte |= vec($_[3], $$start++, 8);
		} else {
		    return undef;
		}
		$$start += $byte;
		$$start > $end and return undef;
		next;
	    }
	    if ($byte == NUM_OPCODES + 15) {
		# "splat", no other data
		next;
	    }
	    # unknown type
	    return undef;
	}
    }
    return 1;
}

sub bc_skip ($$$) {
    my (undef, $start, $end) = @_;
    $$start >= $end and return undef;
    my $byte = vec($_[0], $$start++, 8);
    $byte >= NUM_OPCODES and return 1;
    $bytecodes[$byte] or return undef;
    _skip($start, $end, $bytecodes[$byte][3], $_[0]);
}

sub bc_forall {
    @_ == 5
	or croak "Usage: bc_forall(PATTERN, CODE, START, END, CLOSURE)";
    my ($pattern, undef, $start, $end, $closure) = @_;
    $start ||= 0;
    $end = length($_[1]) if not defined $end;
    return undef if $start >= $end || $start < 0;
    my $np = '';
    while ($pattern =~ s/^(.*?)C\(/(/) {
	my $a = $1;
	$a =~ s/(.)/$1\x01/g;
	$np .= $a . 'C';
	$np .= '(' . _args('forall', \$pattern) . ')';
	$np .= "\01";
    }
    $pattern =~ s/(.)/$1\x01/g;
    $pattern = "\x01" if $pattern eq '';
    $np .= $pattern;
    _forall($np, $_[1], $start, $end, $closure);
}

my %typemap = (
    'S' => { 'S' => 0 },
    'O' => { 'S' => 0 },
    'E' => { 'E' => 0, 'R' => 0, '#' => 0 },
    'A' => { 'E' => 0, 'R' => 0, '#' => 0 },
    'R' => { 'R' => 0 },
    'V' => { 'R' => 0, 'V' => 0 },
    '#' => { '#' => 0 },
    'C' => { '#' => 0 },
    'Z' => { 'S' => 0, 'E' => 0, 'R' => 0, '#' => 0 },
    '*' => { 'S' => 0, 'E' => 0, 'R' => 0, '#' => 0 },
);

sub _args {
    my ($name, $pattern) = @_;
    faint(SP_BCMATCH, $name, 'Missing (') if $$pattern !~ s/^\(//;
    my $count = 1;
    my $result = '';
    while ($count > 0) {
	$$pattern =~ s/^([^\(\)]*)([\(\)])//
	    or faint(SP_BCMATCH, $name, 'Missing )');
	$count++ if $2 eq '(';
	$count-- if $2 eq ')';
	$result .= $1 . ($count ? $2 : '');
    }
    $result;
}

sub _forall {
    my ($pattern, undef, $sc, $ep, $closure) = @_;
    my $osc = $sc;
    MATCH: while ($pattern ne '') {
	my $e = substr($pattern, 0, 1, '');
	if ($e eq "\x00") {
	    $closure->(undef, '>') if $closure;
	    next MATCH;
	}
	if ($e eq "\x01") {
	    $closure->($sc, undef) if $closure;
	    next MATCH;
	}
	faint(SP_INTERNAL, '_forall: reading past end of code') if $sc >= $ep;
	my $v = vec($_[1], $sc, 8);
	if (exists $typemap{$e}) {
	    # check next opcode is correct type
	    my ($op, $type, $args, $const);
	    if ($v >= NUM_OPCODES && $e ne 'O') {
		$op = '#' . ($v - NUM_OPCODES);
		$type = '#';
		$args = '';
		$const = 1;
	    } else {
		$v %= NUM_OPCODES; # so gerunds can be small constants as well as opcodes
		$bytecodes[$v] or faint(SP_INTERNAL, "_forall: $e: invalid gerund $v");
		my $p = $bytecodes[$v];
		$op = $p->[2];
		$type = $p->[1];
		$args = $p->[3];
		$const = $p->[4];
	    }
	    faint(SP_INTERNAL, "_forall: $e: unknown type $type")
		unless exists $typemap{$e}{$type} ||
		       (($v == BC_MUL || $v == BC_STR) && exists $typemap{$e}{V});
	    if ($e eq 'O' && $const) {
		# inlining a stripped-down version of BCget because this is like
		# the inner loop of an inner loop
		if ($v < NUM_OPCODES) {
		    if ($v == BC_HSN) {
			$sc < $ep or return ();
			$sc++;
		    } elsif ($v == BC_OSN) {
			$sc += 2;
			$sc <= $ep or return ();
		    } else {
			return ();
		    }
		}
	    } elsif ($type eq '#' && $e ne '*') {
		my $num = BCget($_[1], \$sc, $ep);
		$closure->($v, "#$num") if $closure;
		if ($e eq 'C') {
		    $args = _args('count', \$pattern) x $num;
		    $args .= "\x00";
		    $closure->(undef, '<') if $closure;
		} else {
		    $args = '';
		}
	    } else {
		$sc++;
		$args = '' if $e eq 'O' || $e eq '*';
		$closure->($v, $op) if $closure;
	    }
	    $pattern = $args . $pattern;
	    next MATCH;
	} elsif ($e eq 'N') {
	    # any number
	    $closure->($v, "N$v") if $closure;
	    $sc++;
	} elsif ($e eq '<') {
	    # left grammar element
	    my $count = BCget($_[1], \$sc, $ep);
	    my $num = BCget($_[1], \$sc, $ep);
	    if ($num == 0) {
		$closure->(undef, '?<') if $closure;
	    } elsif ($num == 1 || $num == 2) {
		$closure->(undef, ',<') if $closure;
	    } else {
		$closure->(undef, ',!<') if $closure;
	    }
	    if ($count && $closure) {
		$closure->(undef, $count == 65535 ? '*' : $count);
	    }
	    $pattern = "E\x00" . $pattern;
	    next MATCH;
	} elsif ($e eq '>') {
	    # right grammar element
	    my $num = BCget($_[1], \$sc, $ep);
	    if ($num == 0 || $num == 6) {
		my $count = BCget($_[1], \$sc, $ep);
		if ($count && $closure) {
		    $closure->(undef, $count);
		}
		$closure->($v, $num ? '!<' : '?<') if $closure;
		$pattern = "E\x00" . $pattern;
		next MATCH;
	    }
	    if ($num == 1 || $num == 2) {
		$closure->($v, ',<') if $closure;
		my $count = BCget($_[1], \$sc, $ep);
		if ($count && $closure) {
		    $closure->(undef, $count);
		}
		$pattern = "E\x00" . $pattern;
		next MATCH;
	    }
	    if ($num == 3 || $num == 7) {
		$closure->($v, ',!<') if $closure;
		my $count = BCget($_[1], \$sc, $ep);
		if ($count && $closure) {
		    $closure->(undef, $count);
		}
		$pattern = "E\x00" . $pattern;
		next MATCH;
	    }
	    if ($num == 4) {
		$num = BCget($_[1], \$sc, $ep);
		my $se = $sc + $num;
		$se <= $ep
		    or faint(SP_INTERNAL, '_forall: end of code reached in nested call');
		if ($closure) {
		    $closure->(undef, '=<');
		    while ($sc < $se) {
			$sc += _forall('*', $_[1], $sc, $se, $closure);
		    }
		    $closure->(undef, '>');
		} else {
		    $sc = $se;
		}
		next MATCH;
	    }
	    if ($num == 15) {
		$closure->($v, '*') if $closure;
		next MATCH;
	    }
	    faint(SP_INTERNAL, $num, "_forall: invalid nested call parameter $num");
	} elsif ($e eq '[') {
	    # XXX left optimise element
	    faint(SP_TODO, 'match on [');
	} elsif ($e eq ']') {
	    # XXX right optimise element
	    faint(SP_TODO, 'match on ]');
	} else {
	    faint(SP_BCMATCH, 'type', $e);
	}
    }
    $sc - $osc;
}

1;

__END__

=pod

=head1 NAME

Language::INTERCAL::Bytecode - intermediate language

=head1 DESCRIPTION

The CLC-INTERCAL compiler works by producing bytecode from the
program source; this bytecode can be interpreted to execute the
program immediately; alternatively, a backend can produce something
else from the bytecode, for example C or Perl source code which can
then be compiled to your computer's native object format.

The compiler itself is just some more bytecode. Thus, to produce the
compiler you need a compiler compiler, and to produce that you need
a compiler compiler compiler; to produce the latter you would need
a compiler compiler compiler compiler, and so on to infinity. To
simplify the programmer's life (eh?), the compiler compiler is able
to compile itself, and is therefore identical to the compiler compiler
compiler (etcetera).

The programmer can start the process because a pre-compiled compiler
compiler, in the form of bytecode, is provided with the CLC-INTERCAL
distribution; this compiler compiler then is able to compile all
other compilers, as well as to rebuild itself if need be.

See the online manual or the HTML documentation included with the
distribution for more information about this.

=head1 SEE ALSO

A qualified psychiatrist

=head1 AUTHOR

Claudio Calvelli - compiler (whirlpool) intercal.org.uk
(Please include the word INTERLEAVING in the subject when emailing that
address, or the email may be ignored)

