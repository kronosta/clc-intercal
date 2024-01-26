package Language::INTERCAL::Interpreter::State;

# Extends Interpreter with something to save its state and other internal things

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION @ISA @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Interpreter/State.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Math::BigInt try => 'GMP';
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Interpreter '1.-94.-2.3', qw(
    reg_value reg_default reg_overload reg_belongs
    reg_enrol reg_trickle reg_pending reg_ignore

    thr_ab_gerund thr_ab_label thr_ab_once thr_assign
    thr_grammar_record thr_registers thr_rules thr_stash
    thr_trickling
);
use Language::INTERCAL::Splats '1.-94.-3', qw(SP_LATE);

@ISA = qw(Language::INTERCAL::Interpreter);

use Language::INTERCAL::Splats '1.-94.-2.1', qw(faint SP_INTERNAL);
use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_whp);
use Language::INTERCAL::ByteCode '1.-94.-2.2',
    qw(BC_CON BC_SWA BC_CRE BC_DES);
use Language::INTERCAL::Arrays '1.-94.-2.2',
    qw(make_list make_sparse_list list_subscripts make_array expand_sparse_list replace_array);

use constant STATE_SKIP_ONCE => 0x01;
use constant STATE_OVERRIDE  => 0x02;

@EXPORT_OK = qw(
    STATE_SKIP_ONCE STATE_OVERRIDE
    register_extra encode_register decode_register clear_register
);

my @reg_save = (
    [ reg_overload, 2, \&_get_overload, \&_set_overload ],
    [ reg_belongs,  1, \&_get_belongs,  \&_set_belongs  ],
    [ reg_enrol,    1, \&_get_enrol,    \&_set_enrol    ],
    [ reg_trickle,  1, \&_get_trickle,  \&_set_trickle  ],
    [ reg_pending,  1, \&_get_pending,  \&_set_pending  ],
);

sub gave_up {
    @_ == 1 or croak "Usage: INTERPRETER->gave_up";
    my ($int) = @_;
    $int->{gave_up};
}

sub getrules {
    @_ == 2 or croak "Usage: INTERPRETER->getrules(GRAMMAR)";
    my ($int, $gra) = @_;
    my $rp = $int->{default}[thr_rules][$gra - 1] || [];
    wantarray ? ($rp, $int->{rules}) : $rp;
}

sub record_grammar {
    @_ == 2 or croak "Usage: INTERPRETER->record_grammar(HOW)";
    my ($int, $how) = @_;
    $int->{record_grammar} = $how;
    $int;
}

sub get_abstains {
    @_ == 1 or croak "Usage: INTERPRETER->get_abstains";
    my ($int) = @_;
    my $tp = $int->{default};
    my @labels = sort { $a <=> $b } keys %{$tp->[thr_ab_label]};
    my @gerunds = sort { $a <=> $b } keys %{$tp->[thr_ab_gerund]};
    my @onces = sort keys %{$tp->[thr_ab_once]};
    my $text = "ABR\n";
    $text .= pack('vvvv', $int->{ab_count}, scalar @labels, scalar @gerunds, scalar @onces);
    for my $l (@labels) {
	$text .= pack('vvv', $l, @{$tp->[thr_ab_label]{$l}});
    }
    for my $g (@gerunds) {
	$text .= pack('vvv', $g, @{$tp->[thr_ab_gerund]{$g}});
    }
    for my $o (@onces) {
	my ($u, $s) = split(/\./, $o);
	$text .= pack('vvvv', $u, $s, @{$tp->[thr_ab_once]{$o}});
    }
    $text;
}

sub set_abstains {
    @_ == 2 || @_ == 3
	or croak "Usage: INTERPRETER->set_abstains(DATA [, SKIP_ONCE])";
    my ($int, $text, $skip_once) = @_;
    $text =~ s/^ABR\n// or croak "Invalid abstain DATA";
    my ($count, $lc, $gc, @r) = unpack('v*', $text);
    defined $gc or croak "Invalid abstain DATA";
    my $oc = 0;
    if (! $skip_once) {
	@r or croak "Invalid abstain DATA";
	$oc = shift @r;
    }
    @r == 3 * ($lc + $gc) + 4 * $oc or croak "Invalid abstain DATA";
    my $tp = $int->{default};
    # create new abstain records
    $tp->[thr_ab_label] = {};
    $tp->[thr_ab_gerund] = {};
    $skip_once or $tp->[thr_ab_once] = {};
    $int->{ab_count} = $count;
    for (my $l = 0; $l < $lc; $l++) {
	my $n = shift @r;
	my $a = shift @r;
	my $c = shift @r;
	$tp->[thr_ab_label]{$n} = [$a, $c];
    }
    for (my $g = 0; $g < $gc; $g++) {
	my $n = shift @r;
	my $a = shift @r;
	my $c = shift @r;
	$tp->[thr_ab_gerund]{$n} = [$a, $c];
    }
    for (my $o = 0; $o < $oc; $o++) {
	my $u = shift @r;
	my $s = shift @r;
	my $a = shift @r;
	my $c = shift @r;
	$tp->[thr_ab_once]{"$u.$s"} = [$a, $c];
    }
    $int;
}

sub get_grammar_record {
    @_ == 1 or croak "Usage: INTERPRETER->get_grammar_record";
    my ($int) = @_;
    my $tp = $int->{default};
    my $gr = $tp->[thr_grammar_record];
    my $text = "GRR\n";
    my %smap = ();
    $text .= pack('v', scalar(@$gr));
    for my $g (@$gr) {
	$text .= chr($g->[0]);
	if ($g->[0] == BC_CON || $g->[0] == BC_SWA) {
	    $text .= pack('CC', $g->[1], $g->[2]);
	    next;
	}
	$g->[0] == BC_CRE || $g->[0] == BC_DES
	    or faint(SP_INTERNAL, "get_grammar_record found invalid record");
	$text .= pack('v', $g->[1]);
	$text .= _pack_symbol($int, $g->[2], \%smap);
	$text .= _pack_left($int, $g->[3], \%smap);
	$g->[0] == BC_CRE
	    and $text .= _pack_right($int, $g->[4], \%smap);
    }
    $text;
}

sub set_grammar_record {
    @_ == 2 or croak "Usage: INTERPRETER->set_grammar_record(DATA)";
    my ($int, $text) = @_;
    $text =~ s/^GRR\n// or croak "Invalid DATA: no grammar header";
    my ($gcount) = unpack('v', substr($text, 0, 2, ''));
    my $tp = $int->{default};
    my @smap = ();
    my @gr = ();
    for (my $n = 0; $n < $gcount; $n++) {
	my $t = ord(substr($text, 0, 1, ''));
	if ($t == BC_CON || $t == BC_SWA) {
	    my ($o1, $o2) = unpack('CC', substr($text, 0, 2, ''));
	    push @gr, [$t, $o1, $o2];
	    if ($t == BC_CON) {
		$int->_ii_CON($tp, $o1, $o2);
	    } else {
		$int->_ii_SWA($tp, $o1, $o2);
	    }
	    next;
	}
	$t == BC_CRE || $t == BC_DES or croak "Invalid DATA: invalid grammar opcode";
	my ($gra) = unpack('v', substr($text, 0, 2, ''));
	my $sym = _unpack_symbol(\$text, $int, \@smap);
	my $left = _unpack_left(\$text, $int, \@smap);
	if ($t == BC_CRE) {
	    my $right = _unpack_right(\$text, $int, \@smap);
	    push @gr, [$t, $gra, $sym, $left, $right];
	    $int->_ii_CRE($tp, $gra, $sym, $left, $right);
	} else {
	    push @gr, [$t, $gra, $sym, $left];
	    $int->_ii_DES($tp, $gra, $sym, $left);
	}
    }
    $tp->[thr_grammar_record] = \@gr;
    $text eq '' or croak "Invalid DATA: extra after grammar (" . length($text) . ")";
    $int;
}

sub _pack_symbol {
    my ($int, $sym, $smap) = @_;
    if (exists $smap->{$sym}) {
	return 'S' . pack('v', $smap->{$sym});
    }
    $sym = $int->{object}->symboltable->symbol($sym) || 0;
    my $num = scalar keys %$smap;
    $smap->{$sym} = $num;
    return 'M' . pack('v v/a*', $num, $sym);
}

sub _unpack_symbol {
    my ($text, $int, $smap) = @_;
    my $name;
    if ($$text =~ s/^S//) {
	my ($snum) = unpack('v', substr($$text, 0, 2, ''));
	$name = $smap->[$snum];
    } elsif ($$text =~ s/^M//) {
	my ($snum, $slen) = unpack('vv', substr($$text, 0, 4, ''));
	$name = substr($$text, 0, $slen, '');
	length($name) == $slen or croak "Invalid DATA: name ($name)";
	$smap->[$snum] = $name;
    } else {
	croak "Invalid DATA: invalid symbol";
    }
    $int->{object}->symboltable->find($name, 0);
}

sub _pack_left {
    my ($int, $left, $smap) = @_;
    my $text = pack('v', scalar @$left);
    for my $prod (@$left) {
	$text .= $prod->[0];
	if ($prod->[0] eq 's') {
	    $text .= _pack_symbol($int, $prod->[1], $smap);
	} else {
	    $text .= pack('v/a*', $prod->[1]);
	}
	$text .= pack('v', $prod->[2]);
    }
    $text;
}

sub _unpack_left {
    my ($text, $int, $smap) = @_;
    my ($num) = unpack('v', substr($$text, 0, 2, ''));
    my @left = ();
    while ($num-- > 0) {
	my $type = substr($$text, 0, 1, '');
	my $data;
	if ($type eq 's') {
	    $data = _unpack_symbol($text, $int, $smap);
	} else {
	    my $l = unpack('v', substr($$text, 0, 2, ''));
	    $data = substr($$text, 0, $l, '');
	    length $data == $l or croak "Invalid DATA";
	}
	my $count = unpack('v', substr($$text, 0, 2, ''));
	push @left, [$type, $data, $count];
    }
    \@left;
}

sub _pack_right {
    my ($int, $right, $smap) = @_;
    my $text = pack('v', scalar @$right);
    for my $prod (@$right) {
	$text .= $prod->[0];
	if ($prod->[0] eq 's' || $prod->[0] eq 'n') {
	    $text .= pack('v', $prod->[1]);
	    $text .= _pack_symbol($int, $prod->[2], $smap);
	} elsif ($prod->[0] eq 'c' || $prod->[0] eq 'r') {
	    $text .= pack('v v/a*', $prod->[1], $prod->[2]);
	} elsif ($prod->[0] eq 'b') {
	    $text .= pack('v/a*', $prod->[1]);
	}
    }
    $text;
}

sub _unpack_right {
    my ($text, $int, $smap) = @_;
    my ($num) = unpack('v', substr($$text, 0, 2, ''));
    my @right = ();
    while ($num-- > 0) {
	my $type = substr($$text, 0, 1, '');
	if ($type eq 's' || $type eq 'n') {
	    my $n = unpack('v', substr($$text, 0, 2, ''));
	    my $s = _unpack_symbol($text, $int, $smap);
	    push @right, [$type, $n, $s];
	} elsif ($type eq 'c' || $type eq 'r') {
	    my ($n, $l) = unpack('vv', substr($$text, 0, 4, ''));
	    my $s = substr($$text, 0, $l, '');
	    length $s == $l or croak "Invalid DATA";
	    push @right, [$type, $n, $s];
	} elsif ($type eq 'b') {
	    my $l = unpack('v', substr($$text, 0, 2, ''));
	    my $s = substr($$text, 0, $l, '');
	    length $s == $l or croak "Invalid DATA";
	    push @right, [$type, $s];
	}
    }
    \@right;
}

sub get_events {
    @_ == 1 or croak "Usage: INTERPRETER->get_events";
    my ($int) = @_;
    my $text = "EVR\n";
    my $ep = $int->{events} || [];
    $text .= pack('v', scalar @$ep);
    for my $ev (@$ep) {
	my ($cond, $body, $bge) = @$ev;
	$text .= pack('vvv', $bge, length($cond), length($body));
	$text .= $cond;
	$text .= $body;
    }
    $text;
}

sub set_events {
    @_ == 2 or croak "Usage: INTERPRETER->set_events(DATA)";
    my ($int, $text) = @_;
    $text =~ s/^EVR\n// or croak "Invalid DATA";
    my ($count) = unpack('v', substr($text, 0, 2, ''));
    my @ev = ();
    for (my $i = 0; $i < $count; $i++) {
	my ($bge, $clen, $blen) = unpack('vvv', substr($text, 0, 6, ''));
	my $cond = substr($text, 0, $clen, '');
	my $body = substr($text, 0, $blen, '');
	length($cond) == $clen && length($body) == $blen
	    or croak "Invalid DATA (clen or blen)";
	push @ev, [$cond, $body, $bge];
    }
    $text eq '' or croak "Invalid DATA";
    $int->{events} = \@ev;
    $int;
}

sub get_registers {
    @_ == 1 || @_ == 2 || @_ == 3
	or croak "Usage: INTERPRETER->get_registers [(TIMEBASE [, ROUNDING])]";
    my ($int, $timebase, $rounding) = @_;
    my $tp = $int->{default};
    my $rp = $tp->[thr_registers];
    my @rcode = ();
    # we assume special registers are restored by re-running extensions
    # or by using INTERPRETER->read, so we never dump them here;
    # we do dump classes (but not filehandles yet)
    for my $type (REG_spot, REG_twospot, REG_tail, REG_hybrid, REG_whp) {
	$rp->[$type] or next;
	for (my $number = 0; $number < @{$rp->[$type]}; $number++) {
	    my $rv = $rp->[$type][$number];
	    $rv or next;
	    my $sp = $tp->[thr_stash][$type][$number] || [];
	    if ($rv->[reg_default] && ! $rv->[reg_ignore] && ! @$sp) {
		my $save;
		for my $sv (@reg_save) {
		    my ($item, $array, $get, $set) = @$sv;
		    my $value = $rv->[$item];
		    $value or next;
		    if ($array == 1) {
			@$value or next;
		    } elsif ($array == 2) {
			keys %$value or next;
		    }
		    $save = 1;
		    last;
		}
		$save or next;
	    }
	    # dump this register
	    my @rv = map { encode_register($_, $type, $timebase, $rounding) } (@$sp, $rv);
	    my $len = pack('Cv*', $type, $number,
				  scalar @rv, map { length $_ } @rv);
	    push @rcode, join('', $len, @rv);
	}
    }
    my $ns = scalar @reg_save;
    join('', "REG $ns\n", pack('v', scalar @rcode), @rcode);
}

sub encode_register {
    @_ == 2 || @_ == 3 || @_ == 4
	or croak "Usage: encode_register(VALUE, TYPE [, TIMEBASE [, ROUNDING]})";
    my ($rv, $type, $timebase, $rounding) = @_;
    my $v = $rv->[reg_value];
    my $code = pack('CC', $rv->[reg_default] ? 1 : 0, $rv->[reg_ignore] ? 1 : 0);
    for my $sv (@reg_save) {
	my ($item, $array, $get, $set) = @$sv;
	my $value = $rv->[$item];
	if ($value) {
	    if ($array == 1) {
		$code .= pack('v', 1 + scalar @$value);
		$code .= $get->($_, $timebase, $rounding) for @$value;
		next;
	    } elsif ($array == 2) {
		my @keys = sort keys %$value;
		$code .= pack('v', 1 + scalar @keys);
		$code .= $get->($_, $value->{$_}, $timebase, $rounding) for @keys;
		next;
	    } else {
		# scalar value, which we don't actually save for now
		next;
	    }
	}
	# if we get here there was nothing to save so...
	$code .= pack('v', 0);
    }
    if ($type == REG_spot) {
	$code .= pack('v', $v);
    } elsif ($type == REG_twospot) {
	$code .= pack('V', $v);
    } elsif ($type == REG_whp) {
	my @subjects = sort { $a <=> $b } grep { /^\d+$/ } keys %$v;
	$code .= pack('v', scalar @subjects);
	for my $subject (@subjects) {
	    $code .= pack('vv', $subject, $v->{$subject});
	}
	# XXX dump filehandle?
    } else {
	if ($v && ref $v && @$v) {
	    my @v = make_list($v);
	    my @s = make_sparse_list(@v);
	    my $mode;
	    if (@s < @v) {
		undef @v;
		@v = @s;
		$mode = 2;
	    } else {
		undef @s;
		$mode = 1;
	    }
	    @s = list_subscripts($v);
	    $code .= pack('Cv*', $mode, scalar(@s), scalar(@v), @s);
	    if ($type == REG_hybrid) {
		$code .= pack('V*', @v);
	    } else {
		$code .= pack('v*', @v);
	    }
	} else {
	    # array not dimensioned
	    $code .= pack('C', 0);
	}
    }
    $code;
}

sub register_extra {
    return scalar @reg_save;
}

sub _get_overload {
    my ($key, $data, $timebase, $rounding) = @_;
    pack('vva*a*', length $key, length $data, $key, $data);
}

sub _get_belongs {
    my ($data, $timebase, $rounding) = @_;
    my ($type, $number) = @$data;
    pack('Cv', $type, $number);
}

sub _get_enrol {
    my ($data, $timebase, $rounding) = @_;
    pack('v', $data);
}

sub _get_trickle {
    my ($data, $timebase, $rounding) = @_;
    my ($type, $number, $ms) = @$data;
    pack('CvV', $type, $number, $ms);
}

sub _get_pending {
    my ($data, $timebase, $rounding) = @_;
    my ($newval, $newtype, $when) = @$data;
    if ($timebase || $rounding) {
	$when = $when->copy;
	$timebase and $when -= $timebase;
	if ($rounding) {
	    $when->badd($rounding / 2);
	    $when->bdiv($rounding);
	    $when->bmul($rounding);
	}
    }
    my $str = ($when <= 0) ? '' : $when->to_bytes;
    length($str) > 12 and faint(SP_LATE);
    my $pad = length($str) < 12 ? chr(0) x (12 - length($str)) : '';
    pack('CV', $newtype, $newval) . $pad . $str;
}

sub set_registers {
    @_ == 2 || @_ == 3 || @_ == 4
	or croak "Usage: INTERPRETER->set_registers(DATA [, OVERRIDE [, TIMEBASE]])";
    my ($int, $text, $over, $timebase) = @_;
    my $reg_extra;
    if ($text =~ s/^REG\n//) {
	$reg_extra = undef; # 1.-94.-2.2 or older data
    } elsif ($text =~ s/^REG\s+(\d*)\n//) {
	$reg_extra = $1;
	$reg_extra >= 1 && $reg_extra <= scalar(@reg_save)
	    or croak "Invalid DATA: reg_extra=$reg_extra";
    } else {
	croak "Invalid DATA: no REG header";
    }
    my $tp = $int->{default};
    my $rp = $tp->[thr_registers];
    my $sp = $tp->[thr_stash];
    length $text >= 2 or croak "Invalid DATA";
    my ($count) = unpack('v', substr($text, 0, 2, ''));
    while ($count-- > 0) {
	length $text >= 5 or croak "Invalid DATA";
	my ($type, $number, $cnum) = unpack('Cvv', substr($text, 0, 5, ''));
	length $text >= 2 * $cnum or croak "Invalid DATA";
	my @clen = unpack('v*', substr($text, 0, 2 * $cnum, ''));
	my @rv = ();
	for my $clen (@clen) {
	    length $text >= $clen or croak "Invalid DATA";
	    my $code = substr($text, 0, $clen, '');
	    push @rv, $code;
	}
	next if $rp->[$type][$number] && ! $rp->[$type][$number][reg_default] && ! $over;
	my $stashit = 0;
	# if this has an open filehandle we need to preserve it
	# when saving/restoring filehandles will be implemented we may remove this code
	my $save_fh = $type == REG_whp && $rp->[$type][$number][reg_value]{filehandle};
	$rp->[$type][$number] = undef;
	$save_fh and $rp->[$type][$number][reg_value]{filehandle} = $save_fh;
	$sp->[$type][$number] and @{$sp->[$type][$number]}
	    and @{$sp->[$type][$number]} = ();
	$int->_create_register($tp, $type, $number);
	for my $code (@rv) {
	    if ($stashit) {
		$int->_stash_register($tp, $type, $number);
	    }
	    $stashit = 1;
	    decode_register($code, $type, $reg_extra, $rp->[$type][$number], $timebase);
	}
    }
    $text eq '' or croak "Invalid DATA";
    for my $tt ($tp, @{$int->{threads}}) {
	$tt->[thr_trickling] = undef;
    }
    $int;
}

sub decode_register {
    @_ == 4 || @_ == 5
	or croak "Usage: decode_register(DATA, TYPE, EXTRA, REGISTER [, TIMEBASE})";
    my ($code, $type, $reg_extra, $bv, $timebase) = @_;
    my ($is_default, $ignored);
    if (defined $reg_extra) {
	length($code) >= 2 or croak "Invalid register: missing default";
	($is_default, $ignored) = unpack('CC', substr($code, 0, 2, ''));
    } else {
	length($code) >= 1 or croak "Invalid register: missing default";
	($is_default) = unpack('C', substr($code, 0, 1, ''));
	$ignored = $bv->[reg_ignore] || 0;
	$reg_extra = 1; # old format included only overloading
    }
    for (my $re = 0; $re < $reg_extra; $re++) {
	my ($item, $array, $get, $set) = @{$reg_save[$re]};
	if ($array == 1) {
	    length($code) >= 2 or croak "Invalid register: missing array length";
	    my $count = unpack('v', substr($code, 0, 2, ''));
	    $count or next;
	    my @data;
	    for (my $o = 1; $o < $count; $o++) {
		my $value = $set->(\$code, $timebase);
		push @data, $value;
	    }
	    $bv->[$item] = \@data;
	} elsif ($array == 2) {
	    length($code) >= 2 or croak "Invalid register: missing hash count";
	    my $count = unpack('v', substr($code, 0, 2, ''));
	    $count or next;
	    my %data;
	    for (my $o = 1; $o < $count; $o++) {
		my ($key, $value) = $set->(\$code, $timebase);
		$data{$key} = $value;
	    }
	    $bv->[$item] = \%data;
	} else {
	    # scalar value, which we don't actually save for now
	}
    }
    $bv->[reg_default] = $is_default ? 1 : 0;
    $bv->[reg_ignore] = $ignored ? 1 : 0;
    if ($type == REG_spot) {
	length($code) >= 2 or croak "Invalid register: missing spot value";
	$bv->[reg_value] = unpack('v', substr($code, 0, 2, ''));
    } elsif ($type == REG_twospot) {
	length($code) >= 4 or croak "Invalid register: missing twospot value";
	$bv->[reg_value] = unpack('V', substr($code, 0, 4, ''));
    } elsif ($type == REG_whp) {
	length($code) >= 2 or croak "Invalid register: missing subject count";
	my ($nsubjects) = unpack('v', substr($code, 0, 2, ''));
	while ($nsubjects-- > 0) {
	    length($code) >= 4 or croak "Invalid register: missing subject";
	    my ($what, $when) = unpack('vv', substr($code, 0, 4, ''));
	    $bv->[reg_value]{$what} = $when;
	}
	# XXX set filehandle?
    } else {
	length($code) >= 1 or croak "Invalid register: missing mode";
	my ($mode) = unpack('C', substr($code, 0, 1, ''));
	if ($mode) {
	    length($code) >= 4 or croak "Invalid register: missing value count";
	    my ($nsubs, $nvals) = unpack('vv', substr($code, 0, 4, ''));
	    my @subs = unpack('v*', substr($code, 0, 2 * $nsubs, ''));
	    my $v = make_array(\@subs);
	    my @vals;
	    if ($type == REG_hybrid) {
		length($code) >= 4 * $nvals or
		    croak "Invalid register: missing hybrid element";
		@vals = unpack('V*', substr($code, 0, 4 * $nvals, ''));
	    } else {
		length($code) >= 2 * $nvals or
		    croak "Invalid register: missing tail element";
		@vals = unpack('v*', substr($code, 0, 2 * $nvals, ''));
	    }
	    $mode == 2 and @vals = expand_sparse_list(@vals);
	    replace_array($v, $type, @vals);
	    $bv->[reg_value] = $v;
	} else {
	    $bv->[reg_value] = undef;
	}
    }
    $code eq '' or croak "Invalid register: extra code (" . length($code) . ")";
}

sub _set_overload {
    my ($data, $timebase) = @_;
    length($$data) >= 4 or croak "Invalid register: missing overload code";
    my ($kl, $vl) = unpack('vv', substr $$data, 0, 4, '');
    my $key = substr($$data, 0, $kl, '');
    my $value = substr($$data, 0, $vl, '');
    length $key == $kl && length $value == $vl or croak "Invalid DATA";
    ($key, $value);
}

sub _set_belongs {
    my ($data, $timebase) = @_;
    length($$data) >= 3 or croak "Invalid register: missing belongs";
    [unpack('Cv', substr($$data, 0, 3, ''))];
}

sub _set_enrol {
    my ($data, $timebase) = @_;
    length($$data) >= 2 or croak "Invalid register: missing enrol";
    [unpack('v', substr($$data, 0, 2, ''))];
}

sub _set_trickle {
    my ($data, $timebase) = @_;
    length($$data) >= 7 or croak "Invalid register: missing trickle";
    [unpack('CvV', substr($$data, 0, 7, ''))];
}

sub _set_pending {
    my ($data, $timebase) = @_;
    length($$data) >= 17 or croak "Invalid register: missing pending";
    my ($newtype, $newval) = unpack('CV', substr($$data, 0, 5, ''));
    # see _get_pending() for time encoding
    my $when = Math::BigInt->from_bytes(substr($$data, 0, 12, ''));
    $timebase and $when += $timebase;
    [$newval, $newtype, $when];
}

sub clear_register {
    @_ == 2 or croak "Usage: clear_register(TYPE, REGISTER)";
    my ($type, $bv) = @_;
    $bv->[reg_default] = 1;
    $bv->[reg_ignore] = 0;
    for my $sv (@reg_save) {
	my ($item, $array, $get, $set) = @$sv;
	if ($array == 1) {
	    $bv->[$item] = [];
	} elsif ($array == 2) {
	    $bv->[$item] = {};
	} else {
	    # scalar value, which we don't actually save for now
	}
    }
    if ($type == REG_spot || $type eq REG_twospot) {
	$bv->[reg_value] = 0;
    } elsif ($type == REG_whp) {
	$bv->[reg_value] = {};
    } elsif ($type == REG_tail || $type eq REG_hybrid) {
	$bv->[reg_value] = make_array([]);
    } else {
	$bv->[reg_value] = undef;
    }
}

sub _clear_overload {
    my ($data) = @_;
    my ($kl, $vl) = unpack(substr $$data, 0, 4, '');
    my $key = substr($$data, 0, $kl, '');
    my $value = substr($$data, 0, $vl, '');
    length $key == $kl && length $value == $vl or croak "Invalid DATA";
    ($key, $value);
}

sub _clear_belongs {
    my ($data) = @_;
    [unpack('Cv', substr($$data, 0, 3))];
}

sub _clear_enrol {
    my ($data) = @_;
    [unpack('v', sustr($$data, 0,2))];
}

sub _clear_trickle {
    my ($data) = @_;
    [unpack('CvV', substr($$data, 0, 7))];
}

sub _clear_pending {
    my ($data) = @_;
    my ($type, $number, $newval, $s1, $s2, $ms) = unpack('CvVVVV', substr($$data, 0, 19));
    # time values are (better be) 64 bits, but we can't assume a 64 bit perl
    # even though in 2023 anything else will be a bit unusable. But not to
    # worry, we have practice in forcing larger values into 32 bits, don't we?
    my $when  = $s1 * 4294967296.0 + $s2 + $ms / 1e6;
    [$type, $number, $newval, $when];
}

sub get_constants {
    @_ == 1 or croak "Usage: INTERPRETER->get_constants";
    my ($int) = @_;
    my $tp = $int->{default};
    my $ap = $tp->[thr_assign];
    my @al = sort { $a <=> $b } grep { ${$ap->{$_}} != $_ } keys %$ap;
    my @av = map { ($_ => ${$ap->{$_}}) } @al;
    my $text = "CON\n";
    $text .= pack('v*', scalar @al, @av);
    $text;
}

sub set_constants {
    @_ == 2 or croak "Usage: INTERPRETER->set_constants(DATA)";
    my ($int, $text) = @_;
    my $tp = $int->{default};
    $text =~ s/^CON\n// or croak "Invalid DATA";
    my ($count, @data) = unpack('v*', $text);
    @data == 2 * $count or croak "Invalid DATA";
    my %ap = ();
    while (@data) {
	my $c = shift @data;
	my $v = shift @data;
	$ap{$c} = \$v;
    }
    $tp->[thr_assign] = \%ap;
    $int;
}

sub get_state {
    @_ == 1 || @_ == 2 || @_ == 3
	or croak "Usage: INTERPRETER->get_state [(TIMEBASE [, ROUNDING])]";
    my ($int, $timebase, $rounding) = @_;
    my $text = "STA\n";
    for my $v ($int->get_abstains(),
	       $int->get_grammar_record(),
	       $int->get_events(),
	       $int->get_registers($timebase, $rounding),
	       $int->get_constants())
    {
	$text .= pack('v/a*', $v);
    }
    $text;
}

sub set_state {
    @_ == 2 || @_ == 3 || @_ == 4
	or croak "Usage: INTERPRETER->set_state(DATA [, FLAGS [, TIMEBASE]])";
    my ($int, $text, $flags, $timebase) = @_;
    $text =~ s/^STA\n// or croak "Invalid DATA";
    $int->{default}[thr_assign] = {}; # otherwise set_registers fails
    $flags ||= 0;
    # set abstains
    length $text >= 2 or croak "Invalid DATA: no abstain length";
    my ($len) = unpack('v', substr($text, 0, 2, ''));
    length $text >= $len or croak "Invalid DATA: no abstain data";
    $int->set_abstains(substr($text, 0, $len, ''), $flags & STATE_SKIP_ONCE);
    # replay grammar record
    length $text >= 2 or croak "Invalid DATA: no grammar length";
    ($len) = unpack('v', substr($text, 0, 2, ''));
    length $text >= $len or croak "Invalid DATA: no grammar data";
    $int->set_grammar_record(substr($text, 0, $len, ''));
    # set events
    length $text >= 2 or croak "Invalid DATA: no events length";
    ($len) = unpack('v', substr($text, 0, 2, ''));
    length $text >= $len or croak "Invalid DATA: no events data";
    $int->set_events(substr($text, 0, $len, ''));
    # set registers
    length $text >= 2 or croak "Invalid DATA: no registers length";
    ($len) = unpack('v', substr($text, 0, 2, ''));
    length $text >= $len or croak "Invalid DATA: no registers data";
    $int->set_registers(substr($text, 0, $len, ''), $flags & STATE_OVERRIDE, $timebase);
    # set constants
    length $text >= 2 or croak "Invalid DATA: no constants length";
    ($len) = unpack('v', substr($text, 0, 2, ''));
    length $text >= $len or croak "Invalid DATA: no constants data";
    $int->set_constants(substr($text, 0, $len, ''));
    # all done
    $text eq '' or croak "Invalid DATA: extra data (" . length($text) . ")";
    $int;
}

1;
