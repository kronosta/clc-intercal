package Language::INTERCAL::INET::Interface;

# Interface detection, using Net::Interface.

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;
use Socket qw(AF_INET AF_INET6);
use Net::Interface qw(
    IFF_UP IFF_LOOPBACK IFF_BROADCAST IFF_MULTICAST
    RFC2373_NODELOCAL RFC2373_LINKLOCAL RFC2373_SITELOCAL
    RFC2373_ORGLOCAL RFC2373_GLOBAL
    IPV6_ADDR_MULTICAST
);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/INET links/NetInterface.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Language::INTERCAL::Exporter '1.-94.-2.3';

use vars qw(@EXPORT_OK %EXPORT_TAGS);
my @flags = qw(
    iflags_loopback iflags_broadcast iflags_multicast iflags_up
);
my @items = qw(
    ifitem_name ifitem_index ifitem_broadcast
    ifitem_address4 ifitem_address6 ifitem_flags
);
my @scope = qw(
    ifscope_node ifscope_link ifscope_site ifscope_org ifscope_global
);
@EXPORT_OK = (@flags, @items, @scope, qw(
    interface_list address_scope address_multicast6
));
%EXPORT_TAGS = (
    FLAGS => \@flags,
    ITEMS => \@items,
    SCOPE => \@scope,
);

use constant iflags_loopback  => 0x01;
use constant iflags_broadcast => 0x02;
use constant iflags_multicast => 0x04;
use constant iflags_up        => 0x80;

use constant ifitem_name      => 0;
use constant ifitem_index     => 1;
use constant ifitem_broadcast => 2;
use constant ifitem_address4  => 3;
use constant ifitem_address6  => 4;
use constant ifitem_flags     => 5;

use constant ifscope_node     => 0x01;
use constant ifscope_link     => 0x02;
use constant ifscope_site     => 0x05;
use constant ifscope_org      => 0x08;
use constant ifscope_global   => 0x0e;

sub interface_list {
    @_ == 0 || @_ == 1 or croak "Usage: interface_list [(FLAGS)]";
    my $reqflags = @_ ? $_[0] : iflags_up;
    my @list;
    for my $if (Net::Interface->interfaces) {
	my $flags = $if->flags || 0;
	my $cnvflags = 0;
	$flags & IFF_LOOPBACK and $cnvflags |= iflags_loopback;
	$flags & IFF_BROADCAST and $cnvflags |= iflags_broadcast;
	$flags & IFF_MULTICAST and $cnvflags |= iflags_multicast;
	$flags & IFF_UP and $cnvflags |= iflags_up;
	($cnvflags & $reqflags) == $reqflags or next;
	my @item;
	$item[ifitem_name] = $if->name;
	$item[ifitem_index] = $if->index;
	$flags & IFF_BROADCAST
	    and $item[ifitem_broadcast] = [$if->broadcast(&AF_INET)];
	$item[ifitem_address4] = [$if->address(&AF_INET)];
	$item[ifitem_address6] = [$if->address(&AF_INET6)];
	$item[ifitem_flags] = $cnvflags;
	push @list, \@item;
    }
    @list;
}

sub address_scope ($) {
    my ($addr) = @_;
    my $s = Net::Interface->scope($addr) & 0x0f;
    $s == RFC2373_NODELOCAL and return ifscope_node;
    $s == RFC2373_LINKLOCAL and return ifscope_link;
    $s == RFC2373_SITELOCAL and return ifscope_site;
    $s == RFC2373_ORGLOCAL and return ifscope_org;
    $s == RFC2373_GLOBAL and return ifscope_global;
    undef;
}

sub address_multicast6 ($) {
    my ($addr) = @_;
    Net::Interface->type($addr) & IPV6_ADDR_MULTICAST;
}

