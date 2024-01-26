package Language::INTERCAL::Charset::EBCDIC;

# Convert between EBCDIC and ASCII

# This file is part of CLC-INTERCAL.

# Copyright (C) 1999, 2000, 2002, 2006-2008 Claudio Calvelli, all rights reserved

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Charset/EBCDIC.pm 1.-94.-2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(ascii2ebcdic ebcdic2ascii);

sub ebcdic2ascii {
    @_ == 1 or croak "Usage: ebcdic2ascii(STRING)";
    my $string = shift;
    $string =~ tr[\000-\037\100\112\113\114\115\116\117\120\132\133\134\135\136\137\140\141\145\152\153\154\155\156\157\172\173\174\175\176\177\201-\211\221-\231\234\236\241\242-\251\260\301-\311\321-\331\334\336\342-\351\360-\371\377]
    		 [\000-\037\040\242\056\074\050\053\041\046\135\044\052\051\073\254\055\057\245\174\054\045\137\076\077\072\043\100\047\075\042\141-\151\152-\162\173\133\176\163-\172\136\101-\111\112-\122\175\134\123-\132\060-\071\177];
    $string;
}

sub ascii2ebcdic {
    @_ == 1 or croak "Usage: ascii2ebcdic(STRING)";
    my $string = shift;
    $string =~ tr[\000-\037\040\242\056\074\050\053\041\046\135\044\052\051\073\254\055\057\245\174\054\045\137\076\077\072\043\100\047\075\042\141-\151\152-\162\173\133\176\163-\172\136\101-\111\112-\122\175\134\123-\132\060-\071\177]
    		 [\000-\037\100\112\113\114\115\116\117\120\132\133\134\135\136\137\140\141\145\152\153\154\155\156\157\172\173\174\175\176\177\201-\211\221-\231\234\236\241\242-\251\260\301-\311\321-\331\334\336\342-\351\360-\371\377];
    $string;
}

1;

__END__

=head1 NAME

Charset::EBCDIC - convert between INTERCAL variant of EBCDIC and ASCII

=head1 SYNOPSIS

    use Charset::EBCDIC 'ascii2abcdic';

    my $a = ebcdic2ascii "(EBCDIC text)";

=head1 DESCRIPTION

I<Charset::EBCDIC> defines functions to convert between a subset of ASCII and a
subset of nonstandard EBCDIC (since there isn't such a thing as a standard
EBCDIC we defined our own variant which is guaranteed to be incompatible
with all versions of EBCDIC used by IBM hardware - however, when we have
chosen a code for a character, we have made sure that at least one - but
certainly not all - IBM models used that same code, so the choice cannot
be criticised). If you really want to know, several variants of EBCDIC
are listed in RFC 1345, which is available from the usual sources.

Two functions, I<ebcdic2ascii> and I<ascii2ebcdic> are exportable but not
exported by default. They do the obvious thing to their first argument and
return the transformed string.

=head1 EBCDIC CHARACTER TABLE

The following are the characters recognised. The ones shown as 2 letter
abbreviations cannot be translated to ASCII (except for the control
characters, which do have an ASCII equivalent).

     +   0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f   Notes
    00                          OV TA LF       CR         OV=overstrike
    10                                                    TA=tab
    20                                                    LF=linefeed
    30                                                    CR=carr-return
    40  SP                            CT  .  <  (  +  !   SP=space
    50   &                             ]  $  *  )  ; NO   CT=cents
    60   -  /          XO              |  ,  %  _  >  ?   NO=not-sign
    70                                 :  #  @  '  =  "   XO=XOR(1)
    80      a  b  c  d  e  f  g  h  i                  
    90      j  k  l  m  n  o  p  q  r        {     [   
    a0      ~  s  t  u  v  w  x  y  z                RE   RE=registered
    b0   ^ PO       CO                                    PO=pound
    c0      A  B  C  D  E  F  G  H  I                     CO=copyright
    d0      J  K  L  M  N  O  P  Q  R        }     \   
    e0         S  T  U  V  W  X  Y  Z                  
    f0   0  1  2  3  4  5  6  7  8  9                DE   DE=delete

(1) The symbol for the INTERCAL XOR operator, "V overstrike -".

=head1 COPYRIGHT

This module is part of CLC-INTERCAL.

Copyright (C) 1999, 2000, 2002, 2006, 2007 Claudio Calvelli, all rights reserved

See the files README and COPYING in the distribution for information.

=head1 SEE ALSO

A qualified psychiatrist.

