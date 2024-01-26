package Language::INTERCAL::Charset::Baudot;

# Convert between Baudot and ASCII

# This file is part of CLC-INTERCAL.

# Copyright (C) 1999, 2000, 2002, 2006-2008, 2023 Claudio Calvelli, all rights reserved

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Charset/Baudot.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_NOSUCHCHAR);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(ascii2baudot baudot2ascii);

my @charset = (
	"\000E\nA SIU\rDRJNFCKTZWLHYPQOBG2MXV1",
	"\000e\na siu\rdrjnfcktzwlhypqobg2mxv1",
	"\0003\n- \a87\r\$4',!:(5\")2 6019?&3./;0",
	"\000\242\n+\t\\#=\r*{~\245|^<[}>]\b@\253\243\254\377\2613%_\2730",
);

my $charset = join('', map { "\000" . substr($_, 1, 26) .
			     "\000" . substr($_, 28, 3) . "\000" }
		           @charset);
push @charset, '';

sub baudot2ascii {
    @_ == 1 or croak "Usage: baudot2ascii(STRING)";
    my $string = shift;
    my $set = 0;
    my $result = '';
    while ($string ne '') {
    	my $chr = ord($string) & 037;
	$string = substr($string, 1);
	if ($chr == 033 || $chr == 037) {
	    $set = vec($charset[$set], $chr, 8) & 03;
	} else {
	    $result .= substr($charset[$set], $chr, 1);
	}
    }
    $result;
}

sub ascii2baudot {
    @_ == 1 or @_ == 2 or croak "Usage: ascii2baudot(STRING)";
    my $string = shift;
    my $faint = @_ ? shift : 1;
    my $set = 4;
    my $result = '';
    while ($string ne '') {
    	my $chr = substr($string, 0, 1);
	$string = substr($string, 1);
	my $pos = index($charset[$set], $chr);
	if ($pos < 0 || $pos == 033 || $pos == 037) {
	    $pos = index($charset, $chr);
	    if ($pos < 0 || $chr eq "\000") {
		faint(SP_NOSUCHCHAR, ord($chr), "Baudot") if $faint;
		$string = sprintf("\\%03o", ord($chr)) . $string;
		next;
	    }
	    my $s = $pos >> 5;
	    $pos = $pos & 037;
	    if ($set > 3) {
		$result .= ['[_', '__', '_[', '[[']->[$s];
	    } else {
		$result .= ['', '_', '[', '[[',
			    '[_', '', '[', '[[',
			    '_', '__', '', '[[',
			    '_', '__', '_[', '',
			   ]->[($set << 2) | $s];
	    }
	    $set = $s;
	}
	$result .= sprintf("%c", 0x40 + $pos);
    }
    $result;
}

1;

__END__

=head1 NAME

Charset::Baudot - convert between INTERCAL variant of Extended Baudot and ASCII

=head1 SYNOPSIS

    use Charset::Baudot 'baudot2ascii';

    my $a = baudot2ascii"(Baudot text)";

=head1 DESCRIPTION

I<Charset::Baudot> defines functions to convert between a subset of ASCII and a
subset of nonstandard Baudot - the original Baudot allows only letters,
numbers, and some punctuation. We assume that a "Shift to letters" code
while already in letters mode means "Shift to lowercase" and "Shift to
figures" while already in figures mode means "Shift to symbols". This allows
to use up to 120 characters. However, for simplicity some characters are
available in multiple sets, so the total is less than that.

Two functions, I<baudot2ascii> and I<ascii2baudot>, are exportable (but
not exported by default). They do the obvious thing to their first argument
and return the transformed string.

=head1 BAUDOT CHARACTER TABLE

The following are the characters recognised. As described, the "shift"
characters have nonstandard meaning.

     set   Letters     Lowercase    Figures    Symbols
  code
    00       N/A          N/A         N/A        N/A
    01        E            e           3        Cents
    02       L/F          L/F         L/F        L/F    (line feed)
    03        A            a           -          +
    04      Space        Space       Space       Tab
    05        S            s          BELL        \
    06        I            i           8          #
    07        U            u           7          =
    08       C/R          C/R         C/R        C/R    (carriage return)
    09        D            d           $          *
    10        R            r           4          {
    11        J            j           '          ~
    12        N            n           ,         XOR
    13        F            f           !          |
    14        C            c           :          ^
    15        K            k           (          <
    16        T            t           5          [
    17        Z            z           "          }
    18        W            w           )          >
    19        L            l           2          ]
    20        H            h          N/A     backspace
    21        Y            y           6          @
    22        P            p           0          «
    23        Q            q           1        POUND
    24        O            o           9         NOT
    25        B            b           ?        delete
    26        G            g           &          ±
    27     Figures      Figures     Symbols    Symbols
    28        M            m           .          %
    29        X            x           /          _
    30        V            v           ;          »
    31    Lowercase    Lowercase    Letters    Letters

=head1 COPYRIGHT

This module is part of CLC-INTERCAL.

Copyright (C) 1999, 2000, 2002, 2006-2008, 2023 Claudio Calvelli, all rights reserved

See files README and COPYING in the distribution for information.

=head1 SEE ALSO

A qualified psychiatrist.

