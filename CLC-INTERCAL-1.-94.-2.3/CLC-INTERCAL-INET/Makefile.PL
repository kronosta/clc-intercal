#!/usr/bin/perl -w

eval 'exec perl -S $0 ${1+"$@"}'
    if 0;

# This script will create the Makefile to build CLC-INTERCAL's INTERNET
# (INTERcal NETworking) library

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

require 5.005;
use strict;
use File::Spec::Functions qw(catfile);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/INET Makefile.PL 1.-94.-2.3") =~ /\s(\S+)$/;

my $in_bundle = $ENV{CLC_INTERCAL_BUNDLE} && $ENV{CLC_INTERCAL_BUNDLE} eq '42' && $ENV{CLC_INTERCAL_ROOT};

for my $module (qw(InstallModule Exporter)) {
    if ($in_bundle) {
	eval {
	    require (catfile($ENV{CLC_INTERCAL_ROOT}, 'INTERCAL', "$module.pm"));
	    eval "import Language::INTERCAL::$module '$VERSION';";
	    die $@ if $@;
	};
    } else {
	eval "use Language::INTERCAL::$module '$VERSION';";
    }
    if ($@) {
	$@ =~ /can't locate/i and die "You don't appear to have CLC-INTERCAL installed:\n$@";
	die "Error loading the CLC-INTERCAL installer:\n$@";
    }
}

# look for an interface list module
my ($ifmodule, %ifmodule) = Language::INTERCAL::InstallModule::module_search(
    ['Getifaddrs.xs', undef, \&checkifnames],
    ['NetInterface.pm', \&hasindex, \&Language::INTERCAL::InstallModule::module_check, 'Net::Interface', 1.0],
);
$ifmodule or die "Cannot find an interface module, please see documentation\n";
print "Building interface module: $ifmodule\n";

install Language::INTERCAL::InstallModule 'INET',
    prereq => {
	    'Socket6' => 0,
	    'IO::Socket::INET6' => 0,
    },
    link => \%ifmodule;

# check that the Net::Interface module we found has a working ->index
sub hasindex {
    # verify that Net::Interface provides a nonzero index;
    # unpatched versions will provide zero on some systems, and
    # we can't use them.
    require Net::Interface;
    for my $if (Net::Interface->interfaces) {
	$if->index && $if->index > 0 and return 1;
    }
    # we must assume there is no supported module
    return 0;
}

# check if we can compile an XS and if we have getifaddrs and if_nametoindex
# also check that all the constants we use are defined
sub checkifnames {
    Language::INTERCAL::InstallModule::compile_check(<<'EOF');
#include <stdio.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <net/if.h>
#include <ifaddrs.h>
int main(void) {
    struct ifaddrs * addrs;
    int fl = IFF_LOOPBACK | IFF_BROADCAST | IFF_MULTICAST | IFF_UP;
    fl += AF_INET + AF_INET6;
    fl += sizeof(struct in6_addr);
    if (getifaddrs(&addrs) != 1) {
	if (addrs) {
	    fl += if_nametoindex(addrs->ifa_name);
	    fl += addrs->ifa_flags;
	    fl += addrs->ifa_addr->sa_family;
	    if (addrs->ifa_broadaddr != NULL) fl++;
	    if (addrs->ifa_addr != NULL) fl++;
	}
	freeifaddrs(addrs);
    }
    return fl;
}
EOF
}

1;
