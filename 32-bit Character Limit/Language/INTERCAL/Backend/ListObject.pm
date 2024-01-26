package Language::INTERCAL::Backend::ListObject;

# Produce a (non-executable) listing of an object

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend/ListObject.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::ByteCode '1.-94.-2.2',
    qw(bc_skip bc_forall bytedecode);
use Language::INTERCAL::Object '1.-94.-2.2', qw(:SFLAG :UFLAG);
use Language::INTERCAL::Interpreter::State '1.-94.-2.2';
use Language::INTERCAL::Backend::DumpRegisters;

use constant default_suffix => 'ilst';
use constant default_mode   => 0666;

use constant BYTES_PER_LINE => 8;

BEGIN {
    *_fold = \&Language::INTERCAL::Backend::DumpRegisters::_fold;
}

sub generate {
    @_ == 5 or croak "Usage: BACKEND->generate(INTERPRETER, NAME, HANDLE, OPTIONS)";
    my ($class, $int, $name, $fh, $options) = @_;

    local $ENV{LC_COLLATE} = 'C'; # help making sort output reproducible
    my $object = $int->object;

    if ($options->{utf8_hack}) {
	$fh->set_utf8_hack($options->{utf8_hack});
	$fh->read_charset($fh->read_charset);
    }

    #my ($perversion) = $Language::INTERCAL::Object::PERVERSION =~ /\s(\S+)$/;
    my $perversion = $object->perversion;
    my $format = $object->format;

    $fh->read_text("CLC-INTERCAL $perversion (format $format) Object List\n\n");

    # object flags
    $fh->read_text("FLAGS:\n");
    for my $fn (sort { lc($a) cmp lc($b) } $object->all_flags) {
	my $fv = $object->flag_value($fn);
	$fh->read_text("    $fn <- $fv\n");
    }
    $fh->read_text("\n");

    # code listing
    my $num_units = $object->num_units;
    $fh->read_text("CODE: $num_units units\n");
    for (my $unit = 0; $unit < $num_units; $unit++) {
	my $do = 0;
	my $please = 0;
	my ($source, $length, $code, $cptr, $flags) = $object->unit_code($unit);
	my $create = ($flags & UFLAG_nocreate) ? 'no' : 'has';
	my $multiple = ($flags & UFLAG_nomultiple) ? 'no' : 'has';
	my $frozen = ($flags & UFLAG_frozen) ? '' : 'not ';
	$fh->read_text("UNIT $unit ($create CREATE, $multiple MULTIPLE, ${frozen}FROZEN):\n");
	my %xref;
	my $shadow = 0;
	for my $xp (@$cptr) {
	    my ($sp, $cp) = @$xp;
	    for my $p (@$cp) {
		my ($fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru) = @$p;
		my $se = $sp + $sl - 1;
		my $s = '';
		if ($source ne '') {
		    $s = substr($source, $sp, $sl);
		    $s =~ s/\s+/ /g;
		    $s =~ s/^ //;
		    $s =~ s/ $//;
		}
		_fold($fh, "    \@$sp..$se", $s);
		if ($ll > 0) {
		    my $le = $ls + $ll - 1;
		    $fh->read_text("    LABEL \@$ls..$le\n");
		    $xref{$ls}{$le}{$sp} = undef;
		    _list_code($fh, $code, $ls, $le + 1);
		} elsif ($ls > 0) {
		    $fh->read_text("    LABEL: $ls\n");
		}
		if ($dl > 0) {
		    my $de = $ds + $dl - 1;
		    $fh->read_text("    DSX \@$ds..$de:\n");
		    $xref{$ds}{$de}{$sp} = undef;
		    _list_code($fh, $code, $ds, $de + 1);
		} elsif ($ds > 0) {
		    $fh->read_text("    DSX: $ds\n");
		}
                my $qual;
		my ($gn) = bytedecode($ge);
                defined $gn and $qual .= " ($gn)";
		for my $fp (@stmt_flags) {
		    $fl & $fp->[0] and $qual .= "; $fp->[1]";
		}
		if ($sp >= $shadow) {
		    $fl & stmt_please and $please++;
		    $do++;
		    $shadow = $sp + $sl;
		}
		$fh->read_text("    GERUND: $ge$qual\n");
		if (defined $ru && $ru ne '') {
		    my @ru;
		    my $l = 8 * length $ru;
		    for (my $rn = 0; $rn < $l; $rn++) {
			vec($ru, $rn, 1) and push @ru, $rn;
		    }
		    @ru and _fold($fh, "    DEPENDS ON", join(' ', @ru));
		}
		if ($xl > 0) {
		    my $xe = $xs + $xl - 1;
		    $fh->read_text("    CODE \@$xs..$xe:\n");
		    $xref{$xs}{$xe}{$sp} = undef;
		    _list_code($fh, $code, $xs, $xe + 1);
		}
		$fh->read_text("\n");
	    }
	}
	$do and $fh->read_text(sprintf("Unit %d PLEASE proportion: %.2f%%\n\n", $unit, 100 * $please / $do));
	my @xref = sort { $a <=> $b } keys %xref;
	if (@xref > 1) {
	    $fh->read_text("CODE XREF:\n");
	    my @xlist;
	    for my $xs (@xref) {
		for my $xe (sort { $a <=> $b } keys %{$xref{$xs}}) {
		    my $indent = "$xs..$xe: ";
		    my $space = 36 - length $indent;
		    my $line = join(' ', sort { $a <=> $b } keys %{$xref{$xs}{$xe}});
		    while (length($line) > $space) {
			my $item = substr($line, 0, $space + 1);
			$item =~ s/\s\S*$//;
			length($item) > $space and $item = substr($item, 0, $space);
			$item =~ s/\s+$//;
			push @xlist, $indent . $item;
			$indent = ' ' x length($indent);
			$line = substr($line, length($item));
			$line =~ s/^\s+//;
		    }
		    $line ne '' and push @xlist, $indent . $line;
		}
	    }
	    my $half = int(@xlist / 2);
	    my $skip = int((1 + @xlist) / 2);
	    for (my $n = 0; $n < $half; $n++) {
		my $p = $xlist[$n];
		length($p) < 36 and $p .= ' ' x (36 - length $p);
		$fh->read_text('    ' . $p . '    ' . $xlist[$n + $skip] . "\n");
	    }
	    $half != $skip and $fh->read_text('    ' . $xlist[$half] . "\n");
	    $fh->read_text("\n");
	}
    }

    # grammar and symbol table listing
    _list_symbols($fh, $object->symboltable);
    for (my $p = 1; $p <= $object->num_parsers; $p++) {
	$fh->read_text("GRAMMAR #$p:\n");
	_list_grammar($fh, $int, $p, $object->symboltable, $object->parser($p));
	$fh->read_text("\n");
    }

    # register listing
    my %options = (%$options, title => "REGISTERS:\n");
    Language::INTERCAL::Backend::DumpRegisters->generate($int, $name, $fh, \%options);
}

sub _code_text {
    my ($fh, $cs, $cp, $ep) = @_;
    my $et = $cp;
    if (! bc_skip($cs, \$et, $ep)) {
	_code_line($fh, $cs, $cp, 1, '???', 0);
	return 1;
    }
    my $len = $et - $cp;
    my $v = vec($cs, $cp, 8);
    my ($op, $desc, $type, $value, $args, $function) = bytedecode($v);
    my $sp = 0;
    if ($len >= BYTES_PER_LINE) {
	_code_line($fh, $cs, $cp, 1, $op, 0);
	$cp++;
	$type = $args;
	$sp = 2;
    }
    my @text = ();
    my $co = sub {
	my ($byte, $name) = @_;
	if (defined $name) {
	    push @text, $name;
	} else {
	    if (@text) {
		my $text = join(' ', @text);
		$text =~ s/<\s+/</g;
		$text =~ s/\s+>/>/g;
		_code_line($fh, $cs, $cp, $byte - $cp, $text, $sp);
		@text = ();
	    }
	    $cp = $byte;
	}
    };
    bc_forall($type, $cs, $cp, $ep, $co);
    return $len;
}

sub _list_code {
    my ($fh, $cs, $cp, $ep) = @_;
    while ($cp < $ep) {
	$cp += _code_text($fh, $cs, $cp, $ep);
    }
}

sub _code_line {
    my ($fh, $cs, $cp, $cl, $ts, $sp) = @_;
    while ($cl > 0 || $ts ne '') {
	my $code = sprintf("        %04X", $cp);
	my $c = $cl > BYTES_PER_LINE ? BYTES_PER_LINE : $cl;
	$cl -= $c;
	while ($c-- > 0) {
	    my $byte = vec($cs, $cp++, 8);
	    $code .= sprintf(" %02X", $byte);
	}
	$code .= ' ' x (40 + $sp - length $code);
	my $text = substr($ts, 0, 32 - $sp);
	$text =~ s/\S+$// if $text ne $ts;
	$text =~ s/\s+$//;
	$text = substr($ts, 0, 32 - $sp) if $text eq '';
	$fh->read_text($code . $text . "\n");
	$ts = substr($ts, length $text);
	$ts =~ s/^\s+//;
    }
}

sub _list_symbols {
    my ($fh, $table) = @_;
    my %s = map { ($table->symbol($_) => $_) } (1..$table->max);
    keys %s or return;
    $fh->read_text("SYMBOL TABLE:\n");
    my $lk = 0;
    my $lv = 0;
    for my $s (keys %s) {
	$lk = length($s) if $lk < length($s);
	$lv = length($s{$s}) if $lv < length($s{$s});
    }
    my $ll = $lk + $lv + 3;
    my @s0 = map { sprintf("%-${ll}s", "$_: $s{$_}") }
		 sort { lc($a) cmp lc($b) } keys %s;
    my @s1 = map { sprintf("%${lv}d: %s", $s{$_}, $_) }
		 sort { $s{$a} <=> $s{$b} } keys %s;
    while (@s0) {
	$fh->read_text("    " . shift(@s0) . "     " . shift(@s1) . "\n");
    }
    $fh->read_text("\n");
}

sub _list_grammar {
    my ($fh, $int, $gra, $table, $grammar) = @_;
    my ($rules, $bitmap) = Language::INTERCAL::Interpreter::State::getrules($int, $gra);
    my $code = sub {
	my ($g, $s, $prodnum, $sym, $left, $right) = @_;
	# determine if these rules are enabled
	my $enab = $rules->[$prodnum] && vec($bitmap, $rules->[$prodnum], 1)
		 ? "ENABLED"
		 : "DISABLED";
	$fh->read_text("    #$prodnum $enab\n");
	my $start = "        ?" . $table->symbol($sym);
	my $data = '';
	$data .= ' ,,' unless @$left;
	for my $l (@$left) {
	    my ($t, $v, $c) = @$l;
	    if ($t eq 's') {
		$data .= ' ?' . $table->symbol($v);
	    } else {
		$data .= ' ,';
		$data .= '!' if $t eq 'r';
		if ($v =~ /^[^\W_]+$/) {
		    $data .= $v;
		} else {
		    $data .= join(' + ', map { "#$_" } unpack('C*', $v));
		}
		$data .= ',';
	    }
	    $data .= '=' . $c if $c && $c < 65535;
	    $data .= '=*' if $c == 65535;
	}
	$data .= ' ==>';
	while (@$right) {
	    my ($t, $c, $v) = @{shift @$right};
	    if ($t eq 's' || $t eq 'n') {
		$data .= ' ';
		$data .= $t eq 'n' ? '!' : '?';
		$data .= $table->symbol($v);
	    } elsif ($t eq 'c' || $t eq 'r') {
		$data .= ' ,';
		$data .= '!' if $t eq 'r';
		if ($v =~ /^[^\W_]+$/) {
		    $data .= $v;
		} else {
		    $data .= join(' + ', map { "#$_" } unpack('C*', $v));
		}
		$data .= ',';
	    } elsif ($t eq 'b') {
		if ($c eq '') {
		    $data .= ' ,,';
		} else {
		    my $plus = ' ';
		    for my $u (unpack('C*', $c)) {
			$data .= $plus;
			$data .= bytedecode($u) || "?#$u";
			$plus = ' + ';
		    }
		}
		next;
	    } elsif ($t eq 'm') {
		unshift @$right, @$c;
		next;
	    } elsif ($t eq '*') {
		$data .= ' *';
		next;
	    } else {
		$data .= '???';
	    }
	    $data .= ' #' . $c;
	}
	$data =~ s/^ //;
	_fold($fh, $start, $data);
    };
    $grammar->forall($code);
}

1;
__END__

sub _list_right {
    my ($indent, $left, $right, $s, $fh) = @_;
    my $i = $indent;
    for (my $ep = 0; $ep < @$right; $ep++) {
	my ($type, $value) = @{$right->[$ep]};
	if ($type eq 's' || $type eq 'n') {
	    my $w = $value + 1;
	    my $bang = $type eq 'n' ? '!' : '';
	    $fh->read_text("$i$bang$s->[$left->[$value][1]]($w)");
	} elsif ($type eq 'r') {
	    my $v = $left->[$value][1];
	    $v =~ s/([\\\@])/\\$1/g;
	    $v =~ s/\n/\\n/g;
	    $v =~ s/\t/\\t/g;
	    $v =~ s/([\000-\037\177-\377])/
		    sprintf "\\%03o", ord($1)/ge;
	    my $w = $value + 1;
	    $fh->read_text("$i\@$v\@($w)");
	} elsif ($type eq 'c') {
	    my $v = $left->[$value][1];
	    $v =~ s/([\\"])/\\$1/g;
	    $v =~ s/\n/\\n/g;
	    $v =~ s/\t/\\t/g;
	    $v =~ s/([\000-\037\177-\377])/
		    sprintf "\\%03o", ord($1)/ge;
	    my $w = $value + 1;
	    $fh->read_text("$i\"$v\"($w)");
	} elsif ($type eq 'b') {
	    $fh->read_text("$i\{\n");
	    $ep++;
	    while ($ep < @$right && $right->[$ep][0] eq 'b') {
		$value .= $right->[$ep][1];
		$ep++;
	    }
	    $ep--;
	    _list_code($value, $fh, $indent . '    ');
	    $fh->read_text("$indent}");
	} elsif ($type eq 'm') {
	    $fh->read_text("$i\{{\n");
	    _list_right($indent . '    ', $left, $value, $s, $fh);
	    $fh->read_text("$indent}}");
	}
	$i = ' ' ;
    }
    $fh->read_text("\n");
}

1;
