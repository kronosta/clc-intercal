package Language::INTERCAL::Backend::DumpRegisters;

# Lists any registers modified by an object

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# USE EXAMPLE

# sick -lRun,DumpRegisters -o- program.i
# (or: sick -lRun,DumpRegisters -o- program.io)

# This runs the program until it either ends normally or splats, then produces
# a listting of all registers which have been modified by the program, and
# their last value; this could be useful for debugging or just curiosity

# Omitting the -o- will produce the registers dump in program.regs instead

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend/DumpRegisters.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Registers '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_whp REG_dos REG_shf reg_decode);
use Language::INTERCAL::Interpreter '1.-94.-2.2',
    qw(reg_value reg_print reg_trickle reg_pending);
use Language::INTERCAL::Arrays '1.-94.-2.2', qw(forall_elements);
use Language::INTERCAL::Time '1.-94.-2.3', qw(current_time);

use constant default_suffix => 'regs';
use constant default_mode   => 0666;

sub generate {
    @_ == 5 or croak "Usage: BACKEND->generate(INTERPRETER, NAME, HANDLE, OPTIONS)";
    my ($class, $int, $name, $fh, $options) = @_;
    local $ENV{LC_COLLATE} = 'C'; # help making sort output reproducible
    my $object = $int->object;
    if ($options->{utf8_hack}) {
	$fh->set_utf8_hack($options->{utf8_hack});
	$fh->read_charset($fh->read_charset);
    }
    my $has_title = exists $options->{title};
    my $print_title = 1;
    my $rcode = sub {
	my ($rtype, $rname, $rvalue) = @_;
	if ($print_title) {
	    $has_title and $fh->read_text($options->{title});
	    $print_title = 0;
	}
	my $d = reg_decode($rtype, $rname);
	if ($rtype == REG_spot || $rtype == REG_twospot) {
	    $d .= ' = ' . $rvalue->[reg_value];
	} elsif ($rtype == REG_tail || $rtype == REG_hybrid) {
	    my @prevsub = ();
	    $d .= ' = ';
	    forall_elements($rvalue->[reg_value], sub {
		my ($evalue, @subscripts) = @_;
		if (@prevsub) {
		    my $done = 0;
		    $done++ while ($done < @prevsub && $prevsub[$done] == $subscripts[$done]);
		    $d .= ']' x ($#subscripts - $done);
		    $d .= ', ';
		    $d .= '[' x ($#subscripts - $done);
		} else {
		    $d .= '[' x @subscripts;
		}
		@prevsub = @subscripts;
		$d .= $evalue;
	    });
	    $d .= @prevsub ? (']' x @prevsub) : '[]';
	} elsif ($rtype == REG_dos || $rtype == REG_shf) {
	    my $val = $rvalue->[reg_print]->($object, $rvalue->[reg_value]);
	    defined $val or $val = $rvalue->[reg_value];
	    $d .= ' = ' . $val;
	} elsif ($rtype == REG_whp) {
	    my $eq = ' = ';
	    if ($rvalue->[reg_value]{filehandle}) {
		$d .= $eq . $rvalue->[reg_value]{filehandle}->describe;
		$eq = '; ';
	    }
	    for my $sub (sort { $a <=> $b } grep { /^\d+$/ } keys %{$rvalue->{value}}) {
		$d .= $eq . $sub . '@' . $rvalue->[reg_value]{$sub};
		$eq = '; ';
	    }
	}
	my $first = '';
	$has_title and $first .= '    ';
	$first .= substr($d, 0, 4, '');
	_fold($fh, $first, $d, 1);
	if ($rvalue->[reg_trickle] && @{$rvalue->[reg_trickle]}) {
	    $d = '    ';
	    my $comma = 'Trickle:';
	    for my $p (@{$rvalue->[reg_trickle]}) {
		my ($dtype, $dnumber, $ms) = @$p;
		$d .= $comma . ' ' . reg_decode($dtype, $dnumber) . "\@$ms";
		$comma = ',';
	    }
	    $first = '';
	    $has_title and $first .= '    ';
	    $first .= substr($d, 0, 4, '');
	    _fold($fh, $first, $d, 1);
	}
	if ($rvalue->[reg_pending] && @{$rvalue->[reg_pending]}) {
	    my $now = current_time;
	    $d = '    ';
	    my $comma = 'Pending';
	    for my $p (@{$rvalue->[reg_pending]}) {
		my ($newval, $newtype, $when) = @$p;
		# XXX would need to decode $newval according to $newtype
		$d .= $comma . ' ' . $newval . sprintf '@%.3f', ($when - $now)->numify() / 1e6;
		$comma = ',';
	    }
	    $first = '';
	    $has_title and $first .= '    ';
	    $first .= substr($d, 0, 4, '');
	    _fold($fh, $first, $d, 1);
	}
	# XXX overload
    };
    $int->allreg($rcode, 'n');
    $print_title or $fh->read_text("\n");
}

sub _fold {
    my ($fh, $first, $text, $no_colon) = @_;
    $first .= ': ' if ! $no_colon && $first =~ /\S/ && $text =~ /\S/;
    my $space = 74 - length($first);
    while (length($text) > $space) {
	my $l = substr($text, 0, $space);
	$l =~ s/\S+$//;
	$l =~ s/\s+$//;
	$l = substr($text, 0, $space) if $l eq '';
	$fh->read_text($first . $l . "\n");
	$first = ' ' x length $first;
	substr($text, 0, length $l) = '';
	$text =~ s/^\s+//;
    }
    $fh->read_text($first . $text . "\n");
}

1;
