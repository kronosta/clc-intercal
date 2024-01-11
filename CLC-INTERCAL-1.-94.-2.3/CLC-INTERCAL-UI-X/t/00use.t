# just checking your version of Perl does not barf when seeing this

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use Language::INTERCAL::Distribute '1.-94.-2.2';

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/UI-X t/00use.t 1.-94.-2.2") =~ /\s(\S+)$/;

my $Gtk;
BEGIN {
    eval {
	require Gtk3;
	import Gtk3;
	$Gtk = 'Gtk3';
    };
    defined $Gtk or eval {
	require Gtk2;
	import Gtk2;
	$Gtk = 'Gtk2';
    };
};

defined $Gtk and exit Language::INTERCAL::Distribute::use_test('UI-X');
print "1..0 # skipped: neither Gtk2 nor Gtk3 found\n";
exit 0;

