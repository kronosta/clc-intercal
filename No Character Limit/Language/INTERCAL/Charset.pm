package Language::INTERCAL::Charset;

# Character sets

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Charset.pm 1.-94.-2.1") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use vars qw(@EXPORT_OK $seen_utf8);
@EXPORT_OK = qw(fromascii toascii charset charset_default charset_name $seen_utf8);

my @charsets;
my %charsets;
my $default;

BEGIN {
    $default = 'ASCII';
    @charsets = ( [$default, \&_toascii, sub { shift }] );
    %charsets = ( $default => scalar(@charsets) );
}

use constant charset_default => $charsets{$default};

sub _find {
    my ($how, $charset, $hack) = @_;
    $charset =~ s/\s+//g;
    if ($charset =~ /^\d+$/) {
	$charset = charset_default if $charset == 0;
	return undef if $charset < 1 || $charset > @charsets;
    } else {
	if (! exists $charsets{$charset}) {
	    eval "require Language::INTERCAL::Charset::$charset";
	    return undef if $@;
	    my ($to, $from);
	    eval {
		no strict 'refs';
		$to = \&{"Language::INTERCAL::Charset::${charset}::\L${charset}\E2ascii"};
		&$to('');
		$from = \&{"Language::INTERCAL::Charset::${charset}::ascii2\L${charset}\E"};
		&$from('');
	    };
	    return undef if $@;
	    push @charsets, [$charset, $to, $from];
	    $charsets{$charset} = @charsets;
	}
	$charset = $charsets{$charset};
    }
    $how and return $charset;
    $charset--;
    $charset == 0 or return $charsets[$charset];
    $hack or return $charsets[$charset];
    return [
	$charsets[0][0],
	sub { _toascii_check_utf8($_[0], $hack) },
	sub { _fromascii_check_utf8($_[0], $hack) },
    ];
}

# We use only three characters from the non-ASCII latin1 set: ¢ (0xa2),
# ¥ (0xa5) and ¬ (0xac); these are all represented in utf8 by a sequence
# 0xc2 followed by that byte, and in latin1 as just that byte; so we
# check for any "hint" of utf8 by looking for 0xc2 followed by something
# between 0x80 and 0xbf: all these are utf8 encodings for what latin1
# represents as just the second byte, and we take that as evidence that
# the input is utf8; moreover, since we are in "silly hack" mode, we
# remember we've seen that and alter the conversion back from ASCII
# in future: this is sufficient to compile programs encoded in either
# latin1 or utf8, to produce program listings in the same encoding as
# the input, and to make the calculator work identically in both
# environments. It this weren't INTERCAL we'd probably do a proper UTF8
# conversion instead.
sub _toascii_check_utf8 {
    my ($a, $record) = @_;
    ($a =~ s/\xc2([\x80-\xbf])/$1/g) and $$record = 1;
    $a;
}

sub _fromascii_check_utf8 {
    my ($a, $record) = @_;
    $$record and ($a =~ s/([\x80-\xbf])/\xc2$1/g);
    $a;
}

sub _toascii {
    my ($a) = @_;
    $a =~ s/\xc2([\x80-\xbf])/$1/g;
    $a;
}

sub charset {
    @_ == 1 or croak "Usage: charset(CHARSET)";
    _find(1, @_);
}

sub charset_name {
    @_ == 1 or croak "Usage: charset_name(CHARSET)";
    my $charset = _find(0, @_);
    defined $charset ? $charset->[0] : undef;
}

sub toascii {
    @_ == 1 || @_ == 2 or croak "Usage: toascii(CHARSET [, UTF8_HACK])";
    my $charset = _find(0, @_);
    defined $charset ? $charset->[1] : undef;
}

sub fromascii {
    @_ == 1 || @_ == 2 or croak "Usage: fromascii(CHARSET [, UTF8_HACK])";
    my $charset = _find(0, @_);
    defined $charset ? $charset->[2] : undef;
}

1;
