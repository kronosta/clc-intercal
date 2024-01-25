package Language::INTERCAL::Numbers;

# Calculations

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Numbers.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::Splats '1.-94.-2.2',
    qw(faint SP_BASE SP_DIGITS SP_DIVIDE SP_ISARRAY SP_ISCLASS SP_ISSPECIAL SP_ASSIGN SP_INVALID);
use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_whp REG_dos REG_shf);

use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(
    n_interleave n_select n_swb n_awc n_but n_bitdiv n_arithdiv
    n_uninterleave n_unselect n_unswb n_unawc n_unbut n_unbitdiv n_unarithdiv
);

# if we need to splat on an invalid value we call this
sub _invalid {
    my ($type) = @_;
    $type == REG_tail || $type == REG_hybrid and faint(SP_ISARRAY);
    $type == REG_whp and faint(SP_ISCLASS);
    $type == REG_dos || $type ==REG_shf and faint(SP_ISSPECIAL);
    faint(SP_INVALID, $type, 'data type');
}

my @twospotbits = (0, 0, 32, 20, 16, 12, 12, 10);
my @spotbits = (0, 0, 16, 10, 8, 6, 6, 5);
my @bits = (0, \@spotbits, \@twospotbits);

sub _from_digits {
    my ($base, @values) = @_;
    my $value = 0;
    for my $n (@values) {
	$value = $value * $base + $n;
    }
    $value;
}

sub _digits {
    my ($num, $spots, $base) = @_;
    my $bits = $bits[$spots][$base];
    my $orig = $num;
    my $value = $orig;
    my @result = ();
    for (my $n = 0; $n < $bits; $n++) {
	unshift @result, $value % $base;
	$value = int($value / $base);
    }
    $value and faint(SP_DIGITS, $base, $orig);
    @result;
}

sub n_interleave ($$$) {
    my ($n1, $n2, $base) = @_;
    my $n;
    if ($base == 2) {
	$n1 > 0xffff and faint(SP_DIGITS, $base, $n1);
	$n2 > 0xffff and faint(SP_DIGITS, $base, $n2);
	#                                                               0000000000000000abcdefghjklmnpqr
	$n1 =  (($n1 & 0x000000ff) << 1) | (($n1 & 0x0000ff00) << 9); # 0000000abcdefgh00000000jklmnpqr0
	$n1 =   ($n1 & 0x001e001e)       | (($n1 & 0x01e001e0) << 4); # 000abcd0000efgh0000jklm0000npqr0
	$n1 =   ($n1 & 0x06060606)       | (($n1 & 0x18181818) << 2); # 0ab00cd00ef00gh00jk00lm00np00qr0
	$n1 =   ($n1 & 0x22222222)       | (($n1 & 0x44444444) << 1); # a0b0c0d0e0f0g0h0j0k0l0m0n0p0q0r0
	#                                                               0000000000000000abcdefghjklmnpqr
	$n2 =   ($n2 & 0x000000ff)       | (($n2 & 0x0000ff00) << 8); # 00000000abcdefgh00000000jklmnpqr
	$n2 =   ($n2 & 0x000f000f)       | (($n2 & 0x00f000f0) << 4); # 0000abcd0000efgh0000jklm0000npqr
	$n2 =   ($n2 & 0x03030303)       | (($n2 & 0x0c0c0c0c) << 2); # 00ab00cd00ef00gh00jk00lm00np00qr
	$n2 =   ($n2 & 0x11111111)       | (($n2 & 0x22222222) << 1); # 0a0b0c0d0e0f0g0h0j0k0l0m0n0p0q0r
	$n = $n1 | $n2;
    } elsif ($base == 4) {
	$n1 > 0xffff and faint(SP_DIGITS, $base, $n1);
	$n2 > 0xffff and faint(SP_DIGITS, $base, $n2);
	#                                                                00000000abcdefgh
	$n1 =  (($n1 & 0x000000ff) << 2) | (($n1 & 0x0000ff00) << 10); # 000abcd0000efgh0
	$n1 =   ($n1 & 0x003c003c)       | (($n1 & 0x03c003c0) << 4);  # 0ab00cd00ef00gh0
	$n1 =   ($n1 & 0x0c0c0c0c)       | (($n1 & 0x30303030) << 2);  # a0b0c0d0e0f0g0h0
	#                                                                00000000abcdefgh
	$n2 =   ($n2 & 0x000000ff)       | (($n2 & 0x0000ff00) << 8);  # 0000abcd0000efgh
	$n2 =   ($n2 & 0x000f000f)       | (($n2 & 0x00f000f0) << 4);  # 00ab00cd00ef00gh
	$n2 =   ($n2 & 0x03030303)       | (($n2 & 0x0c0c0c0c) << 2);  # 0a0b0c0d0e0f0g0h
	$n = $n1 | $n2;
    } else {
	my $bits = $spotbits[$base];
	my ($orig1, $orig2) = ($n1, $n2);
	$n = 0;
	my $mul = 1;
	for (my $b = 0; $b < $bits && ($n1 || $n2); $b++) {
	    my $b1 = $n1 % $base; $n1 = int($n1 / $base);
	    my $b2 = $n2 % $base; $n2 = int($n2 / $base);
	    $n += $b2 * $mul;
	    $mul *= $base;
	    $n += $b1 * $mul;
	    $mul *= $base;
	}
	$n1 and faint(SP_DIGITS, $base, $orig1);
	$n2 and faint(SP_DIGITS, $base, $orig2);
    }
    $n;
}

sub n_uninterleave ($$) {
    my ($num, $base) = @_;
    my ($n1, $n2);
    if ($base == 2) {
	#                                                                a_b_c_d_e_f_g_h_j_k_l_m_n_p_q_r_
	$n1 = (($num & 0x88888888) >> 2) | (($num & 0x22222222) >> 1); # 00ab00cd00ef00gh00jk00lm00np00qr
	$n1 = (($n1  & 0x30303030) >> 2) |  ($n1  & 0x03030303);       # 0000abcd0000efgh0000jklm0000npqr
	$n1 = (($n1  & 0x0f000f00) >> 4) |  ($n1  & 0x000f000f);       # 00000000abcdefgh00000000jklmnpqr
	$n1 = (($n1  & 0x00ff0000) >> 8) |  ($n1  & 0x000000ff);       # 0000000000000000abcdefghjklmnpqr
	#                                                                _a_b_c_d_e_f_g_h_j_k_l_m_n_p_q_r
	$n2 = (($num & 0x44444444) >> 1) |  ($num & 0x11111111);       # 00ab00cd00ef00gh00jk00lm00np00qr
	$n2 = (($n2  & 0x30303030) >> 2) |  ($n2  & 0x03030303);       # 0000abcd0000efgh0000jklm0000npqr
	$n2 = (($n2  & 0x0f000f00) >> 4) |  ($n2  & 0x000f000f);       # 00000000abcdefgh00000000jklmnpqr
	$n2 = (($n2  & 0x00ff0000) >> 8) |  ($n2  & 0x000000ff);       # 0000000000000000abcdefghjklmnpqr
    } elsif ($base == 4) {
	#                                                                a_b_c_d_e_f_g_h_
	$n1 = (($num & 0xc0c0c0c0) >> 4) | (($num & 0x0c0c0c0c) >> 2); # 00ab00cd00ef00gh
	$n1 = (($n1  & 0x0f000f00) >> 4) |  ($n1  & 0x000f000f);       # 0000abcd0000efgh
	$n1 = (($n1  & 0x00ff0000) >> 8) |  ($n1  & 0x000000ff);       # 00000000abcdefgh
	#                                                                _a_b_c_d_e_f_g_h
	$n2 = (($num & 0x30303030) >> 2) |  ($num & 0x03030303);       # 00ab00cd00ef00gh
	$n2 = (($n2  & 0x0f000f00) >> 4) |  ($n2  & 0x000f000f);       # 0000abcd0000efgh
	$n2 = (($n2  & 0x00ff0000) >> 8) |  ($n2  & 0x000000ff);       # 00000000abcdefgh
    } else {
	my $bits = $spotbits[$base];
	$n1 = 0;
	$n2 = 0;
	my $mul = 1;
	for (my $b = 0; $b < $bits && $num; $b++) {
	    my $b2 = $num % $base; $num = int($num / $base);
	    my $b1 = $num % $base; $num = int($num / $base);
	    $n1 += $b1 * $mul;
	    $n2 += $b2 * $mul;
	    $mul *= $base;
	}
    }
    ($n1, $n2);
}

sub n_select ($$$) {
    my ($n1, $n2, $base) = @_;
    my $n = 0;
    if ($base == 2) {
	my $bit = 1;
	my $resbit = 1;
	while ($n2) {
	    while (! ($n2 & $bit)) { $bit <<= 1; }
	    $n1 & $bit and $n |= $resbit;
	    $n2 ^= $bit;
	    $bit <<= 1;
	    $resbit <<= 1;
	}
    } else {
	my @num = (0) x $base;
	my @mul = (1) x $base;
	while ($n2) {
	    my $b1 = $n1 % $base; $n1 = int($n1 / $base);
	    my $b2 = $n2 % $base; $n2 = int($n2 / $base);
	    $b2 or next;
	    $b1 and $num[$b2] += $mul[$b2] * ($b1 > $b2 ? $b1 : $b2);
	    $mul[$b2] *= $base;
	}
	shift @num;
	$n = shift @num;
	splice(@mul, 0, 2);
	while (@num) {
	    $n = $n * shift(@mul) + shift(@num);
	}
    }
    $n;
}

sub n_unselect ($$) {
    my ($num, $base) = @_;
    my $res = 0;
    if ($base == 2) {
	while ($num) {
	    $num >>= 1;
	    $res = ($res << 1) | 1;
	}
    } else {
	my $mul = 1;
	while ($num) {
	    $num = int($num / $base);
	    $res += $mul;
	    $mul *= $base;
	}
    }
    $res;
}

sub n_swb ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my $res;
    if ($base == 2) {
	$res = $num >> 1;
	$num & 1 and $res |= $spots > 1 ? 0x80000000 : 0x8000;
	$res ^= $num;
    } elsif ($base == 4) {
	# we used to have:
	#$res = ($num >> 2) | (($num & 0x3) << ($spots > 1 ? 30 : 14));
	#$res = ((($res & 0x33333333) + 0xcccccccc - ($num & 0x33333333)) & 0x33333333)
	#     | ((($res & 0xcccccccc) + 0x33333330 - ($num & 0xcccccccc)) & 0xcccccccc);
	# but this actually requires 33-bit numbers which is fine if perl has 64-bit integers
	# but produces the wrong result with 32-bit integers; so we do that for 16-bit
	# numbers and do it twice for 32-bit
	if ($spots > 1) {
	    my $hi = ($num >> 18) | (($num & 0x3) << 14);
	    my $lo = ($num >> 2) & 0xffff;
	    my $nh = $num >> 16;
	    $hi = ((($hi & 0x3333) + 0xcccc - ($nh & 0x3333)) & 0x3333)
	        | ((($hi & 0xcccc) + 0x3330 - ($nh & 0xcccc)) & 0xcccc);
	    $lo = ((($lo & 0x3333) + 0xcccc - ($num & 0x3333)) & 0x3333)
	        | ((($lo & 0xcccc) + 0x3330 - ($num & 0xcccc)) & 0xcccc);
	    $res = ($hi << 16) | $lo;
	} else {
	    $res = ($num >> 2) | (($num & 0x3) << 14);
	    $res = ((($res & 0x3333) + 0xcccc - ($num & 0x3333)) & 0x3333)
	         | ((($res & 0xcccc) + 0x3330 - ($num & 0xcccc)) & 0xcccc);
	}
    } else {
	my $carry = $num % $base;
	my $high = $carry;
	$num = int($num / $base);
	my $mul = 1;
	$res = 0;
	my $bits = $bits[$spots][$base];
	for (my $b = 1; $b < $bits; $b++) {
	    my $bit = $num % $base;
	    $num = int($num / $base);
	    ($bit, $carry) = ($bit - $carry, $bit);
	    $bit < 0 and $bit += $base;
	    $res += $bit * $mul;
	    $mul *= $base;
	}
	$high -= $carry;
	$high < 0 and $high += $base;
	$res += $high * $mul;
    }
    $res;
}

sub n_unswb ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my @num = _digits($num, $spots, $base);
    my @check = @num;
    my $carry = 0;
    for my $v (reverse @num) {
	($v, $carry) = ($carry, ($carry + $v) % $base);
    }
    my $new_value = _from_digits($base, @num);
    unshift @num, $num[-1];
    while (@num > 1) {
	my $dig = shift @num;
	$dig = ($dig - $num[0]) % $base;
	if ($dig != shift @check) {
	    faint(SP_ASSIGN, $base, '|', $num);
	}
    }
    $new_value;
}

sub n_awc ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my $res;
    if ($base == 2) {
	$res = $num >> 1;
	$num & 1 and $res |= $spots > 1 ? 0x80000000 : 0x8000;
	$res ^= $num;
    } elsif ($base == 4) {
	# we used to have:
	#$res = ($num >> 2) | (($num & 0x3) << ($spots > 1 ? 30 : 14));
	#$res = ((($num & 0x33333333) + ($res & 0x33333333)) & 0x33333333)
	#     | ((($num & 0xcccccccc) + ($res & 0xcccccccc)) & 0xcccccccc);
	# but this actually requires 33-bit numbers which is fine if perl has 64-bit integers
	# but produces the wrong result with 32-bit integers; so we do that for 16-bit
	# numbers and do it twice for 32-bit
	if ($spots > 1) {
	    my $hi = ($num >> 18) | (($num & 0x3) << 14);
	    my $lo = ($num >> 2) & 0xffff;
	    my $nh = $num >> 16;
	    $hi = ((($nh & 0x3333) + ($hi & 0x3333)) & 0x3333)
		| ((($nh & 0xcccc) + ($hi & 0xcccc)) & 0xcccc);
	    $lo = ((($num & 0x3333) + ($lo & 0x3333)) & 0x3333)
		| ((($num & 0xcccc) + ($lo & 0xcccc)) & 0xcccc);
	    $res = ($hi << 16) | $lo;
	} else {
	    $res = ($num >> 2) | (($num & 0x3) << 14);
	    $res = ((($num & 0x3333) + ($res & 0x3333)) & 0x3333)
		 | ((($num & 0xcccc) + ($res & 0xcccc)) & 0xcccc);
	}
    } else {
	my $carry = $num % $base;
	my $high = $carry;
	$num = int($num / $base);
	my $mul = 1;
	$res = 0;
	my $bits = $bits[$spots][$base];
	for (my $b = 1; $b < $bits; $b++) {
	    my $bit = $num % $base;
	    $num = int($num / $base);
	    ($bit, $carry) = ($bit + $carry, $bit);
	    $bit >= $base and $bit -= $base;
	    $res += $bit * $mul;
	    $mul *= $base;
	}
	$high += $carry;
	$high >= $base and $high -= $base;
	$res += $high * $mul;
    }
    $res;
}

sub n_unawc ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my @check = _digits($num, $spots, $base);
    # unlike swb, undoing awc requires to look for the right first digit...
    TRY:
    for (my $try = 0; $try < $base; $try++) {
	my @num = @check;
	my $carry = $try;
	for my $v (reverse @num) {
	    ($v, $carry) = ($carry, ($v - $carry) % $base);
	}
	my $new_value = _from_digits($base, @num);
	unshift @num, $num[-1];
	my @c = @check;
	while (@num > 1) {
	    my $dig = shift @num;
	    $dig = ($num[0] + $dig) % $base;
	    if ($dig != shift @c) {
		next TRY;
	    }
	}
	return $new_value;
    }
    faint(SP_ASSIGN, $base, '|', $num);
}

sub n_but ($$$$) {
    my ($num, $spots, $base, $prefer) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my $res;
    if ($base == 2) {
	faint(SP_BASE, "$prefer/$base") if $prefer != 7 && $prefer != 0;
	$res = $num >> 1;
	$num & 1 and $res |= $spots > 1 ? 0x80000000 : 0x8000;
	$prefer ? ($res |= $num) : ($res &= $num);
    } elsif ($prefer == 7) {
	if ($base == 4) {
	    # we had some clever code to calculate "or" but as for SWB and AWC
	    # it turns out that 32-bit systems can't cope with some values;
	    # so now doing this separately for 16 and 32 bits, and for the
	    # latter calculate two 16-bit values and joining them (note that
	    # the 16-bit calculation actually uses 20 bits...)
	    my $mask;
	    if ($spots < 2) {
		$res = ($num >> 2) | (($num & 0x03) << 14);
		my $lm = (($res & 0x3333) + 0x44444 - ($num & 0x3333)) & 0x44444;
		$lm = ($lm >> 1) | ($lm >> 2);
		my $um = (($res & 0xcccc) + 0x11111 - ($num & 0xcccc)) & 0x11111;
		$um = ($um >> 1) | ($um >> 2);
		$mask = ($lm | $um) & 0xffff;
	    } else {
		$res = ($num >> 2) | (($num & 0x03) << 30);
		my $rhi = $res >> 16;
		my $nhi = $num >> 16;
		my $lmhi = (($rhi & 0x3333) + 0x44444 - ($nhi & 0x3333)) & 0x44444;
		$lmhi = ($lmhi >> 1) | ($lmhi >> 2);
		my $umhi = (($rhi & 0xcccc) + 0x11111 - ($nhi & 0xcccc)) & 0x11111;
		$umhi = ($umhi >> 1) | ($umhi >> 2);
		my $rlo = $res & 0xffff;
		my $nlo = $num & 0xffff;
		my $lmlo = (($rlo & 0x3333) + 0x44444 - ($nlo & 0x3333)) & 0x44444;
		$lmlo = ($lmlo >> 1) | ($lmlo >> 2);
		my $umlo = (($rlo & 0xcccc) + 0x11111 - ($nlo & 0xcccc)) & 0x11111;
		$umlo = ($umlo >> 1) | ($umlo >> 2);
		$mask = (($lmhi | $umhi) << 16) | (($lmlo | $umlo) & 0xffff);
	    }
	    $res = ($res & $mask) | ($num & ~$mask);
	} else {
	    my $carry = $num % $base;
	    my $high = $carry;
	    $num = int($num / $base);
	    my $mul = 1;
	    $res = 0;
	    my $bits = $bits[$spots][$base];
	    for (my $b = 1; $b < $bits; $b++) {
		my $bit = $num % $base;
		$num = int($num / $base);
		$res += $mul * ($carry < $bit ? $bit : $carry);
		$carry = $bit;
		$mul *= $base;
	    }
	    $res += $mul * ($carry < $high ? $high : $carry);
	}
    } elsif ($prefer == 0) {
	my $carry = $num % $base;
	my $high = $carry;
	$num = int($num / $base);
	my $mul = 1;
	$res = 0;
	my $bits = $bits[$spots][$base];
	for (my $b = 1; $b < $bits; $b++) {
	    my $bit = $num % $base;
	    $num = int($num / $base);
	    if ($bit && $carry) {
		$res += $mul * ($carry < $bit ? $bit : $carry);
	    }
	    $carry = $bit;
	    $mul *= $base;
	}
	if ($high && $carry) {
	    $res += $mul * ($carry < $high ? $high : $carry);
	}
    } else {
	faint(SP_BASE, "$prefer/$base") if $prefer > $base - 2;
	my $carry = $num % $base;
	my $high = $carry;
	$num = int($num / $base);
	my $mul = 1;
	$res = 0;
	my $bits = $bits[$spots][$base];
	for (my $b = 1; $b < $bits; $b++) {
	    my $bit = $num % $base;
	    $num = int($num / $base);
	    if ($bit <= $prefer) {
		if ($carry < $bit || $carry > $prefer) {
		    $res += $bit * $mul;
		} else {
		    $res += $carry * $mul;
		}
	    } else {
		if ($carry < $bit && $carry > $prefer) {
		    $res += $bit * $mul;
		} else {
		    $res += $carry * $mul;
		}
	    }
	    $carry = $bit;
	    $mul *= $base;
	}
	if ($high <= $prefer) {
	    if ($carry < $high || $carry > $prefer) {
		$res += $high * $mul;
	    } else {
		$res += $carry * $mul;
	    }
	} else {
	    if ($carry < $high && $carry > $prefer) {
		$res += $high * $mul;
	    } else {
		$res += $carry * $mul;
	    }
	}
    }
    $res;
}

sub n_unbut ($$$$) {
    my ($num, $spots, $base, $prefer) = @_;
    faint(SP_BASE, "$prefer/$base") if $prefer != 7 && $prefer > $base - 2;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my @num = _digits($num, $spots, $base);
    push @num, $num[0];
    my @result = ();
    while (@num > 1) {
	my $num1 = shift @num;
	my $num2 = $num[0];
	if ($num1 == $prefer && $num2 == $prefer) {
	    push @result, $prefer;
	} elsif ($num1 == $prefer) {
	    push @result, $num2;
	} elsif ($num2 == $prefer) {
	    push @result, $num1;
	} elsif ($num1 < $prefer && $num2 > $prefer) {
	    push @result, $num2;
	} elsif ($num1 > $prefer && $num2 < $prefer) {
	    push @result, $num1;
	} else {
	    push @result, $num1 < $num2 ? $num1 : $num2;
	}
    }
    my $new_value = _from_digits($base, @result);
    my $check = n_but($new_value, $spots, $base, $prefer);
    $check == $num or faint(SP_ASSIGN, $base, $prefer . '?', $num);
    $new_value;
}

sub n_bitdiv ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my $bits = $bits[$spots][$base];
    faint(SP_DIVIDE) if $num < 1;
    my $carry = $num % $base;
    my $div = int($num / $base);
    $div += $carry * $base ** ($bits - 1);
    int($div / $num);
}

sub n_unbitdiv ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my $digits = $bits[$spots][$base];
    my $limit = 1;
    for (my $d = 1; $d < $digits; $d++) {
	$limit *= $base;
    }
    my @range = ();
    my $range = 0;
    if ($num == 0) {
	for (my $x = 0; $x < $base; $x++) {
	    my $min = 1 + int($x * ($limit - 1) / ($base - 1));
	    my $d = $limit - $min;
	    next if $d < 1;
	    push @range, [$x, $min, $d];
	    $range += $d;
	}
    } else {
	for (my $x = 1; $x < $base; $x++) {
	    my $min = $x * ($limit - $num - 1) / ($num * $base + $base - 1);
	    my $max = 1 + int($x * ($limit - $num) / ($num * $base - 1));
	    if ($min < 0) {
		$min = 0;
	    } else {
		$min = int(1 + $min);
	    }
	    $max = $limit * $base if $max > $limit * $base;
	    next if $min >= $max;
	    $max -= $min;
	    push @range, [$x, $min, $max];
	    $range += $max;
	}
    }
    $range > 0 or faint(SP_ASSIGN, $base, '-', $num);
    my $rnd = int(rand $range);
    for my $rg (@range) {
	my ($x, $low, $r) = @$rg;
	if ($rnd < $r) {
	    $num = ($rnd + $low) * $base + $x;
	    last;
	}
	$rnd -= $r;
    }
    $num;
}

sub n_arithdiv ($$) {
    my ($num, $base) = @_;
    my $div = int($num / $base);
    faint(SP_DIVIDE) if $div < 1;
    int($num / $div);
}

sub n_unarithdiv ($$$) {
    my ($num, $spots, $base) = @_;
    $spots == REG_spot || $spots == REG_twospot or _invalid($spots);
    my $digits = $bits[$spots][$base];
    my $limit = 1;
    for (my $d = 1; $d < $digits; $d++) {
	$limit *= $base;
    }
    my (@gives_plus_1, @gives_plus_2, @gives_plus_3);
    if ($base == 2) {
	@gives_plus_1 = (3);
    } elsif ($base == 3) {
	@gives_plus_1 = (4, 8);
    } elsif ($base == 4) {
	@gives_plus_1 = (5, 10, 11, 15);
    } elsif ($base == 5) {
	@gives_plus_1 = (6, 12, 13, 18, 19, 24);
	@gives_plus_2 = (14);
    } elsif ($base == 6) {
	@gives_plus_1 = (7, 14, 15, 21, 22, 23, 28, 29, 35);
	@gives_plus_2 = (16, 17);
    } elsif ($base == 7) {
	@gives_plus_1 = (8, 16, 17, 24, 25, 26, 32, 33, 34, 40, 41, 48);
	@gives_plus_2 = (18, 19, 27);
	@gives_plus_3 = (20);
    }
    if ($num == $base) {
	my @values = (@gives_plus_1, @gives_plus_2, @gives_plus_3);
	# any value > 2 * $base will do except the ones in @values
	$limit *= $base;
	$limit -= @values;
	my %avoid = ();
	for (my $i = 0; $i < @values; $i++) {
	    $avoid{$values[$i]} = $limit + $i;
	}
	$limit -= 1 + 2 * $base;
	$num = int(2 * $base + 1 + int(rand($limit)));
	$num = $avoid{$num} if exists $avoid{$num};
    } elsif ($num == $base + 1 && @gives_plus_1) {
	$num = $gives_plus_1[int(rand scalar @gives_plus_1)];
    } elsif ($num == $base + 2 && @gives_plus_2) {
	$num = $gives_plus_2[int(rand scalar @gives_plus_2)];
    } elsif ($num == $base + 3 && @gives_plus_3) {
	$num = $gives_plus_3[int(rand scalar @gives_plus_3)];
    } elsif ($num < $base || $num >= 2 * $base) {
	faint(SP_ASSIGN, $base, '-', $num);
    }
    $num;
}

1;

