package Language::INTERCAL::ArrayIO;

# Write/read arrays

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/ArrayIO.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2.2', qw(faint SP_IOTYPE SP_FORBIDDEN SP_NODIM SP_NODATA);
use Language::INTERCAL::Charset::Baudot '1.-94.-2',
	qw(baudot2ascii ascii2baudot);
use vars qw(@EXPORT_OK %EXPORT_TAGS);
@EXPORT_OK = qw(iotype_default iotype iotype_name
		write_array_16 read_array_16
		write_array_32 read_array_32);
%EXPORT_TAGS = ();

my @iotypes;
my %iotypes;

BEGIN {
    @iotypes = (
	[CLC  => \&_ra_clc_16,  \&_ra_clc_32,  \&_wa_clc_16,  \&_wa_clc_32],
	[C    => \&_ra_c,       \&_ra_c,       \&_wa_c,       \&_wa_c],
	[1972 => \&_no_io,      \&_no_io,      \&_no_io,      \&_no_io],
    );
    %iotypes = map { ($iotypes[$_ - 1][0] => $_) } (1..@iotypes);
}

use constant iotype_default => $iotypes{CLC};

sub iotype {
    @_ == 1 or croak "Usage: iotype(IOTYPE)";
    my ($iotype) = @_;
    $iotype =~ s/\s+//g;
    if ($iotype =~ /^\d+$/ && $iotype != 1972) {
	return iotype_default if $iotype == 0;
	return undef if $iotype < 1 || $iotype > @iotypes;
	return $iotype;
    } else {
	$iotype = uc($iotype);
	return undef if ! exists $iotypes{$iotype};
	return $iotypes{$iotype};
    }
}

sub iotype_name {
    @_ == 1 or croak "Usage: iotype_name(IOTYPE)";
    my ($iotype) = @_;
    $iotype = iotype_default if $iotype < 1;
    return undef if $iotype < 1 || $iotype > @iotypes;
    return $iotypes[$iotype - 1][0];
}

sub read_array_16 {
    @_ == 5 or croak
	'Usage: read_array_16(IOTYPE, \$IOVALUE, FILEHANDLE, \@VALUES, NL';
    my ($iotype, $iovalue, $fh, $values, $nl) = @_;
    my $iocode = iotype($iotype) or faint(SP_IOTYPE, $iotype);
    &{$iotypes[$iocode - 1][1]}($iovalue, $values, $fh, $nl);
}

sub read_array_32 {
    @_ == 5 or croak
	'Usage: read_array_32(IOTYPE, \$IOVALUE, FILEHANDLE, \@VALUES, NL';
    my ($iotype, $iovalue, $fh, $values, $nl) = @_;
    my $iocode = iotype($iotype) or faint(SP_IOTYPE, $iotype);
    &{$iotypes[$iocode - 1][2]}($iovalue, $values, $fh, $nl);
}

sub _no_io {
    faint(SP_FORBIDDEN, 'Array I/O');
}

sub _ra_c {
    my ($iovalue, $values, $fh, $nl) = @_;
    my $tape_pos = $$iovalue;
    my @v = ();
    for my $value (@$values) {
	$tape_pos = ($tape_pos + 256 - ($value & 0xff)) & 0xff;
	my $v = $tape_pos;
	$v = (($v & 0x0f) << 4) | (($v & 0xf0) >> 4);
	$v = (($v & 0x33) << 2) | (($v & 0xcc) >> 2);
	$v = (($v & 0x55) << 1) | (($v & 0xaa) >> 1);
	push @v, $v;
    }
    $$iovalue = $tape_pos;
    $fh->read_binary(pack("C*", @v));
}

sub _ra_clc_16 {
    my ($iovalue, $values, $fh, $nl) = @_;
    my $value = pack("C*", grep { $_ > 0 } @$values);
    $fh->read_text(baudot2ascii($value) . ($nl ? "\n" : ''));
}

sub _ra_clc_32 {
    my ($iovalue, $values, $fh, $nl) = @_;
    my $line = '';
    my $io = 172;
    for my $value (@$values) {
	next if ! $value;
	my $val0 = $value;
	my $bits0 = 0;
	my $bits1 = 0;
	my $i;
	for ($i = 0; $i < 8; $i++) {
	    $bits0 >>= 1;
	    $bits1 >>= 1;
	    $bits0 |= 0x80 if $val0 & 2;
	    $bits1 |= 0x80 if $val0 & 1;
	    $val0 >>= 2;
	}
	$val0 = 0;
	for ($i = 0; $i < 8; $i++) {
	    $val0 >>= 1;
	    if ($io & 1) {
		$val0 |= 0x80 if $bits0 & 1;
		$bits0 >>= 1;
	    } else {
		$val0 |= 0x80 if ! ($bits1 & 1);
		$bits1 >>= 1;
	    }
	    $io >>= 1;
	}
	$line .= chr($val0);
	$io = $val0;
    }
    $fh->read_binary($line);
}

sub write_array_16 {
    @_ == 4
	or croak 'Usage: write_array_16(IOTYPE, \$IOVALUE, FILEHANDLE, SIZE';
    my ($iotype, $iovalue, $fh, $size) = @_;
    my $iocode = iotype($iotype) or faint(SP_IOTYPE, $iotype);
    &{$iotypes[$iocode - 1][3]}($iovalue, $fh, $size);
}

sub write_array_32 {
    @_ == 4
	or croak 'Usage: write_array_32(IOTYPE, \$IOVALUE, FILEHANDLE, SIZE';
    my ($iotype, $iovalue, $fh, $size) = @_;
    my $iocode = iotype($iotype) or faint(SP_IOTYPE, $iotype);
    &{$iotypes[$iocode - 1][4]}($iovalue, $fh, $size);
}

sub _wa_c {
    my ($iovalue, $fh, $size) = @_;
    my $line = $fh->write_binary($size);
    defined $line && $line ne '' or return ();
    my @values = unpack("C*", $line);
    my $tape_pos = $$iovalue;
    for my $chr (@values) {
	my $c = $chr;
	$chr = (256 + $chr - $tape_pos) & 0xff;
	$tape_pos = $c;
    }
    push @values, 256 while @values < $size;
    $$iovalue = $tape_pos;
    @values;
}

sub _wa_clc_16 {
    my ($iovalue, $fh, $size) = @_;
    my $line = $fh->write_text();
    defined $line && $line ne '' or return ();
    chomp $line;
    $line = ascii2baudot($line);
    unpack("C*", $line);
}

sub _wa_clc_32 {
    my ($iovalue, $fh, $size) = @_;
    $size > 0 or faint(SP_NODIM);
    my $line = $fh->write_binary($size);
    defined $line and $line ne '' or faint(SP_NODATA);
    my @values = unpack("C*", $line);
    my $io = 172;
    for my $datum (@values) {
	my $chr = $datum;
	my $chr0 = $chr;
	my $bits0 = 0;
	my $bits1 = 0;
	for (my $i = 0; $i < 8; $i++) {
	    if ($io & 0x80) {
		$bits0 <<= 1;
		$bits0 |= 1 if $chr & 0x80;
	    } else {
		$bits1 <<= 1;
		$bits1 |= 1 if ! ($chr & 0x80);
	    }
	    $chr <<= 1;
	    $io <<= 1;
	}
	$chr = int(rand 0xffff) + 1;
	for (my $i = 0; $i < 8; $i++) {
	    $chr <<= 2;
	    $chr |= 2 if $bits0 & 0x80;
	    $chr |= 1 if $bits1 & 0x80;
	    $bits0 <<= 1;
	    $bits1 <<= 1;
	}
	$datum = $chr;
	$io = $chr0;
    }
    @values;
}

1;
