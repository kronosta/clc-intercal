package Language::INTERCAL::GenericIO;

# Write/read data

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/GenericIO.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use IO::File;
use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::Charset '1.-94.-2.1', qw(toascii fromascii charset);
use Language::INTERCAL::Splats '1.-94.-2.1', qw(faint SP_IOMODE SP_SEEKERR SP_MODEERR);

use vars qw(@EXPORT_OK @EXPORT_TAGS
	    $stdread $stdwrite $stdsplat $devnull);
@EXPORT_OK = qw($stdread $stdwrite $stdsplat $devnull);
@EXPORT_TAGS = (files => [qw($stdread $stdwrite $stdsplat $devnull)]);

# Specific GenericIO modules could "require" or even "use" this
# so protect the next four lines from being called while in
# the process of loading GenericIO::FILE of GenericIO::TEE
require Language::INTERCAL::GenericIO::FILE;
require Language::INTERCAL::GenericIO::TEE;
defined $stdread or $stdread = new Language::INTERCAL::GenericIO('FILE', 'r', '-');
defined $stdwrite or $stdwrite = new Language::INTERCAL::GenericIO('FILE', 'w', '-');
defined $stdsplat or $stdsplat = new Language::INTERCAL::GenericIO('FILE', 'r', '-2');
defined $devnull or $devnull = new Language::INTERCAL::GenericIO('TEE', 'r', []);

sub new {
    @_ >= 3
	or croak "Usage: new Language::INTERCAL::GenericIO(TYPE, MODE, DATA)";
    my ($class, $type, $mode, @data) = @_;
    if ($mode =~ /^\d+$/) {
	$mode = chr($mode & 0xff) . ($mode & 0x100 ? '+' : '');
    }
    $mode =~ /^[rwau]\+?$/ or faint(SP_IOMODE, $mode);
    $type = uc($type);
    my $module = "Language::INTERCAL::GenericIO::$type";
    eval "use $module";
    die $@ if $@;
    my $fh = bless {
	type => $type,
	mode => $mode,
	data => \@data,
	read_convert => fromascii(1),
	read_charset => 'ASCII',
	write_convert => toascii(1),
	write_unconvert => fromascii(1),
	write_charset => 'ASCII',
	text_newline => "\n",
	exported => 0,
	buffer => '',
    }, $module;
    $fh->_new($mode, @data);
    $fh;
}

sub set_utf8_hack {
    @_ == 2 or croak 'Usage: IO->set_utf8_hack(\$VARIABLE)';
    my ($fh, $hack) = @_;
    $fh->{write_convert} = toascii(1, $hack);
    $fh->{read_convert} = fromascii(1, $hack);
    $fh->{utf8_hack} = $hack;
    $fh;
}

# methods which subclasses must override
sub tell { faint(SP_SEEKERR, "Not seekable"); }
sub reset { faint(SP_SEEKERR, "Not seekable"); }
sub seek { faint(SP_SEEKERR, "Not seekable"); }
sub read_binary { faint(SP_MODEERR, "Not readable"); }
sub _write_code { faint(SP_MODEERR, "Not writable"); }
sub _write_text_code { faint(SP_MODEERR, "Not writable"); }

sub describe {
    @_ == 1 or croak "Usage: IO->describe";
    # subclasses will override this if required
    my ($object) = @_;
    my $type = $object->{type};
    my $mode = $object->{mode};
    my $data = $object->{data};
    return "$type($mode, $data)";
}

# method implementing filehandle text READ OUT operations

sub read_text {
    @_ == 2 or croak "Usage: IO->read_text(DATA)";
    my ($fh, $string) = @_;
    faint(SP_MODEERR, "Not set up for text reading")
	if ! exists $fh->{read_convert};
    $string = &{$fh->{read_convert}}($string);
    $fh->read_binary($string);
}

sub read_charset {
    @_ == 1 || @_ == 2 or croak "Usage: IO->read_charset [(CHARSET)]";
    my $fh = shift;
    my $oc = $fh->{read_charset};
    if (@_) {
	my $charset = shift;
	$fh->{read_charset} = $charset;
	$fh->{read_convert} = fromascii($charset, $fh->{utf8_hack});
    }
    $oc;
}

sub read_convert {
    @_ == 1 or croak "Usage: IO->read_convert";
    my ($fh) = @_;
    $fh->{read_convert};
}

# method implementing filehandle WRITE IN operations

sub write_binary {
    @_ == 2 or croak "Usage: IO->write_binary(SIZE)";
    my ($fh, $size) = @_;
    if (length($fh->{buffer}) >= $size) {
	return substr($fh->{buffer}, 0, $size, '');
    }
    my $data = '';
    if ($fh->{buffer} ne '') {
	$data = $fh->{buffer};
	$fh->{buffer} = '';
    }
    my $add = $fh->_write_code($size - length($data));
    defined $add ? ($data . $add) : $data;
}

sub write_text {
    @_ == 1 or @_ == 2 or croak "Usage: IO->write_text [(NEWLINE)]";
    my ($fh, $newline) = @_;
    if (defined $newline) {
	if ($newline ne '') {
	    eval { $newline = $fh->{write_unconvert}->($newline) };
	    $newline = "\n" if $@;
	}
    } else {
	$newline = $fh->{text_newline};
    }
    if ($newline eq '') {
	my $line = $fh->{buffer};
	$fh->{buffer} = '';
	while (1) {
	    my $data = $fh->_write_code(1024);
	    last if ! defined $data || $data eq '';
	    $line .= $data;
	}
	return &{$fh->{write_convert}}($line);
    }
    my $nlpos = index $fh->{buffer}, $newline;
    if ($nlpos >= 0) {
	$nlpos += length($newline);
	my $line = substr($fh->{buffer}, 0, $nlpos, '');
	return &{$fh->{write_convert}}($line);
    }
    my $line = $fh->_write_text_code($newline);
    $line = defined $line ? ($fh->{buffer} . $line) : $fh->{buffer};
    $fh->{buffer} = '';
    return &{$fh->{write_convert}}($line);
}

sub write_charset {
    @_ == 1 || @_ == 2 or croak "Usage: IO->write_charset [(CHARSET)]";
    my $fh = shift;
    my $oc = $fh->{write_charset};
    if (@_) {
	my $charset = shift;
	$fh->{write_charset} = $charset;
	$fh->{write_convert} = toascii($charset, $fh->{utf8_hack});
	$fh->{write_unconvert} = fromascii($charset);
	eval { $fh->{text_newline} = $fh->{write_unconvert}->("\n") };
	$fh->{text_newline} = "\n" if $@;
    }
    $oc;
}

sub write_convert {
    @_ == 1 or croak "Usage: IO->write_convert";
    my ($fh) = @_;
    $fh->{write_convert};
}

sub mode {
    @_ == 1 or croak "Usage: IO->mode";
    my ($fh) = @_;
    $fh->{mode};
}

1;
