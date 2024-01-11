# test INTERcal NETworking -- IPv6

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/INET t/04ipv6.t 1.-94.-2.3

use Socket qw(inet_aton inet_ntoa IPV6_MULTICAST_IF);
use Language::INTERCAL::Rcfile;
use Language::INTERCAL::Server '1.-94.-2.1';
use Language::INTERCAL::Theft '1.-94.-2.3';
use Language::INTERCAL::INET::Interface '1.-94.-2.3', qw(
    interface_list iflags_up iflags_multicast
    ifitem_name
);

if (! Language::INTERCAL::Server::has_ipv6) {
    print "1..0 # skipped: IPv6 not supported, try installing Socket6 and IO::Socket::INET6\n";
    exit 0;
}

my @interfaces = interface_list(iflags_up | iflags_multicast);
my ($interface, $interface2, $alter);
my $alter1 = 0;
if (@interfaces) {
    $interface = $interfaces[-1][ifitem_name];
    $alter1 = 1;
    $alter2 = 0;
    if (@interfaces > 1) {
	$alter2 = 2;
	$interface2 = $interfaces[0][ifitem_name];
    }
}

my @tests = (
    [0, $alter1, 'ff02::1', '127.0.1.0'],
    [1, 0, '2001::1', '224.0.0.1'],
    [1, $alter1, 'ff1e::42', '127.0.2.0'],
    [0, 0, '::1', '224.0.0.0'],
($interface ?  [1, $alter2, "fe80::1\%$interface", '224.0.0.2'] : ()),
);

my $count = 0;
for my $test (@tests) {
    my ($create, $alter, $ipv6, $ipv4) = @$test;
    $count += 1 + $create + $alter;
}
print "1..$count\n";

my $rc = Language::INTERCAL::Rcfile->new();
$rc->setoption(nouserrc => 1);
$rc->setoption(nosystemrc => 1);
$rc->rcfind('system');
$rc->rcfind('INET');
$rc->load;
my $t = Language::INTERCAL::Theft->new(undef, $rc, '', []);

for my $test (@tests) {
    my ($create, $alter, $ipv6, $ipv4) = @$test;
    my $packed = inet_aton($ipv4);
    my $number = unpack('N', $packed);
    if ($create) {
	eval {
	    my $a = $t->encode_address($ipv6);
	    defined $a or die "No result for $ipv6\n";
	    my $n = inet_ntoa(pack('N', $a));
	    $n eq $ipv4 or die "Unexpected IPv4 address $n for $ipv6: expected $ipv4\n";
	    print "ok\n";
	};
	if ($@) {
	    print STDERR $@;
	    print "not ok\n";
	}
    }
    eval {
	my $a = $t->decode_address($number);
	defined $a or die "No result for $ipv4\n";
	$a eq $ipv6 or die "Unexpected IPv6 address $a for $ipv4: expected $ipv6\n";
	print "ok\n";
    };
    if ($@) {
	print STDERR $@;
	print "not ok\n";
    }
    $alter or next;
    my $v = $ipv4;
    my $i;
    my $n = $ipv6;
    if ($alter == 1) {
	my $index = $t->encode_interface($interface);
	$v =~ s/\.0$/.$index/;
	$i = $index;
	$n .= '%' . $interface;
    } else {
	$v =~ s/\.(\d+)$/'.' . ($1 + 1)/e;
	$i = 1;
	$n =~ s/%.*$/%$interface2/;
	eval {
	    my $a = $t->encode_address($n);
	    defined $a or die "No result for $ipv6\n";
	    my $f = inet_ntoa(pack('N', $a));
	    $f eq $v or die "Unexpected IPv4 address $f for $n: expected $v\n";
	    print "ok\n";
	};
	if ($@) {
	    print STDERR $@;
	    print "not ok\n";
	}
    }
    eval {
	my $a = $t->decode_address($number + $i);
	defined $a or die "No result for $v\n";
	$a eq $n or die "Unexpected IPv6 address $a for $v: expected $n\n";
	print "ok\n";
    };
    if ($@) {
	print STDERR $@;
	print "not ok\n";
    }
}

