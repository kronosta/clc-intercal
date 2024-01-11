package Language::INTERCAL::INET::Interface;

# Interface detection, using our own XS

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.3';

use vars qw($VERSION $PERVERSION @ISA @EXPORT_OK %EXPORT_TAGS);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/INET links/Getifaddrs.pm 1.-94.-2.3") =~ /\s(\S+)$/;

require DynaLoader;

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

@ISA = qw(DynaLoader);

{
    my ($v, @v) = split(/\./, $VERSION);
    @v = map { sprintf "%03d", $_ + 500 } @v;
    local $VERSION = "$v." .  join('', @v);
    Language::INTERCAL::INET::Interface->bootstrap();
}

1;
