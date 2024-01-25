package Language::INTERCAL::Splats;

# Splats and error messages

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.


use strict;
use vars qw($VERSION $PERVERSION $DATAVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Splats.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-3', qw(import compare_version);
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension);
use vars qw(@EXPORT_OK);

$DATAVERSION = '1.-94.-2.3';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

@EXPORT_OK = qw(
    splatnumber splatname splatdescription faint add_splat
    SP_ARRAY SP_ASSIGN SP_BASE SP_BCMATCH SP_BUG SP_CHARSET SP_CIRCULAR
    SP_CLASS SP_CLASSWAR SP_COMEFROM SP_COMMENT SP_CONTEXT SP_CONVERT
    SP_CREATION SP_DIGITS SP_DIVERSION SP_DIVIDE SP_EARLY SP_EVENT
    SP_EVOLUTION SP_FALL_OFF SP_FORBIDDEN SP_HEADSPIN SP_HIDDEN SP_HOLIDAY
    SP_ILLEGAL SP_INDEPENDENT SP_INDIGESTION SP_INTERNAL SP_INTERNET
    SP_INVALID SP_INVARRAY SP_INVBELONG SP_INVCLASS SP_INVLABEL SP_INVSPEC
    SP_INVSPLAT SP_INVUNDOC SP_IOERR SP_IOMODE SP_IOTYPE SP_ISARRAY
    SP_ISCLASS SP_ISNUMBER SP_ISSPECIAL SP_JUNK SP_LANGUAGE SP_LATE
    SP_LECTURE SP_MODEERR SP_NEXTING SP_NOARRAY SP_NOASSIGN SP_NOBELONG
    SP_NOCLASS SP_NOCURRICULUM SP_NODATA SP_NODIM SP_NONUMBER SP_NOREGISTER
    SP_NORESUME SP_NOSPECIAL SP_NOSTUDENT SP_NOSUCHBELONG SP_NOSUCHCHAR
    SP_NOSUCHLABEL SP_NOSYSCALL SP_NOTCLASS SP_NOTHREAD SP_NOVALUE
    SP_NUMBER SP_OSERR SP_OVREG SP_QUANTUM SP_READ SP_REGISTER SP_REGNUM
    SP_RESUME SP_ROMAN SP_SEEKERR SP_SPECIAL SP_SPLAT SP_SPOT SP_SPOTS
    SP_SUBSCRIPT SP_SUBSIZE SP_SUBVERSION SP_SWAP SP_SYMBOL SP_SYSCALL
    SP_THREESPOT SP_TODO SP_TOOMANYLABS SP_UBUG SP_UNDOCUMENTED
);

my %splatbyname = (
    ARRAY => 280,
    ASSIGN => 277,
    BASE => 8,
    BCMATCH => 578,
    BUG => 774,
    CHARSET => 10,
    CIRCULAR => 818,
    CLASS => 254,
    CLASSWAR => 603,
    COMEFROM => 555,
    COMMENT => 0,
    CONTEXT => 398,
    CONVERT => 444,
    CREATION => 816,
    DIGITS => 534,
    DIVERSION => 249,
    DIVIDE => 662,
    EARLY => 999,
    EVENT => 751,
    EVOLUTION => 815,
    FALL_OFF => 633,
    FORBIDDEN => 796,
    HEADSPIN => 665,
    HIDDEN => 436,
    HOLIDAY => 799,
    ILLEGAL => 997,
    INDEPENDENT => 511,
    INDIGESTION => 664,
    INTERNAL => 634,
    INTERNET => 899,
    INVALID => 69,
    INVARRAY => 251,
    INVBELONG => 514,
    INVCLASS => 253,
    INVLABEL => 131,
    INVSPEC => 6,
    INVSPLAT => 457,
    INVUNDOC => 636,
    IOERR => 642,
    IOMODE => 641,
    IOTYPE => 9,
    ISARRAY => 243,
    ISCLASS => 244,
    ISNUMBER => 438,
    ISSPECIAL => 248,
    JUNK => 128,
    LANGUAGE => 700,
    LATE => 998,
    LECTURE => 699,
    MODEERR => 644,
    NEXTING => 123,
    NOARRAY => 245,
    NOASSIGN => 752,
    NOBELONG => 512,
    NOCLASS => 250,
    NOCURRICULUM => 823,
    NODATA => 703,
    NODIM => 241,
    NONUMBER => 701,
    NOREGISTER => 437,
    NORESUME => 621,
    NOSPECIAL => 257,
    NOSTUDENT => 822,
    NOSUCHBELONG => 513,
    NOSUCHCHAR => 109,
    NOSUCHLABEL => 129,
    NOSYSCALL => 660,
    NOTCLASS => 242,
    NOTHREAD => 369,
    NOVALUE => 256,
    NUMBER => 281,
    OSERR => 742,
    OVREG => 252,
    QUANTUM => 666,
    READ => 432,
    REGISTER => 433,
    REGNUM => 70,
    RESUME => 632,
    ROMAN => 4,
    SEEKERR => 643,
    SPECIAL => 247,
    SPLAT => 456,
    SPOT => 5,
    SPOTS => 274,
    SUBSCRIPT => 276,
    SUBSIZE => 279,
    SUBVERSION => 315,
    SWAP => 445,
    SYMBOL => 535,
    SYSCALL => 661,
    THREESPOT => 702,
    TODO => 1,
    TOOMANYLABS => 130,
    UBUG => 775,
    UNDOCUMENTED => 635,
);

my %splats = (
    0 => ['COMMENT', '%'],
    1 => ['TODO', 'Not implemented: %'],
    4 => ['ROMAN', 'Unknown read type for Roman numerals: %'],
    5 => ['SPOT', '% des not look like a one spot value'],
    6 => ['INVSPEC', 'Invalid value % for special register'],
    8 => ['BASE', 'Base must be between 2 and 7 (got %)'],
    9 => ['IOTYPE', 'Invalid I/O Type: %'],
    10 => ['CHARSET', 'Invalid character set: %'],
    69 => ['INVALID', 'Invalid bytecode (%) for %'],
    70 => ['REGNUM', 'Invalid register number "%"'],
    109 => ['NOSUCHCHAR', 'Invalid character (%) for %'],
    123 => ['NEXTING', 'Program attempted more than % levels of NEXTing'],
    128 => ['JUNK', 'Cannot use JUNK in this grammar'],
    129 => ['NOSUCHLABEL', 'Could not find label %'],
    130 => ['TOOMANYLABS', 'Cannot decide between % instances of label %'],
    131 => ['INVLABEL', 'Invalid label %'],
    241 => ['NODIM', 'Array not dimensioned'],
    242 => ['NOTCLASS', 'Non-class value used as class'],
    243 => ['ISARRAY', 'Array register used as value'],
    244 => ['ISCLASS', 'Class register used as value'],
    245 => ['NOARRAY', 'Non-array register used as array'],
    247 => ['SPECIAL', 'Attempt to use special register %'],
    248 => ['ISSPECIAL', 'Attempt to use special register as number'],
    249 => ['DIVERSION', 'Invalid diversion: % is % %'],
    250 => ['NOCLASS', 'Invalid value % assigned to class'],
    251 => ['INVARRAY', 'Invalid value in array element: %'],
    252 => ['OVREG', 'Cannot use overload register %'],
    253 => ['INVCLASS', 'Invalid lecture: %'],
    254 => ['CLASS', 'Invalid subject: %'],
    256 => ['NOVALUE', 'This register cannot hold a value'],
    257 => ['NOSPECIAL', 'Normal register used as special'],
    274 => ['SPOTS', 'Number % too large for %'],
    276 => ['SUBSCRIPT', 'Invalid subscript %: %'],
    277 => ['ASSIGN', 'Impossible assignment (base %): cannot find #X such that #%X is #%'],
    279 => ['SUBSIZE', 'Invalid number of subscripts: % provided, % required'],
    280 => ['ARRAY', 'Invalid array: %'],
    281 => ['NUMBER', 'Invalid number: %'],
    315 => ['SUBVERSION', 'Program trying to subvert natural order'],
    369 => ['NOTHREAD', 'Thread % does not exist'],
    398 => ['CONTEXT', 'Invalid context: %'],
    432 => ['READ', 'Not suitable for %'],
    433 => ['REGISTER', 'Not a valid register: %'],
    436 => ['HIDDEN', 'Register % stashed away too well'],
    437 => ['NOREGISTER', 'Cannot % numbers'],
    438 => ['ISNUMBER', 'Numbers cannot %'],
    444 => ['CONVERT', 'Cannot convert % to %'],
    445 => ['SWAP', 'Cannot swap % and %'],
    456 => ['SPLAT', 'No splat'],
    457 => ['INVSPLAT', 'Invalid splat %'],
    511 => ['INDEPENDENT', 'Register % does not belong to anything'],
    512 => ['NOBELONG', 'Register % does not belong to register %'],
    513 => ['NOSUCHBELONG', 'Register % does not belong to % registers (just %)'],
    514 => ['INVBELONG', 'Invalid belong number: %'],
    534 => ['DIGITS', 'Wrong number of digits for base %: %'],
    535 => ['SYMBOL', 'Invalid symbol: %'],
    555 => ['COMEFROM', 'Multiple "COME FROM" %'],
    578 => ['BCMATCH', 'Invalid bytecode pattern in %: %'],
    603 => ['CLASSWAR', 'Class war between % and %'],
    621 => ['NORESUME', 'Pointless RESUME'],
    632 => ['RESUME', 'Program terminated via RESUME'],
    633 => ['FALL_OFF', 'Falling off the edge of the program'],
    634 => ['INTERNAL', 'Internal error: %'],
    635 => ['UNDOCUMENTED', 'No such undocumented % as %'],
    636 => ['INVUNDOC', 'Invalid undocumented operation (%): %s'],
    641 => ['IOMODE', 'Invalid I/O mode %'],
    642 => ['IOERR', 'Input output error in %: %'],
    643 => ['SEEKERR', 'Seek/tell error: %'],
    644 => ['MODEERR', 'I/O error: %'],
    660 => ['NOSYSCALL', 'Undefined system call %'],
    661 => ['SYSCALL', 'Missing system call number'],
    662 => ['DIVIDE', 'Unary division by zero'],
    664 => ['INDIGESTION', 'Program is too large'],
    665 => ['HEADSPIN', 'Confused by your diversions, my head is spinning'],
    666 => ['QUANTUM', '% does not have a quantum version'],
    699 => ['LECTURE', 'Not in a lecture'],
    700 => ['LANGUAGE', 'Invalid language: %'],
    701 => ['NONUMBER', 'Value written in is not a number: %'],
    702 => ['THREESPOT', 'Value written in is larger than two spots'],
    703 => ['NODATA', 'End of file encountered when writing an array in'],
    742 => ['OSERR', '%'],
    751 => ['EVENT', 'Invalid event: BODY WHILE CONDITION'],
    752 => ['NOASSIGN', 'Cannot assign %: %'],
    774 => ['BUG', 'Compiler error'],
    775 => ['UBUG', 'Unexplainable compiler error'],
    796 => ['FORBIDDEN', '% is forbidden in INTERCAL-1972'],
    799 => ['HOLIDAY', 'No class teaches subjects %'],
    815 => ['EVOLUTION', 'Creation not allowed: %'],
    816 => ['CREATION', 'CREATE statement misconfiguration: %'],
    818 => ['CIRCULAR', 'Circular reasoning in %'],
    822 => ['NOSTUDENT', 'Register % is not a student'],
    823 => ['NOCURRICULUM', 'Subject % is not in %\'s curriculum'],
    899 => ['INTERNET', 'INTERcal NETwork error talking to %: %'],
    997 => ['ILLEGAL', 'Illegal operator % for base %'],
    998 => ['LATE', 'Too late to run this program'],
    999 => ['EARLY', 'Lecture at % is too early'],
);

sub SP_ARRAY () { 280 }
sub SP_ASSIGN () { 277 }
sub SP_BASE () { 8 }
sub SP_BCMATCH () { 578 }
sub SP_BUG () { 774 }
sub SP_CHARSET () { 10 }
sub SP_CIRCULAR () { 818 }
sub SP_CLASS () { 254 }
sub SP_CLASSWAR () { 603 }
sub SP_COMEFROM () { 555 }
sub SP_COMMENT () { 0 }
sub SP_CONTEXT () { 398 }
sub SP_CONVERT () { 444 }
sub SP_CREATION () { 816 }
sub SP_DIGITS () { 534 }
sub SP_DIVERSION () { 249 }
sub SP_DIVIDE () { 662 }
sub SP_EARLY () { 999 }
sub SP_EVENT () { 751 }
sub SP_EVOLUTION () { 815 }
sub SP_FALL_OFF () { 633 }
sub SP_FORBIDDEN () { 796 }
sub SP_HEADSPIN () { 665 }
sub SP_HIDDEN () { 436 }
sub SP_HOLIDAY () { 799 }
sub SP_ILLEGAL () { 997 }
sub SP_INDEPENDENT () { 511 }
sub SP_INDIGESTION () { 664 }
sub SP_INTERNAL () { 634 }
sub SP_INTERNET () { 899 }
sub SP_INVALID () { 69 }
sub SP_INVARRAY () { 251 }
sub SP_INVBELONG () { 514 }
sub SP_INVCLASS () { 253 }
sub SP_INVLABEL () { 131 }
sub SP_INVSPEC () { 6 }
sub SP_INVSPLAT () { 457 }
sub SP_INVUNDOC () { 636 }
sub SP_IOERR () { 642 }
sub SP_IOMODE () { 641 }
sub SP_IOTYPE () { 9 }
sub SP_ISARRAY () { 243 }
sub SP_ISCLASS () { 244 }
sub SP_ISNUMBER () { 438 }
sub SP_ISSPECIAL () { 248 }
sub SP_JUNK () { 128 }
sub SP_LANGUAGE () { 700 }
sub SP_LATE () { 998 }
sub SP_LECTURE () { 699 }
sub SP_MODEERR () { 644 }
sub SP_NEXTING () { 123 }
sub SP_NOARRAY () { 245 }
sub SP_NOASSIGN () { 752 }
sub SP_NOBELONG () { 512 }
sub SP_NOCLASS () { 250 }
sub SP_NOCURRICULUM () { 823 }
sub SP_NODATA () { 703 }
sub SP_NODIM () { 241 }
sub SP_NONUMBER () { 701 }
sub SP_NOREGISTER () { 437 }
sub SP_NORESUME () { 621 }
sub SP_NOSPECIAL () { 257 }
sub SP_NOSTUDENT () { 822 }
sub SP_NOSUCHBELONG () { 513 }
sub SP_NOSUCHCHAR () { 109 }
sub SP_NOSUCHLABEL () { 129 }
sub SP_NOSYSCALL () { 660 }
sub SP_NOTCLASS () { 242 }
sub SP_NOTHREAD () { 369 }
sub SP_NOVALUE () { 256 }
sub SP_NUMBER () { 281 }
sub SP_OSERR () { 742 }
sub SP_OVREG () { 252 }
sub SP_QUANTUM () { 666 }
sub SP_READ () { 432 }
sub SP_REGISTER () { 433 }
sub SP_REGNUM () { 70 }
sub SP_RESUME () { 632 }
sub SP_ROMAN () { 4 }
sub SP_SEEKERR () { 643 }
sub SP_SPECIAL () { 247 }
sub SP_SPLAT () { 456 }
sub SP_SPOT () { 5 }
sub SP_SPOTS () { 274 }
sub SP_SUBSCRIPT () { 276 }
sub SP_SUBSIZE () { 279 }
sub SP_SUBVERSION () { 315 }
sub SP_SWAP () { 445 }
sub SP_SYMBOL () { 535 }
sub SP_SYSCALL () { 661 }
sub SP_THREESPOT () { 702 }
sub SP_TODO () { 1 }
sub SP_TOOMANYLABS () { 130 }
sub SP_UBUG () { 775 }
sub SP_UNDOCUMENTED () { 635 }

# line 42

sub add_splat {
    @_ == 3 or croak "Usage: add_splat(NUMBER, NAME, MESSAGE)";
    my ($number, $name, $message) = @_;
    $name = uc($name);
    $number += 0;
    $number < 0 || $number > 999
	and croak "Invalid splat number: $number";
    exists $splats{$number}
	and croak "Duplicate splate number: $number";
    exists $splatbyname{$name}
	and croak "Duplicate splate name: $name";
    $splats{$number} = [$name, $message];
    $splatbyname{$name} = $number;
    push @EXPORT_OK, "SP_$name";
    no strict;
    *{"SP_$name"} = sub { $number };
}

sub faint {
    @_ >= 1 or croak "Usage: faint(NUM, ARGS)";
    die splatdescription(@_) . "\n";
}

sub splatnumber ($) {
    my $s = shift;
    exists $splatbyname{$s} ? $splatbyname{$s} : -1;
}

sub splatname ($) {
    my $s = shift;
    exists $splats{$s} ? $splats{$s}[0] : undef;
}

sub splatdescription {
    @_ >= 1 or croak "Usage: splatdescription(SPLAT, ARGS)";
    my $s = shift;
    $s %= 1000;
    return 'Unknown splat code' if ! exists $splats{$s};
    my $desc = $splats{$s}[1];
    $desc =~ s/%/shift || '?'/ge;
    $desc .= " (?" . join(' ', @_) . "?)" if @_;
    sprintf("*%03d %s", $s, $desc);
}

1;

__END__

=pod

=head1 NAME

Language::INTERCAL::Splats - errors

=head1 DESCRIPTION

Execution of I<CLC-INTERCAL> program can produce many errors, one of
the most common is attempting to execute a comment. Errors are
reported using a I<splat>, consisting of an error code and an error
message. The splat code is also available in the special expression
I<*> after the error occurred: this is only useful when the
program is multithreaded (another thread produced the splat) or
within events, as producing a splat is always fatal and causes the
program to terminate.

When printing a splat, the format will always be:

   *nnn message

where nnn is the splat code. See file blib/htmldoc/errors.html in
the distribution build directory (or the corresponding page in the
online reference manual) for a list of splat codes.

=head1 SEE ALSO

A qualified psychiatrist

=head1 AUTHOR

Claudio Calvelli - compiler (whirlpool) intercal.org.uk
(Please include the word INTERLEAVING in the subject when emailing that
address, or the email may be ignored)

