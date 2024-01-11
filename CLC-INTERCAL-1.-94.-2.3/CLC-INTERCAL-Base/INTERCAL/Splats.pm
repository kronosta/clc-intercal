package Language::INTERCAL::Splats;

# Splats and error messages

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

@@DATA Splats@@

use strict;
use vars qw($VERSION $PERVERSION $DATAVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Splats.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-3', qw(import compare_version);
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension);
use vars qw(@EXPORT_OK);

$DATAVERSION = '@@VERSION@@';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

@EXPORT_OK = qw(
    splatnumber splatname splatdescription faint add_splat
    @@FILL SPLATS 'SP_' NAME '' 76 ' '@@
);

my %splatbyname = (
    @@ALL SPLATS NAME@@ => @@NUMBER@@,
);

my %splats = (
    @@ALL SPLATS NUMBER@@ => ['@@NAME@@', '@@'DESCR'@@'],
);

sub SP_@@ALL SPLATS NAME@@ () { @@NUMBER@@ }

# line @@LINE@@

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

