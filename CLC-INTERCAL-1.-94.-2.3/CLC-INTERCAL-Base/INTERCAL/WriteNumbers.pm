package Language::INTERCAL::WriteNumbers;

# Write in numbers

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/WriteNumbers.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_LANGUAGE SP_NONUMBER SP_THREESPOT);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(write_language write_number);

my %write_language = (
    'English' => {
	'OH'          => 0,
	'ZERO'        => 0,
	'ONE'         => 1,
	'TWO'         => 2,
	'THREE'       => 3,
	'FOUR'        => 4,
	'FIVE'        => 5,
	'SIX'         => 6,
	'SEVEN'       => 7,
	'EIGHT'       => 8,
	'NINE'        => 9,
	'NINER'       => 9,
    },
    'Scottish Gaelic' => {
	# Write to the Lunatic if you wonder how these are pronounced, or why
	# there are so many different forms.
	'NONI'        => 0,
	'NEONI'       => 0,
	'AON'         => 1,
	'A H-AON'     => 1,
	'AONAR'       => 1,
	'DA'          => 2,
	'DHA'         => 2,
	'A DHA'       => 2,
	'DITHIS'      => 2,
	'TRI'         => 3,
	'A TRI'       => 3,
	'TRIUIR'      => 3,
	'CEITHIR'     => 4,
	'A CEITHIR'   => 4,
	'CEATHRAR'    => 4,
	'COIG'        => 5,
	'A COIG'      => 5,
	'C\`OIG'      => 5,
	'A C\`OIG'    => 5,
	'CÒIG'        => 5,
	'A CÒIG'      => 5,
	'COIGNEAR'    => 5,
	'C\`OIGNEAR'  => 5,
	'CÒIGNEAR'    => 5,
	'SIA'         => 6,
	'SE'          => 6,
	'A SIA'       => 6,
	'A SE'        => 6,
	'SEANAR'      => 6,
	'SEACHD'      => 7,
	'A SEACHD'    => 7,
	'SEACHDNAR'   => 7,
	'OCHD'        => 8,
	'A H-OCHD'    => 8,
	'OCHDNAR'     => 8,
	'NAOI'        => 9,
	'A NAOI'      => 9,
	'NAONAR'      => 9,
    },
    'Sanskrit' => {
	'SUTYA'       => 0,
	'SHUTYA'      => 0,
	'EKA'         => 1,
	'DVI'         => 2,
	'TRI'         => 3,
	'CHATUR'      => 4,
	'PANCHAN'     => 5,
	'SHASH'       => 6,
	'SAPTAM'      => 7,
	'ASHTAN'      => 8,
	'NAVAN'       => 9,
    },
    'Basque' => {
	'ZEROA'       => 0,
	'BAT'         => 1,
	'BI'          => 2,
	'HIRO'        => 3,
	'LAU'         => 4,
	'BORTZ'       => 5,
	'SEI'         => 6,
	'ZAZPI'       => 7,
	'ZORTZI'      => 8,
	'BEDERATZI'   => 9,
    },
    'Tagalog' => {
	'WALA'        => 0,
	'ISA'         => 1,
	'DALAWA'      => 2,
	'TATLO'       => 3,
	'APAT'        => 4,
	'LIMA'        => 5,
	'ANIM'        => 6,
	'PITO'        => 7,
	'WALO'        => 8,
	'SIYAM'       => 9,
    },
    'Classical Nahuatl' => {
	'AHTLE'       => 0,
	'CE'          => 1,
	'OME'         => 2,
	'IEI'         => 3,
	'NAUI'        => 4,
	'NACUILI'     => 5,
	'CHIQUACE'    => 6,
	'CHICOME'     => 7,
	'CHICUE'      => 8,
	'CHICUNAUI'   => 9,
    },
    'Georgian' => {
	'NULI'        => 0,
	'ERTI'        => 1,
	'ORI'         => 2,
	'SAMI'        => 3,
	'OTXI'        => 4,
	'XUTI'        => 5,
	'EKSVI'       => 6,
	'SHVIDI'      => 7,
	'RVA'         => 8,
	'CXRA'        => 9,
    },
    'Kwakiutl' => { # (technically, Kwak'wala)
	"KE'YOS"      => 0,
	"'NEM"        => 1,
	"MAL'H"       => 2,
	"YUDEXW"      => 3,
	"MU"          => 4,
	"SEK'A"       => 5,
	"Q'ETL'A"     => 6,
	"ETLEBU"      => 7,
	"MALHGWENALH" => 8,
	"'NA'NE'MA"   => 9,
    },
    'Volap\"uk' => {
	'NOS'         => 0,
	'BAL'         => 1,
	'TEL'         => 2,
	'KIL'         => 3,
	'FOL'         => 4,
	'LUL'         => 5,
	'M\\"AL'      => 6,
	'MÄL'         => 6,
	'VEL'         => 7,
	'J\\"OL'      => 8,
	'JÖL'         => 8,
	'Z\\"UL'      => 9,
	'ZÜL'         => 9,
    },
    'Latin' => {
	"NIHIL"       => 0,
	"NIL"         => 0,
	"UNUS"        => 1,
	"UNA"         => 1,
	"UNUM"        => 1,
	"DUO"         => 2,
	"DUAE"        => 2,
	"DUÆ"         => 2,
	"DU\\AE"      => 2,
	"TRES"        => 3,
	"QUATTUOR"    => 4,
	"QUINQUE"     => 5,
	"SEX"         => 6,
	"SEPTEM"      => 7,
	"OCTO"        => 8,
	"NOVEM"       => 9,
    },
);

my %write_number = map { %$_ } values %write_language;

sub write_language {
    @_ <= 2 or croak "Usage: write_language([LANGUAGE [, TEXT]])";
    return keys %write_language if @_ == 0;
    my $language = shift;
    exists $write_language{$language} or faint(SP_LANGUAGE, $language);
    my $wl = $write_language{$language};
    return keys %$wl if @_ == 0;
    my $text = shift;
    exists $wl->{$text} or faint(SP_NONUMBER, $text);
    return $wl->{$text};
}

my $regex = '\\s*('
	  . join('|', map {quotemeta($_)}
			  sort {length($b) <=> length($a) || $a cmp $b}
			       keys %write_number)
	  . ')';
$regex =~ s/\\? /\\s*/g;
$regex = qr/^$regex/i;

sub write_number {
    @_ == 2 or croak "Usage: write_number(FILEHANDLE, WIMP?)";
    my ($fh, $wimp) = @_;
    my $line = $fh->write_text();
    faint(SP_NONUMBER, "(end of file)") if ! defined $line || $line eq '';
    my $val = 0;
    if ($wimp) {
	$line =~ s/\s+//g;
	faint(SP_NONUMBER, $line) if $line =~ /\D/;
	$val = $line;
    } else {
	while ($line =~ s/$regex//) {
	    my $digit = $write_number{uc($1)};
	    faint(SP_THREESPOT)
		if $val > 429496729 || ($val == 429496729 && $digit > 5);
	    $val *= 10;
	    $val += $digit;
	}
	faint(SP_NONUMBER, $line) if $line =~ /\S/;
    }
    $val;
}

1;
