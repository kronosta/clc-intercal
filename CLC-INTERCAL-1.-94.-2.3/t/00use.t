# just checking your version of Perl does not barf when seeing this

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use Language::INTERCAL::Distribute '1.-94.-2.3';

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL t/00use.t 1.-94.-2.3") =~ /\s(\S+)$/;

exit Language::INTERCAL::Distribute::use_test('');

