package Language::INTERCAL::Parser;

# Parser/code generator/etc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Parser.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_CREATION SP_CIRCULAR);
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(BC BC_MUL BC_STR);
use Language::INTERCAL::SymbolTable '1.-94.-3';

# for some reason this sort of things works faster than regexes here
my $digits = '';
vec($digits, ord($_), 1) = 1 for (0..9);
my $alphalist ='abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ';
my $alphabet = $digits;
for (my $i = 0; $i < length $alphalist; $i++) {
    vec($alphabet, vec($alphalist, $i, 8), 1) = 1;
}
my $anything = '';
vec($anything, $_, 1) = 1 for (0..255);
my $spaces = '';
vec($spaces, ord($_), 1) = 1 for (" ", "\t", "\012", "\015");
my $nonspaces = $anything;
vec($spaces, ord($_), 1) = 0 for (" ", "\t", "\012");

my @parser_predefined = (
    # NAME         PARSE                BAD GENCODE           STARTS      EMPTY COMPLETE
    ["CONSTANT",   \&_parse_constant,   0,  \&_code_constant, $digits,    0,    \&_complete_constant],
    ["SYMBOL",     \&_parse_symbol,     0,  \&_code_symbol,   $alphabet,  0,    \&_complete_list],
    ["JUNK",       \&_parse_junk,       1,  \&_code_junk,     $anything,  1,    \&_complete_none],
    ["SPACE",      \&_parse_space,      0,  sub { () },       $spaces,    1,    \&_complete_list],
    ["BLACKSPACE", \&_parse_blackspace, 0,  sub { () },       $nonspaces, 1,    \&_complete_list],
    ["ANYTHING",   \&_parse_anything,   0,  sub { () },       $anything,  0,    \&_complete_none],
    ["ASM_CODE",   \&_parse_asm_code,   0,  \&_code_asm_code, $digits,    0,    \&_complete_asm_code],
);

sub _parse_constant {
    #my ($src, $pos, $grammar, $start) = @_;
    pos($_[0]) = $_[1];
    return () unless $_[0] =~ /\G0*(\d{1,5})/go;
    $_[1] = pos($_[0]);
    my $con = $1 + 0;
    return $con if $con < 65536;
    $_[1]--;
    return int($con / 10);
}

sub _code_constant {
    my ($number) = @_;
    my @code = BC($number);
    (pack('C*', @code), scalar(@code));
}

sub _complete_constant {
    my ($src, $pos, $grammar, $pf) = @_;
    my $con = substr($src, $pos);
    return [0..9] if $con eq '' || $con < 6553;
    return [0..5] if $con == 6553;
    return [];
}

sub _parse_asm_code {
    #my ($src, $pos, $grammar, $start) = @_;
    pos($_[0]) = $_[1];
    return () unless $_[0] =~ /\G0*(\d{1,3})/go;
    $_[1] = pos($_[0]);
    my $con = $1 + 0;
    return $con if $con < 128;
    $_[1]--;
    return int($con / 10);
}

sub _code_asm_code {
    my ($number) = @_;
    (pack('C', $number), 1);
}

sub _complete_asm_code {
    my ($src, $pos, $grammar, $pf) = @_;
    my $con = substr($src, $pos);
    return [0..9] if $con eq '' || $con < 12;
    return [0..7] if $con == 12;
    return [];
}

sub _complete_list {
    my ($src, $pos, $grammar, $pf) = @_;
    my $vec = $pf->[4];
    my @cpl = ();
    for (my $sym = 0; $sym < 8 * length $vec; $sym++) {
	push @cpl, chr($sym) if vec($vec, $sym, 1);
    }
    return \@cpl;
}

sub _complete_none {
    my ($src, $pos, $grammar, $pf) = @_;
    return [];
}

sub _parse_symbol {
    #my ($src, $pos, $grammar, $start) = @_;
    pos($_[0]) = $_[1];
    return () unless $_[0] =~ /\G(\w+)/go;
    $_[1] = pos($_[0]);
    return $1;
}

sub _code_symbol {
    my ($string) = @_;
    (pack('C*', BC_STR, BC(length $string)) . $string, 1);
}

sub _parse_junk {
    #my ($src, $pos, $grammar, $start) = @_;
    my (undef, undef, $grammar, $start) = @_;
    my $junk = $grammar->{junk_symbol};
    return () unless $junk && $junk <= @{$grammar->{productions}};
    if (! exists $grammar->{junk_cache}{$_[1]}) {
	# XXX this could be made more efficient, for now we'll leave it at this
	my $end = undef;
	$grammar->{junk_symbol} = 0;
	my $cspace = $grammar->{cspace};
	my $compile = $grammar->{compile};
	my $ls = length($_[0]);
	for (my $p = $_[1] + 1; $p < $ls; $p++) {
	    $cspace->($p);
	    my $t = $compile->($grammar, $junk, $_[0], $p, $cspace, 1);
	    next unless @$t;
	    $end = $p;
	    last;
	}
	$grammar->{junk_symbol} = $junk;
	if (! defined $end) {
	    $end = $ls;
	    $grammar->{junk_cache}{$end} = $end;
	}
	for (my $p = $_[1]; $p < $end; $p++) {
	    $grammar->{junk_cache}{$p} = $end;
	}
    }
    my $ej = $grammar->{junk_cache}{$_[1]};
    defined $start or $start = $_[1];
    my $res = substr($_[0], $start, $ej - $start);
    $_[1] = $ej;
    $res;
}

sub _code_junk {
    my ($string) = @_;
    $string =~ s/^\s+//o;
    $string =~ s/\s+$//o;
    (pack('C*', BC_STR, BC(length $string)) . $string, 1);
}

sub _parse_space {
    #my ($src, $pos, $grammar, $start) = @_;
    pos($_[0]) = $_[1];
    return () unless $_[0] =~ /\G([ \t\012\015]+)/go;
    $_[1] = pos($_[0]);
    $1;
}

sub _parse_blackspace {
    #my ($src, $pos, $grammar, $start) = @_;
    pos($_[0]) = $_[1];
    return () unless $_[0] =~ /\G([^ \t\012]+)/go;
    $_[1] = pos($_[0]);
    $1;
}

sub _parse_anything {
    #my ($src, $pos, $grammar, $start) = @_;
    my $p = $_[1];
    return () if $p >= length $_[0];
    $_[1] = $p + 1;
    substr($_[0], $p, 1);
}

# precompile provides optimised access to _parse_space etc to be used when
# using the compiler's SPACE symbol - this saves quite a lot of compile time
sub _precompile {
    my ($grammar, $source, $space, $compile) = @_;
    my $predefs = $grammar->{predefined};
    if (exists $predefs->{$space}) {
	if ($predefs->{$space}[1] == \&_parse_space) {
	    return (
		sub {
		    pos($source) = $_[0];
		    return unless $source =~ /\G[ \t\012\015]+/go;
		    $_[0] = pos($source);
		},
		[' ', "\t", "\012", "\015"],
	    );
	}
	if ($predefs->{$space}[1] == \&_parse_blackspace) {
	    return (
		sub {
		    pos($source) = $_[0];
		    return unless $source =~ /\G[^ \t\012]+/go;
		    $_[0] = pos($source);
		},
		[grep { ! /^[ \t\012]/ } map { chr } (0..255)],
	    );
	}
	my $sub = $predefs->{$space}[1];
	my $start = $predefs->{$space}[4];
	return (
	    sub { $sub->($source, \$_[0], $grammar); },
	    [map { chr } grep { vec($start, $_, 1) } (0..255)],
	);
    }
    return (sub {}, []) unless $space && $space <= @{$grammar->{productions}};
    my $start = '';
    for my $prod (@{$grammar->{productions}[$space]}) {
	$start |= $prod->[2];
    }
    return (
	sub {
	    my $p = $compile->($grammar, $space, $source, $_[0], sub {}, 0);
	    # now find the longest matching result
	    for my $e (@$p) {
		my ($start, $end) = @$e;
		$_[0] = $end if $_[0] < $end;
	    }
	},
	[map { chr } grep { vec($start, $_, 1) } (0..255)],
    );
}

sub new {
    @_ == 2 or croak "Usage: new Language::INTERCAL::Parser(SYMBOLTABLE)";
    my ($class, $symboltable) = @_;
    my %predefined = ();
    for my $pf (@parser_predefined) {
	my $sn = $symboltable->find($pf->[0]);
	$predefined{$sn} = $pf;
    }
    bless {
	productions => [],
	converted => 1,
	rule_count => 0,
	symboltable => $symboltable,
	predefined => \%predefined,
	recsyms => '',
    }, $class;
}

sub forall {
    @_ == 2 or croak "Usage: GRAMMAR->forall(CODE)";
    my ($grammar, $code) = @_;
    my $p = $grammar->{productions};
    my $s = $grammar->{symboltable};
    my @prod = ();
    for (my $sym = 0; $sym < @$p; $sym++) {
	next unless $p->[$sym];
	for my $prod (@{$p->[$sym]}) {
	    my ($left, $right, $_1, $_2, $_3, $prodnum) = @$prod;
	    push @prod, [$prodnum, $sym, $left, $right];
	}
    }
    for my $prod (sort { $a->[0] <=> $b->[0] } @prod) {
	my ($prodnum, $sym, $left, $right) = @$prod;
	$right = _unconvert_right($right, $left);
	$code->($grammar, $s, $prodnum, $sym, $left, $right);
    }
}

sub start_profiling {
    @_ == 1 or croak "Usage: GRAMMAR->start_profiling";
    my ($grammar) = @_;
    $grammar->{profiling} = [];
    $grammar;
}

sub profile {
    @_ >= 2 or croak "Usage: GRAMMAR->profiling(CODE [,ARGS])";
    my ($grammar, $code, @args) = @_;
    my $f = $grammar->{profiling};
    $f or croak "Grammar was not set up for profiling";
    my $p = $grammar->{productions};
    my $s = $grammar->{symboltable};
    my @counts;
    for (my $symbol = 1; $symbol < @$f; $symbol++) {
	my $fp = $f->[$symbol];
	$fp or next;
	for (my $prod = 0; $prod < @$fp; $prod++) {
	    $fp->[$prod] or next;
	    my ($count, $cost) = @{$fp->[$prod]};
	    $count and push @counts, [$count, $cost, $symbol, $prod];
	}
    }
    for my $cp (sort { $b->[0] <=> $a->[0] } @counts) {
	my ($count, $cost, $symbol, $prod) = @$cp;
	my ($left, $right) = @{$p->[$symbol][$prod]};
	$right = _unconvert_right($right, $left);
	$code->($grammar, $s, $count, $cost, $symbol, $left, $right, @args);
    }
}

sub stop_profiling {
    @_ == 1 or croak "Usage: GRAMMAR->stop_profiling";
    my ($grammar) = @_;
    delete $grammar->{profiling};
    $grammar;
}

sub start_recording {
    @_ == 2 or croak 'Usage: GRAMMAR->start_recording(\@LIST)';
    my ($grammar, $list) = @_;
    $grammar->{recording} = {};
    my $table = $grammar->{symboltable};
    # add to the list of what we are already recording; multiple modules could
    # all ask to record some information, and we need to record the union of
    # all these requests
    my $recsyms = $grammar->{recsyms};
    for my $s (@$list) {
	if (defined $s) {
	    my $v = $table->find($s);
	    $v and vec($recsyms, $v, 1) = 1;
	} else {
	    vec($recsyms, 0, 1) = 1;
	}
    }
    $grammar->{recsyms} = $recsyms;
    $grammar;
}

sub syntax_record {
    @_ == 1 or croak "Usage: GRAMMAR->syntax_record";
    my ($grammar) = @_;
    my $f = $grammar->{recording};
    $f or croak "Grammar was not set up for recording";
    $f;
}

sub stop_recording {
    @_ == 1 or croak "Usage: GRAMMAR->stop_recording";
    my ($grammar) = @_;
    delete $grammar->{recording};
    $grammar->{recsyms} = '';
    $grammar;
}

sub read {
    @_ == 2 or croak "Usage: GRAMMAR->read(FILEHANDLE)";
    my ($grammar, $fh) = @_;

    # make it faster to run next time
    _convert_grammar($grammar);

    my $plist = $grammar->{productions};
    $fh->read_binary(pack('vv', $grammar->{rule_count}, scalar @$plist));
    for (my $symbol = 1; $symbol < @$plist; $symbol++) {
	my $gp = $plist->[$symbol] || [];
	$fh->read_binary(pack('v', scalar @$gp));
	for my $prod (@$gp) {
	    my ($left, $right, $initial, $startmap, $empty, $prodnum) = @$prod;
	    _read_left($fh, $left);
	    _read_right($fh, $right);
	    $fh->read_binary(pack('vvCv', length($initial), length($startmap),
					  $empty ? 1 : 0, $prodnum));
	    $fh->read_binary($initial);
	    $fh->read_binary($startmap);
	}
    }

    $grammar;
}

sub _read_left {
    my ($fh, $left) = @_;
    $fh->read_binary(pack('v', scalar(@$left)));
    for my $element (@$left) {
	my ($type, $e, $c, @e) = @$element;
	$fh->read_binary($type);
	if ($type eq 's') {
	    $fh->read_binary(pack('v', $e));
	} else {
	    $fh->read_binary(pack('v/a*', $e));
	}
	$fh->read_binary(pack('v', $c));
    }
}

sub _read_right {
    my ($fh, $right) = @_;
    $fh->read_binary(pack('v', scalar(@$right)));
    for my $element (@$right) {
	my $type = $element->[0];
	my $e = $element->[1];
	$fh->read_binary($type);
	if ($type eq 'b') {
	    $fh->read_binary(pack('v/a*', $e));
	} elsif ($type ne '*') {
	    $fh->read_binary(pack('v', $e));
	}
    }
}

sub write {
    @_ == 3 or croak "Usage: write " .
		     "Language::INTERCAL::Parser(FILEHANDLE, SYMBOLS)";
    my ($class, $fh, $symboltable) = @_;

    my ($rule_count, $nsymbols) = unpack('vv', $fh->write_binary(4));
    my @productions = ();
    for (my $symbol = 1; $symbol < $nsymbols; $symbol++) {
	my $nprod = unpack('v', $fh->write_binary(2));
	my @prod = ();
	while (@prod < $nprod) {
	    my $left = _write_left($fh);
	    my $right = _write_right($fh);
	    my ($ninit, $mapsize, $empty, $prodnum) =
		unpack('vvCv', $fh->write_binary(7));
	    my $initial = $fh->write_binary($ninit);
	    my $startmap = $fh->write_binary($mapsize);
	    push @prod,
		[$left, $right, $initial, $startmap, $empty, $prodnum];
	}
	$productions[$symbol] = \@prod;
    }

    my %predefined = ();
    for my $pf (@parser_predefined) {
	my $sn = $symboltable->find($pf->[0]);
	$predefined{$sn} = $pf;
    }
    my $grammar = bless {
	symboltable => $symboltable,
	productions => \@productions,
	converted => 1,
	rule_count => $rule_count,
	predefined => \%predefined,
    }, $class;

    $grammar;
}

sub _write_left {
    my ($fh) = @_;
    my $elems = unpack('v', $fh->write_binary(2));
    my @left = ();
    while ($elems-- > 0) {
	my $type = $fh->write_binary(1);
	my $data = '';
	my @comp = ();
	if ($type eq 's') {
	    $data = unpack('v', $fh->write_binary(2));
	} else {
	    my $size = unpack('v', $fh->write_binary(2));
	    $data = uc($fh->write_binary($size));
	    @comp = (length($data));
	}
	my $count = unpack('v', $fh->write_binary(2));
	push @left, [$type, $data, $count, @comp];
    }
    \@left;
}

sub _write_right {
    my ($fh) = @_;
    my $elems = unpack('v', $fh->write_binary(2));
    my @right = ();
    while ($elems-- > 0) {
	my $type = $fh->write_binary(1);
	my $data = '';
	if ($type eq 'b') {
	    my $len = unpack('v', $fh->write_binary(2));
	    $data = $fh->write_binary($len);
	} elsif ($type ne '*') {
	    $data = unpack('v', $fh->write_binary(2));
	}
	push @right, [$type, $data];
    }
    \@right;
}

sub _convert_left {
    my ($left) = @_;
    [map { $_->[0] eq 'c' && $_->[1] eq ''
	   ? ()
	   : $_->[0] eq 'c'
	     ? [$_->[0], uc($_->[1]), $_->[2], length($_->[1])]
	     : [$_->[0], $_->[1], $_->[2]];
    } @$left];
}

sub _find_right {
    my ($grammar, $left, $type, $number, $data) = @_;
    for (my $lp = 0; $lp < @$left; $lp++) {
	my $l = $left->[$lp];
	next if $l->[0] ne $type;
	next if $l->[0] eq 's' && $l->[1] != $data;
	next if $l->[0] ne 's' && $l->[1] ne $data;
	$number--;
	return $lp if $number < 1;
    }
    if ($type eq 's') {
	faint(SP_CREATION, "Symbol " .
			   $grammar->{symboltable}->symbol($data) .
			   " not found");
    } elsif ($type eq 'c') {
	my @data = unpack('C*', $data);
	faint(SP_CREATION, "Block (@data) not found");
    }
    faint(SP_CREATION, "Internal error");
}

sub _convert_right {
    my ($right, $left, $grammar) = @_;
    [map {
	$_->[0] eq 'c' && $_->[2] eq ''
	    ? ()
	    : $_->[0] =~ /^[scr]$/o
		? [$_->[0], _find_right($grammar, $left, $_->[0], $_->[1], $_->[2])]
		: $_->[0] eq 'n'
		    ? [$_->[0], _find_right($grammar, $left, 's', $_->[1], $_->[2])]
		    : $_->[0] eq '*'
			? [$_->[0]]
			: [$_->[0], $_->[1]];
    } @$right];
}

sub _unconvert_right {
    my ($right, $left) = @_;
    [map {
	$_->[0] =~ /^[scr]$/o ?
	    [$_->[0], _count_left($_->[0], $_->[1], $left)] :
	$_->[0] eq 'n' ?
	    [$_->[0], _count_left('s', $_->[1], $left)] :
	[$_->[0], $_->[1]];
    } @$right];
}

sub _count_left {
    my ($type, $number, $left) = @_;
    my $count = 0;
    my $data = $left->[$number][1];
    for (my $lp = 0; $lp <= $number; $lp++) {
	my $l = $left->[$lp];
	next if $l->[0] ne $type;
	next if $l->[0] eq 's' && $l->[1] != $data;
	next if $l->[0] ne 's' && $l->[1] ne $data;
	$count++;
    }
    ($count, $data);
}

# compile_top works similarly to compile but is useful for some types of
# top-level symbols, as it avoids compile's potentially exponential
# behaviour. Returns a list of generated code fragments (no completion
# is attempted)

sub compile_top {
    @_ == 7 || @_ == 8
	or croak "Usage: GRAMMAR->compile_top(TOP, INT, SOURCE, " .
		 "POS, SPACE, JUNK [, VERBOSE])";
    my ($grammar, $tsymb, $isymb, $source, $ipos, $space, $junk, $verb) = @_;
    _convert_grammar($grammar);
    my @result = ();
    $grammar->{junk_cache} = {};
    $grammar->{junk_symbol} = $junk;
    my $compile = _set_compile($grammar, 0);
    my ($cspace, $sspace) = _precompile($grammar, $source, $space, $compile);
    $grammar->{cspace} = $cspace;
    $grammar->{sspace} = $sspace;
    my $started_pos = $ipos;
    my $started_time = time;
    my $reported_time = $started_time;
    while ($ipos < length $source) {
	if ($verb) {
	    my $now = time;
	    if ($now - $reported_time > 60) {
		my $s = substr($source, $ipos);
		$s =~ s/\s+/ /go;
		$s =~ s/^ //o;
		$s = substr($s, 0, 28);
		my $fraction = ($ipos - $started_pos)
			     / (length($source) - $started_pos);
		my $eta = '';
		if ($fraction > .1) {
		    $eta = $started_time + ($now - $started_time) / $fraction;
		    my @eta = localtime($eta);
		    $eta = sprintf " ETA: %02d:%02d:%02d", @eta[2, 1, 0];
		}
		my @now = localtime($now);
		my $d = length(length $source);
		printf STDERR
		    "\n    %02d:%02d:%02d: done to %${d}d %-30s %5.1f%%%s",
		    @now[2,1,0], $ipos, "[$s]", 100 * $fraction, $eta;
		$reported_time = $now;
	    }
	}
	my $pos = $ipos++;
	defined _parse_junk($source, $ipos, $grammar)
	    or $ipos = length $source;
	# avoid a duplicate compile of the first statement
	if ($pos == 0) {
	    my $P = $pos;
	    $cspace->($P);
	    if ($P == $ipos) {
		$ipos++;
		defined _parse_junk($source, $ipos, $grammar)
		    or $ipos = length $source;
	    }
	}
	my $pp = $compile->($grammar, $tsymb, $source, $pos, $cspace, 0);
	if ($isymb) {
	    for my $p (@$pp) {
		my ($ps, $pe, $pj, $pc, $pn, @pu) = @$p;
		if ($pe < length($source)) {
		    my $ip =
			$compile->($grammar, $isymb, $source, $pe, $cspace, 0);
		    if (@$ip) {
			for my $i (@$ip) {
			    my ($is, $ie, $ij, $ic, $in, @iu) = @$i;
			    push @result, $pc . $ic;
			}
		    } else {
			push @result, $pc;
		    }
		} else {
		    push @result, $pc;
		}
	    }
	} else {
	    push @result, map { $_->[3] } @$pp;
	}
    }
    @result;
}

# compile attempts to generate code; returns two ARRAYREFs, a list of
# generated code with elements [start, end, uses_junk?, code, count, @prods],
# and a list of possible completion if source is a prefix of a parseable string
# both lists will be empty if nothing can be parsed

sub compile {
    @_ == 6
	or croak "Usage: GRAMMAR->compile(SYMBOL, SOURCE, POS, SPACE, JUNK)";
    my ($grammar, $isymb, $source, $start, $space, $junk) = @_;
    _convert_grammar($grammar);
    $grammar->{junk_cache} = {};
    $grammar->{junk_symbol} = $junk;
    my $compile = _set_compile($grammar, 1);
    my ($cspace, $sspace) = _precompile($grammar, $source, $space, $compile);
    $grammar->{cspace} = $cspace;
    $grammar->{sspace} = $sspace;
    my %complete = ();
    my $r = $compile->($grammar, $isymb, $source, $start, $cspace, 0, \%complete);
    ($r, [keys %complete]);
}

# _compile is provided as a text string and then instantiated multiple times,
# depending on three separate settings:
#   completing  determine all possible completions if the input looks valid
#               but truncated
#   profiling   count the use of each production, for grammar profiling
#   recording   record which grammar rules were used for each part of the source
# comments or other elements in the code identify statements relevant to a
# particular setting only and will be deleted when the setting is off
my $_compile = <<'END_COMPILE';
sub {
    my ($grammar, $isymb, $source, $start, $cspace, $any, $complete) = @_;
    return [] if $isymb < 1;
    my $productions = $grammar->{productions};
    my $pos = $start;
    $cspace->($pos);
    return [] if $pos >= length $source && ! $complete;
    my $predefs = $grammar->{predefined};
    my @result = ();
    # special case out of the main loop (they should not normally do this)
    my $recsyms = $grammar->{recsyms}; # recording
    if (exists $predefs->{$isymb}) {
	my $pf = $predefs->{$isymb};
	if ($pos >= length $source && ! $pf->[5]) {
	    if ($complete) { # completing
		my $cpl = $pf->[6]->($source, $pos, $grammar, $pf); # completing
		$complete->{$_} = 1 for @$cpl; # completing
	    } # completing
	} else {
	    my $end = $pos;
	    my @ok = $pf->[1]->($source, $end, $grammar, $start);
	    my $bad = $pf->[2] ? $end - $start : 0;
	    if ($end >= length $source && $complete) { # completing
		my $cpl = $pf->[6]->($source, $end, $grammar, $pf); # completing
		$complete->{$_} = 1 for @$cpl, @{$grammar->{sspace}}; # completing
	    } # completing
	    if (@ok) {
		my ($code, $count) = $pf->[3]->(@ok);
		vec($recsyms, $isymb, 1) # recording
		    and push @{$grammar->{recording}{$start}{$end}}, [$isymb, $bad];
		$cspace->($end);
		push @result, [$start, $end, $bad, $code, $count];
	    }
	}
	return \@result;
    }
    # normal case, parsing on user-defined symbols
    return [] if $isymb >= @$productions;
    my $iprod = $productions->[$isymb];
    return [] if ! $iprod || ! @$iprod;
    # prepare a list of states which look promising
    my $profiling = $grammar->{profiling};
    my @state = ();
    {
	my $nxc = $pos < length($source) ? vec($source, $pos, 8) : undef;
	for (my $prodnum = @$iprod - 1; $prodnum >= 0; $prodnum--) {
	    next unless $iprod->[$prodnum][4]
		     || ! defined $nxc
		     || vec($iprod->[$prodnum][2], $nxc, 1);
	    $profiling->[$isymb][$prodnum][0]++;
	    my $cp = 1; # profiling
	    push @state, [
		$isymb, $prodnum, 0, $pos, 0, [],
		\$cp, # profiling
		[], $pos, 0, # recording
	    ];
	}
    }
    my $cpspace = 0;
    STATE: while (@state) {
	my ($symb, $prodnum, $prodelem, $place, $bad, $stack,
	    $cost, # profiling
	    $recording_tree, $recording_start, $recording_end,
	    @tree) = @{pop @state};
	my $sprod = $productions->[$symb][$prodnum];
	my $left = $sprod->[0];
	ELEM: while ($prodelem < @$left) {
	    my ($type, $data, $count, $aux) = @{$left->[$prodelem]};
	    $$cost++; # profiling
	    $profiling->[$symb][$prodnum][1]++;
	    $prodelem++;
	    if ($type eq 's') {
		if (exists $predefs->{$data}) {
		    # predefined symbol - we can just run its code here
		    my $pf = $predefs->{$data};
		    if ($place < length $source || $pf->[5]) {
			my $end = $place;
			my @ok = $pf->[1]->($source, $end, $grammar, $start);
			if ($end >= length $source && $complete) { # completing
			    my $cpl = $pf->[6]->($source, $place, $grammar, $pf); # completing
			    $complete->{$_} = 1 for @$cpl; # completing
			    $cpspace = 1; # completing
			} # completing
			next STATE unless @ok;
			$bad += $end - $place if $pf->[2];
			push @tree, [$pf->[3]->(@ok)];
			vec($recsyms, $data, 1) # recording
			    and push @$recording_tree, [$place, $end, $data];
			$recording_end = $end;
			$cspace->($end);
			$place = $end;
			next ELEM;
		    } elsif ($complete) { # completing
			my $cpl = $pf->[6]->($source, $place, $grammar, $pf); # completing
			$complete->{$_} = 1 for @$cpl; # completing
		    }
		    next STATE;
		} else {
		    # user defined symbol - we need to push the current
		    # state onto the stack and add new states to @state
		    next STATE if $data >= @$productions;
		    my $prod = $productions->[$data];
		    next STATE if ! $prod || ! @$prod;
		    pos($source) = $place;
		    push @$stack, [
			$symb, $prodnum, $prodelem, $bad,
			$cost, # profiling
			$recording_tree, $recording_start, $recording_end,
			@tree,
		    ];
		    my $nxc = $place < length $source
			    ? vec($source, $place, 8)
			    : undef;
		    for (my $pn = @$prod - 1; $pn >= 0; $pn--) {
			next unless $prod->[$pn][4]
				 || ! defined $nxc
				 || vec($prod->[$pn][2], $nxc, 1);
			$profiling->[$data][$pn][0]++;
			my $cp = 1; # profiling
			push @state, [
			    $data, $pn, 0, $place, 0, [@$stack],
			    \$cp # profiling
			    [], $place, 0, # recording
			];
		    }
		    next STATE;
		}
	    } elsif ($type eq 'c') {
		# constant - just check if the required string is there
		my $look = uc(substr($source, $place, $aux));
		if ($data eq $look) {
		    # yep, it's there - add the place to the current tree
		    # in case the code generator wants it
		    push @tree, [$place, $aux];
		    vec($recsyms, 0, 1) # recording
			and push @$recording_tree, [$place, $place + $aux];
		    $place += $aux;
		    $recording_end = $place;
		    $cspace->($place);
		    $cpspace = 1 if $place >= length $source;
		    next ELEM;
		} elsif ($complete && # completing
			 length($look) < length($data) && # completing
			 substr($data, 0, length($look)) eq $look) # completing
		{ # completing
		    # a substring of the wanted string is there - handle completing
		    $complete->{substr($data, length($look))} = 1; # completing
		}
		next STATE;
	    }
	}
	# end of production - generate code
	my $uses = '';
	vec($uses, $sprod->[5], 1) = 1;
	for my $t (@tree) {
	    my ($x, $c, $u) = @$t;
	    defined $u and $uses |= $u;
	}
	my ($code, $count) = _gencode($source, $left, $sprod->[1], \@tree,
				      $start, $place - $start, $bad, $uses);
	if (@$stack) {
	    # we were called by another nonterminal
	    $profiling->[$symb][$prodnum][1] += $$cost;
	    my ($nsym, $nprd, $nelm, $nbad,
		$ncost, # profiling
		$nrectree, $nrecstart, $nrecend, # recording
		@ntree) = @{pop @$stack};
	    $nbad += $bad;
	    $nrectree = [@$nrectree]; # recording, to avoid sharing state if > 1 prod
	    vec($recsyms, $symb, 1) || @$recording_tree
		and push @$nrectree, [$recording_start, $recording_end, $symb, $recording_tree];
	    @$left && $nrecend < $recording_end and $nrecend = $recording_end;
	    push @state, [
		$nsym, $nprd, $nelm, $place, $nbad, $stack,
		$ncost, # profiling
		$nrectree, $nrecstart, $nrecend, # recording
		@ntree, [$code, $count, $uses]
	    ];
	} else {
	    # top level symbol, in other words a (possibly partial) result
	    push @result, [$start, $place, $bad, $code, $count, $uses];
	    vec($recsyms, $symb, 1) || @$recording_tree
		and push @{$grammar->{recording}{$recording_start}{$recording_end}},
		    [$symb, $bad, $recording_tree];
	    return \@result if $any;
	}
    }
    if ($complete && $cpspace) { # completing
	$complete->{$_} = 1 for @{$grammar->{sspace}}; # completing
    } # completing
    return \@result;
}
END_COMPILE

my %compile_cache;
sub _set_compile {
    my ($grammar, $complete) = @_;
    my $subname = '_compile_';
    $complete and $subname .= 'c';
    $grammar->{profiling} and $subname .= 'p';
    $grammar->{recording} and $subname .= 'r';
    if (exists $compile_cache{$subname}) {
	my $compile = $compile_cache{$subname};
	$grammar->{compile} = $compile;
	return $compile;
    }
    my $src = $_compile;
    $complete or $src =~ s/^.*completing.*$//gm;
    $grammar->{profiling} or $src =~ s/^.*profiling.*$//gm;
    $grammar->{recording} or $src =~ s/^.*recording.*$//gm;
    my $code = eval $src;
    $@ and die $@;
    $grammar->{compile} = $code;
    $compile_cache{$subname} = $code;
    $code;
}

sub _gencode {
    my ($source, $left, $right, $tree, $start, $length, $junk, $uses) = @_;
    my $code = '';
    for my $rp (@$right) {
	my ($type, $value) = @$rp;
	if ($type eq 'b') {
	    $code .= $value;
	    next;
	}
	if ($type eq 's') {
	    $code .= $tree->[$value][0];
	    next;
	}
	if ($type eq 'n') {
	    $code .= pack('C*', BC($tree->[$value][1]));
	    next;
	}
	if ($type eq 'c') {
	    my ($place, $len) = @{$tree->[$value]};
	    my $const = substr($source, $place, $len);
	    my @v = unpack('C*', $const);
	    $code .= pack('C*', BC_MUL, map { BC($_) } scalar(@v), @v);
	    next;
	}
	if ($type eq '*') {
	    $code .= pack('C*', map { BC($_) } $start, $length, $junk, length $uses);
	    $code .= $uses;
	    next;
	}
    }
    my $count = 0;
    for (my $lp = 0; $lp < @$left; $lp++) {
	my $lc = $left->[$lp][2];
	$count += $lc == 0xffff ? $tree->[$lp][1] : $lc;
    }
    return ($code, $count);
}

sub _find_starts {
    my ($grammar) = @_;

    # first find if any symbol can expand (directly) to empty strings
    # or (directly) to another symbol; since information about each of
    # these changes our idea of the other, we keep repeating until we
    # cannot make any more changes
    my $empty = '';

    my $found = 0;
    for (my $symb = 1; $symb < @{$grammar->{productions}}; $symb++) {
	my $plist = $grammar->{productions}[$symb];
	next unless $plist;
	for my $prod (@$plist) {
	    $prod->[2] = '';
	    $prod->[3] = '';
	    $prod->[4] = 0;
	}
	$found++;
    }
    return $empty unless $found;

    my $continue = 1;
    while ($continue) {
	$continue = 0;
	SYMB: for (my $symb = 1; $symb < @{$grammar->{productions}}; $symb++) {
	    my $plist = $grammar->{productions}[$symb];
	    next unless $plist;
	    PROD: for my $prod (@$plist) {
		# look at the first element of the production, if there's one
		ELEM: for my $p (@{$prod->[0]}) {
		    if ($p->[0] eq 's') {
			# that means we can access this particular symbol
			$continue = 1 if ! vec($prod->[3], $p->[1], 1);
			vec($prod->[3], $p->[1], 1) = 1;
			# if we know the symbol can parse the empty string,
			# we also need to check the next element
			next if vec($empty, $p->[1], 1);
		    }
		    next if $p->[0] eq 'c' && $p->[1] eq '';
		    next PROD;
		}
		# if we get here, all productions are empty, so...
		$continue = 1 if ! vec($empty, $symb, 1);
		vec($empty, $symb, 1) = 1;
		$prod->[4] = 1;
	    }
	}
    }

    for (my $symb = 1; $symb < @{$grammar->{productions}}; $symb++) {
	my $plist = $grammar->{productions}[$symb];
	next unless $plist;
	for my $prod (@$plist) {
	    faint(SP_CIRCULAR, $grammar->{symboltable}->symbol($symb))
		if vec($prod->[3], $symb, 1);
	}
    }

    return $empty;
}

sub _convert_grammar {
    my ($grammar) = @_;

    return if exists $grammar->{converted};
    my $empty = _find_starts($grammar);
    my @i_total = map { '' } @{$grammar->{productions}};
    my $predefs = $grammar->{predefined};

    # first find the "direct" initials;
    SYMB: for (my $symb = 1; $symb < @{$grammar->{productions}}; $symb++) {
	my $plist = $grammar->{productions}[$symb];
	next unless $plist;
	PROD: for my $prod (@$plist) {
	    next unless $prod;
	    $prod->[2] = '';
	    # look at the first element of the production, if there's one
	    ELEM: for my $p (@{$prod->[0]}) {
		if ($p->[0] eq 'c') {
		    next if $p->[1] eq '';
		    my $l = ord(lc(substr($p->[1], 0, 1)));
		    my $u = ord(uc(substr($p->[1], 0, 1)));
		    vec($i_total[$symb], $l, 1) = 1;
		    vec($i_total[$symb], $u, 1) = 1;
		    vec($prod->[2], $l, 1) = 1;
		    vec($prod->[2], $u, 1) = 1;
		    next PROD;
		}
		if ($p->[0] eq 's' && exists $predefs->{$p->[1]}) {
		    my $pf = $predefs->{$p->[1]};
		    my $st = $pf->[4];
		    my $em = $pf->[5];
		    $i_total[$symb] |= $st;
		    $prod->[2] |= $st;
		    next if $em;
		    next PROD;
		}
		next if ($p->[0] eq 's' && vec($empty, $p->[1], 1));
		next PROD;
	    }
	}
    }
    
    # now propagate %i_... using %starts
    my $continue = 1;
    while ($continue) {
	$continue = 0;
	for (my $symb = 1; $symb < @{$grammar->{productions}}; $symb++) {
	    my $plist = $grammar->{productions}[$symb];
	    next unless $plist;
	    for my $prod (@$plist) {
		for (my $other = 0; $other < 8 * length($prod->[3]); $other++) {
		    next unless vec($prod->[3], $other, 1);
		    my $init = $i_total[$other];
		    my $np = $prod->[2] | $init;
		    $continue = 1
			if $np ne substr($prod->[2], 0, length($np));
		    $prod->[2] |= $init;
		    $i_total[$symb] |= $init;
		}
	    }
	}
    }

    my $mask = '';
    for (my $symb = 1; $symb < @{$grammar->{productions}}; $symb++) {
	if (exists $predefs->{$symb}) {
	    vec($mask, $symb, 1) = 1;
	    next;
	}
	my $plist = $grammar->{productions}[$symb];
	next unless $plist;
	for my $prod (@$plist) {
	    $prod->[3] = substr($prod->[3], 0, 1) & $mask;
	}
    }

    $grammar->{converted} = 1;
}

sub _left_equal {
    my ($l1, $l2) = @_;
    return 0 if @$l1 != @$l2;
    for (my $c = 0; $c < @$l1; $c++) {
	my ($t1, $d1, $c1, $a1) = @{$l1->[$c]};
	my ($t2, $d2, $c2, $a2) = @{$l2->[$c]};
	return 0 if $t1 ne $t2;
	return 0 if $c1 != $c2;
	if ($t1 eq 's') {
	    return 0 if $d1 != $d2;
	} elsif ($t1 eq 'c') {
	    return 0 if $d1 ne $d2;
	} else {
	    return 0;
	}
    }
    return 1;
}

sub _right_equal {
    my ($r1, $r2) = @_;
    return 0 if @$r1 != @$r2;
    for (my $c = 0; $c < @$r1; $c++) {
	my ($t1, $v1) = @{$r1->[$c]};
	my ($t2, $v2) = @{$r2->[$c]};
	return 0 if $t1 ne $t2;
	if ($t1 eq 'b') {
	    return 0 if $v1 ne $v2;
	} elsif ($t1 eq 's' || $t1 eq 'c' || $t1 eq 'n') {
	    return 0 if $v1 != $v2;
	} elsif ($t1 ne '*') {
	    return 0;
	}
    }
    return 1;
}

sub _find_rule {
    my ($grammar, $symb, $left, $right) = @_;
    return () if $symb >= @{$grammar->{productions}};
    my $prods = $grammar->{productions}[$symb];
    return () unless $prods;
    my @found = ();
    SYMB: for (my $pp = 0; $pp < @$prods; $pp++) {
	my ($l, $r, $i, $s, $e, $c) = @{$prods->[$pp]};
	# see if this production is same as $left and (if provided) $right
	next SYMB if ! _left_equal($l, $left);
	next SYMB if $right && ! _right_equal($r, $right);
	push @found, $c;
    }
    return @found;
}

sub add {
    @_ == 4 or croak "Usage: GRANMAR->add(SYMBOL, LEFT, RIGHT)";
    my ($grammar, $symb, $left, $right) = @_;
    $left = _convert_left($left);
    $right = _convert_right($right, $left, $grammar);
    # do we already have this production?
    PROD: for my $prod (@{$grammar->{productions}[$symb]}) {
	my ($l, $r, $i, $s, $e, $c) = @$prod;
	next PROD if ! _left_equal($left, $l);
	next PROD if ! _right_equal($right, $r);
	# we have it, no need to add anything or make any changes
	return -$c;
    }
    my $prodnum = ++$grammar->{rule_count};
    push @{$grammar->{productions}[$symb]},
	[$left, $right, '', '', 0, $prodnum];
    delete $grammar->{converted};
    $prodnum;
}

sub find_rule {
    @_ == 3 || @_ == 4
	or croak "Usage: GRANMAR->find_rule(SYMBOL, LEFT [, RIGHT])";
    my ($grammar, $symb, $left, $right) = @_;
    $left = _convert_left($left);
    $right = _convert_right($right, $left, $grammar) if $right;
    my @rules = _find_rule($grammar, $symb, $left, $right);
    wantarray ? @rules : $rules[0];
}

1;
