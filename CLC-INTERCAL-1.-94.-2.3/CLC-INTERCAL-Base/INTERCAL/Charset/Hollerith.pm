package Language::INTERCAL::Charset::Hollerith;

# Convert between Hollerith and ASCII

# This file is part of CLC-INTERCAL.

# Copyright (C) 2000, 2002, 2006-2008, 2023 Claudio Calvelli, all rights reserved

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Charset/Hollerith.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_NOSUCHCHAR);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(ascii2hollerith hollerith2ascii);

my @bitmask = ("\001\000", "\000\001", "\002\000", "\000\002",
	       "\004\000", "\000\004", "\010\000", "\000\010",
	       "\020\000", "\000\020", '', "\040\000", "\000\040");

sub mk_hollerith {
    my ($ascii, @punch) = @_;
    my $hollerith = "\000\000";
    while (@punch) {
	my $punch = shift @punch;
	die "Internal error (punch=$punch)"
	    if $punch >= @bitmask || $bitmask[$punch] eq '';
	$hollerith |= $bitmask[$punch];
    }
    $hollerith |= "\100\000" if "\000\000" eq ($hollerith & "\040\000");
    $hollerith |= "\000\100" if "\000\000" eq ($hollerith & "\000\040");
    ($ascii, $hollerith);
}

my %ascii2hollerith = map { mk_hollerith(@$_) } (
    ["'", 8, 2],
    [' '],
    ['!', 0, 9, 7],
    ['"', 12, 8, 2],
    ['#', 8, 3],
    ['$', 11, 8, 3],
    ['%', 0, 8, 2],
    ['&', 12, 8, 5],
    ['(', 0, 8, 4],
    [')', 12, 8, 4],
    ['*', 11, 8, 4],
    ['+', 12],
    [',', 0, 8, 3],
    ['-', 11],
    ['.', 12, 8, 3],
    ['/', 0, 1],
    [':', 0, 8, 5],
    [';', 0, 8, 6],
    ['<', 11, 0, 8, 4],
    ['=', 8, 5],
    ['>', 11, 12, 8, 4],
    ['?', 11, 8, 2],
    ['@', 8, 4],
    ['[', 0, 7, 4],
    ['\\', 8, 7],
    [']', 12, 7, 4],
    ['^', 11, 8, 6],
    ['_', 12, 11],
    ['`', 8, 6],
    ['{', 0, 6, 4],
    ['|', 11, 8, 5],
    ['}', 12, 6, 4],
    ['~', 11, 9, 7],
    ["\xa2", 12, 0, 1, 3],
    ["\xa5", 11, 0, 5],
    ['[]', 12, 0, 7, 4],
    ["\"\b.", 12, 8, 7, 3],
    ['0', 0],
    ['1', 1],
    ['2', 2],
    ['3', 3],
    ['4', 4],
    ['5', 5],
    ['6', 6],
    ['7', 7],
    ['8', 8],
    ['9', 9],
    ['A', 12, 1],
    ['B', 12, 2],
    ['C', 12, 3],
    ['D', 12, 4],
    ['E', 12, 5],
    ['F', 12, 6],
    ['G', 12, 7],
    ['H', 12, 8],
    ['I', 12, 9],
    ['J', 11, 1],
    ['K', 11, 2],
    ['L', 11, 3],
    ['M', 11, 4],
    ['N', 11, 5],
    ['O', 11, 6],
    ['P', 11, 7],
    ['Q', 11, 8],
    ['R', 11, 9],
    ['S', 2, 0],
    ['T', 3, 0],
    ['U', 4, 0],
    ['V', 5, 0],
    ['W', 6, 0],
    ['X', 7, 0],
    ['Y', 8, 0],
    ['Z', 9, 0],
    # Punched cards do not have lowercase - we use uppercase with overpunch
    ['a', 12, 1, 0],
    ['b', 12, 2, 1],
    ['c', 12, 3, 2],
    ['d', 12, 4, 3],
    ['e', 12, 5, 4],
    ['f', 12, 6, 5],
    ['g', 12, 7, 6],
    ['h', 12, 8, 7],
    ['i', 12, 9, 8],
    ['j', 11, 1, 0],
    ['k', 11, 2, 1],
    ['l', 11, 3, 2],
    ['m', 11, 4, 3],
    ['n', 11, 5, 4],
    ['o', 11, 6, 5],
    ['p', 11, 7, 6],
    ['q', 11, 8, 7],
    ['r', 11, 9, 8],
    ['s', 2, 1, 0],
    ['t', 3, 2, 0],
    ['u', 4, 3, 0],
    ['v', 5, 4, 0],
    ['w', 6, 5, 0],
    ['x', 7, 6, 0],
    ['y', 8, 7, 0],
    ['z', 9, 8, 0],
    # overline (tall worm?) is 11, 0
    # the following codes do not exist in Hollerith - we use "Christmas lights"
    ["\n", 12, 9, 8, 7, 6, 5, 4, 3, 2, 1],
    ["\r", 11, 9, 8, 7, 6, 5, 4, 3, 2, 1],
    ["\t", 0, 9, 8, 7, 6, 5, 4, 3, 2, 1],
);

my %asciimultiple = map { (substr($_, 0, length($_) - 1) => 1) }
			grep { length($_) > 1 }
			     keys %ascii2hollerith;

my %hollerith2ascii = reverse %ascii2hollerith;

#print join(' ', sort values %ascii2hollerith), "\n";
#print join(' ', sort keys %hollerith2ascii), "\n";
die "Internal error" if keys %ascii2hollerith != keys %hollerith2ascii;

sub hollerith2ascii {
    @_ == 1 or croak "Usage: hollerith2ascii(STRING)";
    my $string = shift;
    my $result = '';
    while ($string ne '') {
	my $char = substr($string, 0, 2);
	$string = substr($string, 2);
	$char .= "\000" if length($char) == 1;
	$char &= "\077\077";
	$char |= "\100\000" if "\000\000" eq ($char & "\040\000");
	$char |= "\000\100" if "\000\000" eq ($char & "\000\040");
	if (! exists $hollerith2ascii{$char}) {
	    my @punch = ();
	    for (my $punch = 0; $punch < @bitmask; $punch++) {
		push @punch, $punch if $bitmask[$punch] ne '' &&
				       ($char & $bitmask[$punch]) ne "\000\000";
	    }
	    push @punch, '(empty' unless @punch;
	    my $punch = join('-', sort { $b <=> $a } @punch);
	    faint(SP_NOSUCHCHAR, $punch, "Hollerith")
	}
	$result .= $hollerith2ascii{$char};
    }
    $result;
}

sub ascii2hollerith {
    @_ == 1 or croak "Usage: ascii2hollerith(STRING)";
    my $string = shift;
    my $result = '';
    while ($string ne '') {
	my $char = substr($string, 0, 1);
	$string = substr($string, 1);
	while ($string ne '' && exists $asciimultiple{$char}) {
	    my $next = substr($string, 0, 1);
	    last if ! exists $asciimultiple{$char . $next} &&
		    ! exists $ascii2hollerith{$char . $next};
	    $char .= $next;
	    $string = substr($string, 1);
	}
	$result .= $ascii2hollerith{$char} ||
	    faint(SP_NOSUCHCHAR, $char, "Hollerith")
    }
    $result;
}

1;

__END__

=head1 NAME

Charset::Hollerith - convert between INTERCAL variant of Hollerith and ASCII

=head1 SYNOPSIS

    use Charset::Hollerith qw(hollerith2ascii);

    my $a = hollerith2ascii "(Hollerith text)";

=head1 DESCRIPTION

I<Charset::Hollerith> defines functions to convert between a subset of ASCII
and a subset of nonstandard Hollerith (since there isn't such a thing as a
standard
Hollerith we defined our own variant which is guaranteed to be incompatible
with all versions of Hollerith used by IBM hardware - however, for each
character code we have used the code used by some (but not all) IBM card
reader, if the code exists in Hollerith at all, or we have made one up
in some logical way (such as overpunching) if no IBM hardware had that
particular character.

The two functions I<hollerith2ascii> and I<ascii2hollerith> are exportable
but not exported by default. They do the obvious thing to their argument.

=head1 HOLLERITH CHARACTER TABLE

A Hollerith string is a sequence of 12-bit characters; they are encoded as
two ASCII characters, containing 6 bits each: the first character contains
punches 12, 0, 2, 4, 6, 8 and the second character contains punches 11, 1,
3, 5, 7, 9; interleaving the two characters gives the original 12 bits.
To make the characters printable on ASCII terminals, bit 7 is always set to 0,
and bit 6 is set to the complement of bit 5. These two bits are ignored when
reading Hollerith cards.

Some Hollerith characters (produced by overpunching) can be converted
to sequences of ASCII characters; I<ascii2hollerith> will correctly
recognise the sequences.

The following punched cards document the encoding of characters; the
last card ends with nongraphic symbols in ASCII so the column heading
contains a two-letter abbreviation instead, and with the two
overpunch symbols we use, change and bookworm, whose column heading
shows the two characters, "C/" and "V-" respectively:

        ' !"#$%&()*+,-./:;<=>?@[\]^_`{|}~0123456789
   12      *   * * *  *     *    * *   *              12
   11        *    *  *    * **    **  * *             11
    0     *   * *   *  ****    *     *   *             0
    1                  *                  *            1
    2   *  *  *              *             *           2
    3       **      * *                     *          3
    4           ***       * * ** *   * *     *         4
    5          *        *  *          *       *        5
    6                    *        * ** *       *       6
    7     *                    ***      *       *      7
    8   *  ******** * * ******* * * * *          *     8
    9     *                             *         *    9

        ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrs
   12   *********                 *********             12
   11            *********                 *********    11
    0                     *********        *        *    0
    1   *        *                **       **       *    1
    2    *        *       *        **       **      *    2
    3     *        *       *        **       **          3
    4      *        *       *        **       **         4
    5       *        *       *        **       **        5
    6        *        *       *        **       **       6
    7         *        *       *        **       **      7
    8          *        *       *        **       **     8
    9           *        *       *        *        *     9

        tuvwxyz []  ".  NL  CR  HT  C/  V-
   12            *   *   *           *      12
   11                        *           *  11
    0   *******  *               *   *   *   0
    1                    *   *   *   *       1
    2   *                *   *   *           2
    3   **           *   *   *   *   *       3
    4    **      *       *   *   *           4
    5     **             *   *   *       *   5
    6      **            *   *   *           6
    7       **   *   *   *   *   *           7
    8        **      *   *   *   *           8
    9         *          *   *   *           9


PLEASE NOTE that versions of CLC-INTERCAL before 1.-94.-2 had a bug which
caused a rabbit to be represented as 12-3-2-8 instead of 12-3-7-8. Cards
punched with such older versions, and containing rabbits, will need to be
copied with one of the rabbit holes moved from row 2 to row 7.

=head1 COPYRIGHT

This module is part of CLC-INTERCAL.

Copyright (C) 2000, 2002, 2006, 2007 Claudio Calvelli, all rights reserved

See the files README and COPYING in the distribution for information.

=head1 SEE ALSO

A qualified psychiatrist.

