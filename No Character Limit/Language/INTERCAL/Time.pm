package Language::INTERCAL::Time;

# Convert current time to microseconds since 1970

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Time.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Time::HiRes;
use Math::BigInt try => 'GMP';
use Language::INTERCAL::Exporter '1.-94.-2';

@EXPORT_OK = qw(current_time);

# return current time in microseconds since 1970; we cannot assume that
# perl has been built with 64 bit integers, and we can't assume that a
# floating-point value has more than 53 bits of mantissa, leaving 33
# bits for the seconds (the microseconds take the remaining 20 bits).
# So...
sub current_time () {
    my ($seconds, $microseconds) = Time::HiRes::gettimeofday();
    Math::BigInt->new($seconds)->bmuladd(1000000, $microseconds);
}

1;
