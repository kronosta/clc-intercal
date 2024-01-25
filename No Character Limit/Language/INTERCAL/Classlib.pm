package Language::INTERCAL::Classlib;

# Optimised library routines for INTERCAL programs

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Classlib.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use POSIX qw(frexp signbit tan);
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_BASE SP_SPOTS);
use Language::INTERCAL::RegTypes '1.-94.-2.2', qw(REG_spot REG_twospot);

use constant PHI => .5 * (1 + sqrt(5));

my @limit16 = (0, 0, 65536, 59049, 65536, 15625, 46656, 16807);
my @limit32 = map { $_ * $_ } @limit16;
my @limit = (\@limit16, \@limit32);

sub _numlo {
    my ($r, $s, $base) = @_;
    my $l = $limit[$s ? 1 : 0][$base];
    if ($r < 0) {
	# we only have this in subtraction, so abs($r) will be < $l
	$r += $l;
    } elsif ($r >= $l) {
	$r %= $l;
    }
    ($r, $s ? REG_twospot : REG_spot);
}

sub _numck {
    my ($r, $s, $base) = @_;
    my $l = $limit[$s ? 1 : 0][$base];
    my $c;
    if ($r < 0) {
	# we only have this in subtraction, so abs($r) will be < $l
	$r += $l;
	$c = 2;
    } elsif ($r >= $l) {
	$r %= $l;
	$c = 2;
    } else {
	$c = 1;
    }
    ($r, $s ? REG_twospot : REG_spot, $c, REG_spot);
}

sub _num2 {
    my ($r, $s, $base) = @_;
    my $l = $limit[$s ? 1 : 0][$base];
    my $h;
    if ($r < 0) {
	# we only have this in subtraction, so abs($r) will be < $l
	$r += $l;
	$h = $l - 1;
    } elsif ($r >= $l) {
	$h = int($r / $l);
	$r -= $h * $l;
    } else {
	$h = 0;
    }
    $s ? ($r, REG_twospot, $h, REG_twospot)
       : ($r, REG_spot, $h, REG_spot);
}

sub _numerr {
    my ($r, $s, $base) = @_;
    $r >= $limit[$s ? 1 : 0][$base] || $r < 0
	and faint(SP_SPOTS, $r, $s ? 'two spots' : 'one spot');
    ($r, $s ? REG_twospot : REG_spot);
}

sub addlo {
    my ($a, $b, $s, $base) = @_;
    _numlo($a + $b, $s, $base);
}

sub addck {
    my ($a, $b, $s, $base) = @_;
    _numck($a + $b, $s, $base);
}

sub add2 {
    my ($a, $b, $s, $base) = @_;
    _num2($a + $b, $s, $base);
}

sub adderr {
    my ($a, $b, $s, $base) = @_;
    _numerr($a + $b, $s, $base);
}

sub sublo {
    my ($a, $b, $s, $base) = @_;
    _numlo($a - $b, $s, $base);
}

sub subck {
    my ($a, $b, $s, $base) = @_;
    _numck($a - $b, $s, $base);
}

sub sub2 {
    my ($a, $b, $s, $base) = @_;
    _num2($a - $b, $s, $base);
}

sub suberr {
    my ($a, $b, $s, $base) = @_;
    _numerr($a - $b, $s, $base);
}

# multiplication could require 64 bits if both operands are two-spot and
# large enough; this is not important in the other operations because perl
# will convert s "33-bit" number to double which has enough space, but
# double could have just 53 bits of mantissa which is not enough;
# we try to calculate the product without loss of precision even on 32
# bit processors where perl may be using 32 bit integers

sub _mul2 {
    my ($a, $b, $limit1, $limit2) = @_;
    $a == 0 || $b == 0 and return (0, 0);
    $a < $limit2 / $b and return (0, $a * $b);
    # maybe it still fits in a double
    if ($a <= 1e14 / $b) {
	$a *= $b;
	my $hi = int($a / $limit2);
	return ($hi, $a - $limit2 * $hi);
    }
    # a double will be big enough to contain the product of a 1-spot
    # by a 2-spot, so we split $a into two halves and do two separate
    # multiplications
    my $ah = int($a / $limit1);
    my $al = $a - $ah * $limit1;
    my $lo = $al * $b;
    my $hi = int($lo / $limit2);
    $lo -= $hi * $limit2;
    my $p = $ah * $b;
    my $d = int($p / $limit1);
    $p -= $d * $limit1;
    $lo += $p * $limit1;
    $hi += $d * $limit1;
    if ($lo >= $limit2) {
	$lo -= $limit2;
	$hi ++;
    }
    ($hi, $lo);
}

sub mullo {
    my ($a, $b, $s, $base) = @_;
    ((_mul2($a, $b, $limit[0][$base], $limit[$s ? 1 : 0][$base]))[1], $s ? REG_twospot : REG_spot);
}

sub mulck {
    my ($a, $b, $s, $base) = @_;
    my ($hi, $lo) = _mul2($a, $b, $limit[0][$base], $limit[$s ? 1 : 0][$base]);
    ($lo, $s ? REG_twospot : REG_spot, $hi ? 2 : 1, REG_spot);
}

sub mul2 {
    my ($a, $b, $s, $base) = @_;
    _num2($a * $b, $s, $base);
    my ($hi, $lo) = _mul2($a, $b, $limit[0][$base], $limit[$s ? 1 : 0][$base]);
    $s ? ($lo, REG_twospot, $hi, REG_twospot)
       : ($lo, REG_spot, $hi, REG_spot);
}

sub mulerr {
    my ($a, $b, $s, $base) = @_;
    _numerr($a * $b, $s, $base);
}

sub divlo {
    my ($a, $b, $s, $base) = @_;
    _numlo($b > 2 ? int($a / $b) : 0, $s, $base);
}

sub divck {
    my ($a, $b, $s, $base) = @_;
    _numck($b > 2 ? int($a / $b) : 0, $s, $base);
}

# unlike the other operations, this isn't a double-precision result, instead the
# first number returned is the result, and the second is the first fractional
# digit, which is also ($a * $base / $b) % $base
sub div2 {
    my ($a, $b, $s, $base) = @_;
    my ($r1, $r2);
    if ($b < 1) {
	$r1 = $r2 = 0;
    } else {
	$r1 = int($a * $base / $b);
	$r2 = $r1 % $base;
	$r1 = int($r1 / $base);
    }
    $s ? ($r1, REG_twospot, $r2, REG_twospot)
       : ($r1, REG_spot, $r2, REG_spot);
}

sub diverr {
    my ($a, $b, $s, $base) = @_;
    _numerr($b > 2 ? int($a / $b) : 0, $s, $base);
}

sub mod {
    my ($a, $b) = @_;
    (($b > 1) ? ($a % $b) : 0, REG_twospot);
}

sub base {
    my ($base, $bits) = @_;
    $bits & (1 << $base) or faint (SP_BASE, $base);
    ();
}

sub cat {
    my ($a, $b, $base) = @_;
    $a < 0 || $a >= $limit16[$base] and faint(SP_SPOTS, $a, 'one spot');
    $b < 0 || $b >= $limit16[$base] and faint(SP_SPOTS, $b, 'one spot');
    ($a * $limit16[$base] + $b, REG_twospot);
}

sub urand {
    (int(rand(65536)), REG_spot);
}

sub nrand {
    my ($a) = @_;
    my $res = rand($a / 12)
	    + rand(($a + 1) / 12)
	    + rand(($a + 2) / 12)
	    + rand(($a + 3) / 12)
	    + rand(($a + 4) / 12)
	    + rand(($a + 5) / 12)
	    + rand(($a + 6) / 12)
	    + rand(($a + 7) / 12)
	    + rand(($a + 8) / 12)
	    + rand(($a + 9) / 12)
	    + rand(($a + 10) / 12)
	    + rand(($a + 11) / 12);
    (int($res), REG_twospot);
}

# Convert a 32 bit floatlib value to a perl floating-point number;
# the value is (from most significant to least significant bits):
# sign bit: 0 = positive, 1 = negative
# 8-bit exponent: 0 is 2**-127 and 255 is 2**128, with the exception of the number zero itself
# 23-bit fraction
# The number 0 is represented as 0x00000000 or 0x80000000 depending on its sign
# Nonsero numbers are 2**(exponent-127)*(1.fraction)
sub _tofloat {
    my ($n) = @_;
    my $sign = $n & 0x80000000;
    my $exp = ($n >> 23) & 0xff;
    my $frac = $n & 0x7fffff;
    $exp == 0 && $frac == 0 and return $sign ? -0.0 : 0.0;
    my $val = (1 + $frac / 8388608.00) * 2 ** ($exp - 127);
    $sign ? -$val : $val;
}

# Convert a floating-point number to a 32-bit floatlib value together with an over/underflow marker
# see description before _tofloat();
sub _ck {
    my ($v, $underflow, $ok) = @_;
    my $sign = signbit($v) ? 0x80000000 : 0x00000000;
    $v == 0.0 and return ($sign, REG_twospot, 1, REG_spot);
    my ($mant, $exp) = frexp(abs $v);
    $exp += 126;
    $exp < 0 and return ($sign, REG_twospot, $underflow ? 2 : 1, REG_spot);
    $exp > 255 and return ($sign | 0x7fffffff, REG_twospot, $sign ? 2 : 3, REG_spot);
    my $frac = int(($mant * 2 - 1) * 8388608.00);
    defined $ok or $ok = 1;
    ($sign | ($exp << 23) | $frac, REG_twospot, $ok, REG_spot);
}

# same as _ck but just returns the value without a overflow/underflow indication
sub _ckv {
    my ($v) = @_;
    my $sign = signbit($v) ? 0x80000000 : 0x00000000;
    $v == 0.0 and return ($sign, REG_twospot);
    my ($mant, $exp) = frexp(abs $v);
    $exp += 126;
    $exp < 0 and return ($sign, REG_twospot);
    $exp > 255 and return ($sign | 0x7fffffff, REG_twospot);
    my $frac = int(($mant * 2 - 1) * 8388608.00);
    ($sign | ($exp << 23) | $frac, REG_twospot);
}

sub faddck {
    my ($a, $b) = @_;
    _ck(_tofloat($a) + _tofloat($b));
}

sub fsubck {
    my ($a, $b) = @_;
    _ck(_tofloat($a) - _tofloat($b));
}

sub fmulck {
    my ($a, $b) = @_;
    _ck(_tofloat($a) * _tofloat($b));
}

sub fdivck {
    my ($a, $b) = @_;
    ($b & 0x7fffffff) ? _ck(_tofloat($a) / _tofloat($b)) : (0, REG_twospot, 3, REG_spot);
}

sub fmodck {
    my ($a, $b) = @_;
    ($b & 0x7fffffff) or return (0, REG_twospot, 0, REG_spot);
    $a = _tofloat($a);
    $b = _tofloat($b);
    my $d = int($a / $b);
    _ck($a - $d * $b);
}

sub fintfrac {
    my ($a) = @_;
    $a = _tofloat($a);
    my $i = int($a);
    my $f = $a - $i;
    (_ckv($i), _ckv($f));
}

sub ffromi {
    my ($a) = @_;
    _ckv($a < 0x80000000 ? $a : $a - 65536 * 65536);
}

sub ftoi {
    my ($a) = @_;
    $a = _tofloat($a);
    $a < -32768 * 65536 and return (0x80000000, REG_twospot, 3, REG_spot);
    $a >= 32768 * 65536 and return (0x7fffffff, REG_twospot, 3, REG_spot);
    $a >= 0 and return ($a, REG_twospot, 1, REG_spot);
    ($a + 65536 * 65536, REG_twospot, 2, REG_spot);
}

sub ffromd {
    my ($a) = @_;
    $a >= 2000000000 || $a < 0 and return (0, REG_twospot, 3, REG_spot);
    my $exp = $a % 100;
    $a = int($a / 100);
    if ($a < 10000000) {
	$a < 1000000 and $a = ('0' x (7 - length($a))) . $a;
	substr($a, 1, 0) = '.';
    } else {
	substr($a, 0, 1) = '-';
	substr($a, 2, 0) = '.';
    }
    $exp >= 50 and $exp = 50 - $exp;
    $a .= "e$exp";
    _ck($a);
}

sub ftod {
    my ($a) = @_;
    $a = _tofloat($a);
    my $sign = 0;
    $a < 0 and ($sign, $a) = (1000000000, -$a);
    $a == 0.0 and return ($sign, REG_twospot);
    # oh yes we cheat
    sprintf("%.6e", $a) =~ /^(\d)\.(\d+)e([-+]?\d+)$/
	or die "Cannot parse number $a?\n";
    my $mant = "$1$2";
    my $exp = $3;
    $exp < 0 and $exp = 50 - $exp;
    ($mant * 100 + $sign + $exp, REG_twospot);
}

sub fsqrt {
    my ($a) = @_;
    $a = _tofloat($a);
    $a < 0 and return (0, REG_twospot, 3, REG_spot);
    _ck(sqrt($a));
}

sub fln {
    my ($a) = @_;
    $a = _tofloat($a);
    # floatlib.i always returns 3.02925436e-13 for the logarithm
    # of a negative number; we don't know why but we do the same
    $a < 0 and return (715819048, REG_twospot, 3, REG_spot);
    _ck(log($a));
}

sub fexp {
    my ($a) = @_;
    _ck(exp(_tofloat($a)), 1);
}

sub fpow {
    my ($a, $b) = @_;
    $b = _tofloat($b);
    _ck(_tofloat($a) ** $b, 0, $b < -1 ? 0 : 1);
}

sub fsin {
    my ($a) = @_;
    _ckv(sin(_tofloat($a)));
}

sub fcos {
    my ($a) = @_;
    _ckv(cos(_tofloat($a)));
}

sub ftan {
    my ($a) = @_;
    _ck(tan(_tofloat($a)), 1);
}

sub frand {
    _ckv(rand(1));
}

sub fmulphi {
    my ($a) = @_;
    _ck(_tofloat($a) * PHI);
}

sub fdivphi {
    my ($a) = @_;
    _ck(_tofloat($a) / PHI);
}

1
