package Language::INTERCAL::Theft;

# Implementation of "theft protocol" for the INTERcal NETworking

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/INET INTERCAL/Theft.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Socket qw(:DEFAULT :crlf IPPROTO_IPV6
	      IPV6_MULTICAST_IF IPV6_MULTICAST_LOOP IPV6_MULTICAST_HOPS);
use FindBin qw($Bin);
use File::Spec::Functions qw(catfile updir splitpath catpath splitdir catdir);
use IO::Socket::INET;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import is_object);
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_INTERNET SP_INTERNAL);
use Language::INTERCAL::Server '1.-94.-2.3';
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension);
use Language::INTERCAL::INET::Interface '1.-94.-2.3', qw(
    interface_list address_multicast6 address_scope
    ifscope_link ifscope_node
    iflags_loopback iflags_broadcast iflags_multicast iflags_up
    ifitem_name ifitem_index ifitem_flags ifitem_broadcast
    ifitem_address4 ifitem_address6
);

use constant DEFAULT_PORT => 64928;

@EXPORT_OK = qw(is_localhost);

# used during testing to avoid network access; it could also be used in
# other situations, but this is intentionally undocumented (and unsupported)
our %dns_tests;

# these splats are defined by the INET extension so they may not be
# exported by Language::INTERCAL::Splats when it's loaded, so we
# first make sure the INET extension has done its bit, then load
# the splats
my $splats_loaded;
sub load_splats {
    $splats_loaded and return;
    load_extension('INET');
    defined &SP_CASE or *SP_CASE = \&Language::INTERCAL::Splats::SP_CASE;
    defined &SP_IPV6 or *SP_IPV6 = \&Language::INTERCAL::Splats::SP_IPV6;
    $splats_loaded = 1;
}

my ($ipv6, $ip_class) = Language::INTERCAL::Server::has_ipv6();

if ($ipv6) {
    import Socket6 qw(inet_pton inet_ntop getaddrinfo);
}

my ($if_cache, @if_list, @if6_list, @localhost, %localhost4, %localhost6, %if_map, %if_index, @if_index);

sub new {
    @_ >= 4 or croak "Usage: Language::INTERCAL::Theft->new(SERVER, RC, CODE, ARGS...)";
    my ($class, $server, $rc, $code, @args) = @_;
    my $port;
    eval {
	$port = DEFAULT_PORT;
	$port = $rc->getitem('BLURT');
    };
    load_splats();
    $port or faint(SP_INTERNET, $server, "INTERNET disabled by configuration");
    my (@mc_groups, @throw);
    if ($ipv6) {
	@mc_groups = $rc->getitem('READ');
	$throw[0] = 0;
	my @t = $rc->getitem('THROW');
	for my $t (@t) {
	    my ($limit, $scope) = @$t;
	    if (defined $scope) {
		defined $throw[$scope] or $throw[$scope] = $limit;
	    } else {
		for my $s (1..15) {
		    defined $throw[$s] or $throw[$s] = $limit;
		}
	    }
	}
	# anything not yet specified goes to system default, which is -1
	for my $s (0..15) {
	    defined $throw[$s] or $throw[$s] = -1;
	}
    }
    $class->_new($server, $port, \@mc_groups, \@throw, $code, @args);
}

sub _new {
    my ($class, $server, $port, $mc_groups, $throw, $code, @args) = @_;
    # localhost is either 127.0.0.1 or ::1, depending on whether we have
    # IPv6 or not... we start by getting interface information and find all
    # loopback addresses
    _get_interfaces();
    # for testing, we allow running without a theft server, which means that
    # some operations will fail - the test programs will leave $server undef
    # to tell us that
    my ($id, $host);
    if (defined $server) {
	# see if there's already a theft server running locally
	for my $h (@localhost) {
	    $id = eval { $server->tcp_socket($h, $port) };
	    defined $id or next;
	    $host = $h;
	    last;
	}
	if (! defined $id) {
	    my $tf;
	    # first see if it's in the same place as this script or
	    # somewhere nearby; this is required when we are running
	    # something like "make test" on an uninstalled package,
	    # and... the code looks messy but it's as portable as I
	    # can figure it out, as long as File::Spec knows about
	    # the system we're running on
	    my ($BV, $BD, $BP) = splitpath(catfile($Bin), 'x');
	    my @BD = splitdir($BD);
	    my ($LV, $LD, $LP) = splitpath($INC{'Language/INTERCAL/Theft.pm'});
	    my @LD = splitdir($LD);
	    push @LD, (updir) x 2;
	    for my $try (
		[0],
		[2, qw(blib script)],
		[3, qw(CLC-INTERCAL-INET blib script)],
	    ) {
		my ($up, @down) = @$try;
		if (@BD >= $up) {
		    $BD = catdir(@BD, (updir) x $up, @down);
		    my $ftf = catpath($BV, $BD, 'theft-server');
		    if (-f $ftf) {
			$tf = $ftf;
			last;
		    }
		}
		if (@LD >= $up) {
		    $LD = catdir(@LD, (updir) x $up, @down);
		    my $ftf = catpath($LV, $LD, 'theft-server');
		    if (-f $ftf) {
			$tf = $ftf;
			last;
		    }
		}
	    }
	    defined $tf or $tf = 'theft-server';
	    my @I = map { "-I$_" } @INC;
	    my @G = map { "--group=" . inet_ntop(&AF_INET6, $_->[0]) } @$mc_groups;
	    system $^X, @I, '-S', $tf, "--port=$port", @G;
	    # see if it has actually started
	    my $timeout = 10;
	CHECK_SERVER:
	    while ($timeout-- > 0) {
		select undef, undef, undef, 0.1;
		for my $h (@localhost) {
		    $id = eval { $server->tcp_socket($h, $port) };
		    defined $id or next;
		    $host = $h;
		    last CHECK_SERVER;
		}
	    }
	    defined $id or faint(SP_INTERNET, "localhost", $!);
	}
	defined $host or faint(SP_INTERNAL, "Something went wrong in Language::INTERCAL::Theft->new");
    }
    my $t = bless {
	server => $server,
	id => $id,
	host => $host,
	port => $port,
	mc_groups => $mc_groups,
	throw => $throw,
	code => $code,
	args => \@args,
	ip6index => {},
	ip6value => [],
	mc6index => {},
	mc6value => [''],
	ifcode => {},
	ifname => [''],
	ifidx => [0],
	all_servers => {},
	known_pid => {},
	known_port => {},
	binary => 0,
    }, $class;
    if ($ipv6) {
	$t->encode_address('ff02::1'); # make sure it's always 127.0.1.0
	$t->encode_address('::1'); # make sure it's always 224.0.0.0
	for my $group (@$mc_groups) {
	    $t->encode_address(inet_ntop(&AF_INET6, $group->[0])); # make sure we have space to encode this group
	}
    }
    if (defined $server) {
	my $line = $t->_getline;
	defined $line or faint(SP_INTERNET, $host, "Connection lost");
	$line =~ /^2/ or faint(SP_INTERNET, $host, $line);
	my $lp = $server->tcp_listen(\&_open, \&_line, \&_close, $t);
	$t->{victim_port} = $lp;
	$t->_command("VICTIM $$ ON PORT $lp");
    }
    $t;
}

sub server {
    @_ == 1 or croak "Usage: THEFT->server";
    my ($t) = @_;
    $t->{server};
}

sub victim_port {
    @_ == 1 or croak "Usage: THEFT->victim_port";
    my ($t) = @_;
    $t->{victim_port};
}

# convert a 32 bit number to an IP address
sub decode_address {
    @_ == 2 || @_ == 3 or croak "Usage: THEFT->decode_address(NUMBER, [MAKE BROADCAST?])";
    my ($t, $number, $make_bc) = @_;
    my ($n1, $n2, $n3, $n4) =
	($number >> 24, ($number >> 16) & 0xff, ($number >> 8) & 0xff, $number & 0xff);
    if ($ipv6) {
	if ($n1 == 127 && $n2 + $n3 > 0) {
	    # IPv6 multicast group
	    my $idx = ($n2 << 8) | $n3;
	    $idx < @{$t->{mc6value}} && defined $t->{mc6value}[$idx]
		or faint(&SP_IPV6, "No such multicast group: $idx");
	    my $mc = $t->{mc6value}[$idx];
	    if ($n4 > 0) {
		defined $t->{ifname}[$n4] or faint(&SP_IPV6, "No such interface index: $n4");
		$mc .= "%$t->{ifname}[$n4]";
	    }
	    return $make_bc ? ($mc, pack('N', $number)) : $mc;
	}
	if ($n1 >= 224 && $number != 0xffffffff) {
	    # IPv6 unicast address
	    my $idx = $number - (224 << 24);
	    $idx < @{$t->{ip6value}} && defined $t->{ip6value}[$idx]
		or faint(&SP_IPV6, "No such IPv6 address $n1.$n2.$n3.$n4");
	    return $t->{ip6value}[$idx];
	}
    }
    my $addr = join('.', $n1, $n2, $n3, $n4);
    $make_bc or return $addr;
    $number == 0 || $number == 0xffffffff and return ($addr, pack('N', 0xffffffff));
    my $pack = pack('N', $number);
    # for IPv4, it could be the broadcast address of an interface
    exists $if_map{$pack} or return $addr;
    ($addr, $pack);
}

# convert interface name to index
sub encode_interface {
    @_ == 2 or croak "Usage: THEFT->encode_interface(NAME)";
    my ($t, $interface) = @_;
    if (! exists $if_index{$interface}) {
	# maybe some new interfaces appeared?
	_get_interfaces();
	exists $if_index{$interface} or faint(&SP_IPV6, "Invalid interface $interface");
    }
    exists $t->{ifcode}{$interface} and return $t->{ifcode}{$interface};
    my $idx = @{$t->{ifname}};
    $idx > 255 and faint(&SP_IPV6, "Too many interfaces, cannot encode $interface");
    $t->{ifname}[$idx] = $interface;
    $t->{ifcode}{$interface} = $idx;
    $t->{ifidx}[$idx] = $if_index{$interface};
    return $idx;
}

# convert an IP address to a 32 bit number
sub encode_address {
    @_ == 2 or croak "Usage: THEFT->encode_address(ADDRESS)";
    my ($t, $address) = @_;
    # if it looks like an IPv4 address, it is an IPv4 address.
    if ($address =~ /^\d+(\.\d+){0,3}$/) {
	my $packed = $ipv6 ? inet_pton(&AF_INET, $address) : inet_aton($address);
	defined $packed or faint(&SP_IPV6, "Invalid address: $address");
	return unpack('N', $packed);
    } else {
	$ipv6 or faint(&SP_IPV6, "IPv6 not supported on this system");
	my $ifindex;
	$address =~ s/%([^%]+)$// and $ifindex = $t->encode_interface($1);
	my $packed = inet_pton(&AF_INET6, $address);
	defined $packed or faint(&SP_IPV6, "Invalid address: $address");
	my $unpacked = inet_ntop(&AF_INET6, $packed);
	defined $unpacked or faint(&SP_IPV6, "Invalid address: $address");
	# this is a 128-bit IPv6 address; with a large enough hammer, it
	# will go into a 32-bit register
	my $number;
	# see if we already have the address, and if not create an entry for it
	if (address_multicast6($packed)) {
	    my $idx;
	    if (exists $t->{mc6index}{$packed}) {
		$idx = $t->{mc6index}{$packed};
	    } else {
		$idx = @{$t->{mc6value}};
		$idx >= 65535 and faint(&SP_IPV6, "Too many multicast groups");
		$t->{mc6index}{$packed} = $idx;
		push @{$t->{mc6value}}, $unpacked;
	    }
	    return (127 << 24) | ($idx << 8) | ($ifindex || 0);
	} else {
	    my $idx;
	    if (address_scope($packed) == ifscope_link && defined $ifindex) {
		# need to remember the interface index and we add it to the packed address
		$packed .= chr($ifindex || 0);
		$unpacked .= '%' . $t->{ifname}[$ifindex];
	    }
	    if (exists $t->{ip6index}{$packed}) {
		$idx = $t->{ip6index}{$packed};
	    } else {
		$idx = @{$t->{ip6value}};
		$idx >= (256 - 224) << 24 and faint(&SP_IPV6, "Too many unicast addresses");
		$t->{ip6index}{$packed} = $idx;
		push @{$t->{ip6value}}, $unpacked;
	    }
	    return (224 << 24) + $idx;
	}
    }
}

sub dns_lookup {
    @_ == 2 or croak "Usage: THEFT->dns_lookup(NAME)";
    my ($t, $name) = @_;
    exists $dns_tests{$name}
	and return map { $t->encode_address($_) } @{$dns_tests{$name}};
    if ($ipv6) {
	my @result = getaddrinfo($name, '');
	my @addr;
	my %seen;
	if (@result % 5 == 0) {
	    while (@result) {
		my ($family, $type, $protocol, $packed, $name) = splice(@result, 0, 5);
		my ($port, $addr) = $family == &AF_INET6
				  ? unpack_sockaddr_in6($packed)
				  : unpack_sockaddr_in($packed);
		exists $seen{$addr} and next;
		$seen{$addr} = 0;
		$addr = inet_ntop($family, $addr);
		push @addr, $t->encode_address($addr);
	    }
	}
	return @addr;
    } else {
	my ($name, $aliases, $addrtype, $length, @addrs) = gethostbyname($name);
	return map { unpack('N', $_) } @addrs;
    }
}

sub _cleanup {
    my ($t) = @_;
    my $now = time;
    for my $kw (qw(all_servers known_port)) {
	for my $rbc (keys %{$t->{$kw}}) {
	    my $kept = 0;
	    for my $rpid (keys %{$t->{$kw}{$rbc}}) {
		if ($t->{$kw}{$rbc}{$rpid}[0] < $now) {
		    delete $t->{$kw}{$rbc}{$rpid};
		} else {
		    $kept = 1;
		}
	    }
	    $kept or delete $t->{$kw}{$rbc};
	}
    }
    for my $kw (qw(known_pid)) {
	for my $rad (keys %{$t->{$kw}}) {
	    $t->{$kw}{$rad}[0] < $now and delete $t->{$kw}{$rad};
	}
    }
}

sub find_theft_servers {
    @_ >= 1 && @_ <= 3
	or croak "Usage: THEFT->find_theft_servers[(BROADCAST [,PID])]";
    my ($t, $bcast, $pid) = @_;
    my ($ipv6_interface, $ipv6_groups, $ipv4_interface);
    my $do_ipv4 = ! defined $bcast;
    if (defined $bcast) {
	# see if this is an encoded IPv6 multicast group...
	if ($ipv6 && substr($bcast, 0, 1) eq chr(127) && substr($bcast, 1, 2) ne chr(0) x 2) {
	    my $ipv6_group = $t->decode_address(unpack('N', $bcast));
	    $ipv6_group =~ s/%([^%]+)$// and $ipv6_interface = $1;
	    $ipv6_groups = [ [inet_pton(&AF_INET6, $ipv6_group)] ];
	} else {
	    $do_ipv4 = 1;
	    $ipv4_interface = $bcast eq INADDR_ANY || $bcast eq INADDR_BROADCAST
			    ? undef
			    : $bcast;
	}
    } elsif ($ipv6) {
	# if no broadcast address was specified we also want to send to
	# all multicast groups defined by configuration
	$ipv6_groups = $t->{mc_groups};
    }
    # clean up cache
    _cleanup($t);
    # now see if the query is cached
    my $bcindex = defined $bcast ? $bcast : '';
    $pid ||= 0;
    exists $t->{all_servers}{$bcindex}{$pid}
	and return @{$t->{all_servers}{$bcindex}{$pid}[1]};
    # send all requests...
    my $port = $t->{port};
    my @sockets = ();
    my $select = '';
    my $message = $pid ? "$pid x" : 'x';
    my $timeout = 2; # 2 seconds for a server on LAN to respond will be enough
    if ($do_ipv4) {
	# broadcast UDPv4 requests...
	for my $item (@if_list) {
	    my ($if, $bc) = @$item;
	    next if defined $ipv4_interface && $ipv4_interface ne $bc;
	    my $socket = IO::Socket::INET->new(
		PeerPort  => $port,
		Proto     => 'udp',
		Type      => SOCK_DGRAM,
		Broadcast => 1,
		ReuseAddr => 1,
		Domain    => &AF_INET,
	    ) or faint(&SP_CASE, $!);
	    defined $socket->send($message, 0, pack_sockaddr_in($port, $bc))
		or faint(&SP_CASE, $!);
	    vec($select, fileno($socket), 1) = 1;
	    push @sockets, [0, $socket, $if];
	}
    }
    if ($ipv6 && defined $ipv6_groups) {
	for my $if (@if6_list) {
	    next if defined $ipv6_interface && $ipv6_interface ne $if;
	    my $socket = IO::Socket::INET6->new(
		PeerPort  => $port,
		Proto     => 'udp',
		Type      => SOCK_DGRAM,
		ReuseAddr => 1,
		Domain    => &AF_INET6,
	    ) or faint(&SP_CASE, $!);
	    my $ifindex = $if_index{$if};
	    # we'll need to talk to our local theft server if it's listening
	    # on one of these groups
	    setsockopt($socket, IPPROTO_IPV6, IPV6_MULTICAST_LOOP, pack("I", 1));
	    setsockopt($socket, IPPROTO_IPV6, IPV6_MULTICAST_IF, pack('I', $ifindex));
	    for my $ipv6_gp (@$ipv6_groups) {
		my ($ipv6_group, $limit) = @$ipv6_gp;
		if (! defined $limit) {
		    my $scope = vec($ipv6_group, 1, 8) & 0xf;
		    $limit = $t->{throw}[$scope];
		    defined $limit or $limit = 1; # not supposed to happen
		}
		$limit > 1 and $timeout = 5; # give more time for non-local nodes to respond
		setsockopt($socket, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, pack('I', $limit));
		my $p = pack_sockaddr_in6($port, $ipv6_group);
		defined $socket->send($message, 0, $p) or faint(&SP_CASE, $!);
	    }
	    vec($select, fileno($socket), 1) = 1;
	    push @sockets, [1, $socket, $if];
	}
    }
    @sockets or return ();
    # now wait for replies
    my $list;
    my %ips = ();
    my $rx = quotemeta($message) . '\s+(\d+)';
    $pid or $rx .= '\s+(\d+)';
    $rx = qr/^$rx$/;
    my $limit = time + $timeout;
    my $cache = $limit + 10;
    while ($timeout >= 0 && select($list = $select, undef, undef, $timeout)) {
	for my $sp (@sockets) {
	    my ($is6, $socket, $if) = @$sp;
	    vec($list, fileno($socket), 1) or next;
	    my $buffer = '';
	    my $ip = $socket->recv($buffer, 100, 0) or faint(&SP_CASE, $!);
	    my $addr;
	    if ($is6) {
		my ($port, $paddr) = unpack_sockaddr_in6($ip);
		$addr = inet_ntop(&AF_INET6, $paddr);
		address_scope($paddr) == ifscope_link
		    and $addr .= "%$if";
	    } else {
		my ($port, $paddr) = unpack_sockaddr_in($ip);
		$addr = inet_ntoa($paddr);
	    }
	    $ips{$addr} = undef;
	    # if they added some information and sent back the message,
	    # remember the information for later
	    if ($buffer =~ $rx) {
		if ($pid) {
		    my $rport = $1;
		    $t->{known_port}{$addr}{$pid} = [$cache, $rport];
		} else {
		    my ($rpid, $rport) = ($1, $2);
		    $t->{known_pid}{$addr} = [$cache, $rpid, $rport];
		    $t->{known_port}{$addr}{$rpid} = [$cache, $rport];
		}
	    }
	}
	$timeout = $limit - time;
    }
    my @s = keys %ips;
    @s = ((grep { /:/ } @s), (grep { ! /:/ } @s));
    $pid or $cache += 20;
    $t->{all_servers}{$bcindex}{$pid} = [$cache, \@s];
    return @s;
}

sub _getline {
    my ($t, $id) = @_;
    my $server = $t->{server};
    $id = $t->{id} if ! defined $id;
    $server->progress(0); # in case I'm talking to myself
    while (1) {
	my $count = $server->data_count($id, 1);
	defined $count or return undef;
	$count and return $server->write_in($id, 0);
	$server->progress(0.01); # in case I'm talking to myself
    }
}

sub _putline {
    my ($t, $line, $id) = @_;
    my $server = $t->{server};
    $id = $t->{id} if ! defined $id;
    $server->read_out($id, $line);
    $server->progress(0); # in case I'm talking to myself
}

sub _get_interfaces {
    return if $if_cache && $if_cache >= time;
    %if_map = ();
    %if_index = ();
    @if_index = ();
    @if_list = ();
    @if6_list = ();
    @localhost = ();
    %localhost4 = ();
    %localhost6 = ();
    for my $if (interface_list(iflags_up)) {
	my $flags = $if->[ifitem_flags];
	$if_index{$if->[ifitem_name]} = $if->[ifitem_index];
	$if_index[$if->[ifitem_index]] = $if->[ifitem_name];
	if ($flags & iflags_broadcast) {
	    for my $ba (@{$if->[ifitem_broadcast]}) {
		push @if_list, [$if->[ifitem_name], $ba];
		$if_map{$ba} = $if->[ifitem_name];
	    }
	}
	if ($flags & iflags_multicast) {
	    push @if6_list, $if->[ifitem_name];
	}
	if ($flags & iflags_loopback) {
	    $localhost4{$_} = 0 for @{$if->[ifitem_address4]};
	}
	if ($ipv6) {
	    address_scope($_) == ifscope_node and $localhost6{$_} = 0
		for @{$if->[ifitem_address6]};
	}
    }
    if ($ipv6) {
	push @localhost, map { inet_ntop(&AF_INET6, $_) } sort keys %localhost6;
    }
    push @localhost, map { inet_ntoa($_) } sort keys %localhost4;
    @localhost or faint(SP_INTERNET, "localhost", "No local addresses?");
    $if_cache = time + 10;
}

sub _command {
    @_ == 2 || @_ == 3
	or croak "Usage: THEFT->_command(COMMAND [, ID])";
    my ($t, $cmd, $id) = @_;
    $t->_putline($cmd, $id);
    my $reply = $t->_getline($id);
    defined $reply or faint(SP_INTERNET, $t->{host}, "($cmd) Connection lost");
    $reply =~ /^2/ or faint(SP_INTERNET, $t->{host}, $reply);
    $reply;
}

sub _getlist {
    @_ == 1 || @_ == 2 or croak "Usage: THEFT->_getlist [(ID)]";
    my ($t, $id) = @_;
    my @list = ();
    while (1) {
	my $r = $t->_getline($id);
	defined $r or faint(SP_INTERNET, $t->{host}, "Connection lost");
	$r eq '.' and last;
	push @list, $r;
    }
    @list;
}

sub _open {
    my ($id, $sockhost, $peerhost, $close, $t) = @_;
    return "201 INTERNET (VICTIM) on $sockhost ($VERSION)";
}

sub _line {
    my ($server, $id, $close, $line, $t) = @_;
    if ($line =~ /^\s*(STEAL|SMUGGLE)\s+(\S+)/i) {
	my $code = $t->{code};
	return $code->(uc($1), $2, $id, $t, @{$t->{args}}, $t->{binary});
    } elsif ($line =~ /^\s*BINARY/i) {
	$t->{binary} = 1;
	return "252 Binary it is then";
    } elsif ($line =~ /^\s*HEX/i) {
	$t->{binary} = 2;
	return "252 Hex it is then";
    } elsif ($line =~ /^\s*THANKS/i) {
	$$close = 1;
	return "251 You are welcome";
    } else {
	return "550 Bad request";
    }
}

sub _close {
    my ($id, $t) = @_;
    # nothing to do here
}

sub pids {
    @_ == 1 || @_ == 2 or croak "Usage: THEFT->pids [(SERVER)]";
    my ($t, $server) = @_;
    # clean up cache
    _cleanup($t);
    my $id = undef;
    if (defined $server) {
	$id = $t->{server}->tcp_socket($server, $t->{port});
	$t->_getline($id);
    }
    $t->_command("CASE PID", $id);
    my @pids = map { /^(\d+)/ ? $1 : () } $t->_getlist($id);
    defined $id and $t->{server}->tcp_socket_close($id);
    @pids;
}

sub pids_and_ports {
    @_ == 1 || @_ == 2 or croak "Usage: THEFT->pids_and_ports [(SERVER)]";
    my ($t, $server) = @_;
    # clean up cache
    _cleanup($t);
    my $id = undef;
    if (defined $server) {
	# this function is only called by STEAL/SMUGGLE and if we get here
	# we'll want just a single pid, so if one is cached we'll use it
	if (exists $t->{known_pid}{$server}) {
	    my $known = $t->{known_pid}{$server};
	    my %pids = ($known->[1] => $known->[2]);
	    return %pids;
	}
	$id = $t->{server}->tcp_socket($server, $t->{port});
	$t->_getline($id);
    }
    $t->_command("CASE PID", $id);
    my %pids = map { /^(\d+)\b.*\b(\d+)\s*$/ ? ($1 => $2) : () } $t->_getlist($id);
    defined $id and $t->{server}->tcp_socket_close($id);
    %pids;
}

sub start_request {
    @_ == 5 or croak "Usage: THEFT->start_request(HOST, PID, PORT, TYPE)";
    my ($t, $host, $pid, $port, $type) = @_;
    $type = uc($type);
    $type eq 'STEAL' || $type eq 'SMUGGLE'
	or faint(SP_INTERNET, $host, "Invalid type $type");
    $t->{req_type} = $type;
    # clean up cache
    _cleanup($t);
    if (! defined $port) {
	# if the port is cached, use it, otherwise ask the remote theft server
	if (exists $t->{known_port}{$host}{$pid}) {
	    $port =  $t->{known_port}{$host}{$pid}[1];
	} else {
	    my $id = $t->{server}->tcp_socket($host, $t->{port});
	    $t->_getline($id);
	    $port = $t->_command("CASE PORT $pid", $id);
	    $t->{server}->tcp_socket_close($id);
	    $port =~ /^520/
		and faint(SP_INTERNET, $host, "No such PID $pid");
	    $port =~ /^2\d+\s+(\d+)/
		or faint(SP_INTERNET, $host, "Invalid reply $port");
	    $port = $1;
	}
    }
    my $request = $t->{server}->tcp_socket($host, $port);
    $t->_getline($request);
    # see if the binary protocol introduced in 1.-94.-2.3 is supported at
    # the other end; if not, it's OK, but we won't be able to support
    # the new features
    eval {
	$t->_putline('BINARY', $request);
	$t->_getline($request);
    };
    $t->{request} = $request;
    $t;
}

sub finish_request {
    @_ == 1 or croak "Usage: THEFT->end_request";
    my ($t) = @_;
    exists $t->{request} or faint(SP_INTERNET, $t->{host}, "Not in request");
    my $request = $t->{request};
    $t->_putline("THANKS", $request);
    $t->{server}->tcp_socket_close($request);
    delete $t->{request};
    $t;
}

sub request {
    @_ == 2 or croak "Usage: THEFT->request(REGISTER)";
    my ($t, $reg) = @_;
    exists $t->{req_type} or faint(SP_INTERNET, $t->{host}, "No TYPE");
    exists $t->{request} or faint(SP_INTERNET, $t->{host}, "Not in request");
    my $request = $t->{request};
    my $ok = $t->_command($t->{req_type} . ' ' . $reg, $request);
    $ok =~ /^250/ and return (undef, $t->_getlist($request));
    $ok =~ /^26([01])\s+(\d+)\s+(\d+)\b/i
	or faint(SP_INTERNET, $t->{host}, $ok);
    my ($hex, $len, $extra) = ($1, $2, $3);
    my $data = $t->{server}->write_binary($request, $len, 1);
    $hex and $data =~ s/([[:xdigit:]]{2})/chr(hex $1)/ge;
    return ($extra, $data);
}

sub is_localhost {
    my $addr;
    CHECK_ARGS: {
	if (@_ == 1) {
	    $addr = $_[0];
	    last CHECK_ARGS;
	}
	if (@_ == 2) {
	    if (is_object($_[0]) && $_[0]->isa(__PACKAGE__)) {
		$addr = $_[1];
		last CHECK_ARGS;
	    }
	}
	croak "Usage: [THEFT->] is_localhost(ADDRESS)";
    }
    _get_interfaces();
    my $pack = inet_aton($addr);
    $pack and return exists $localhost4{$pack};
    if ($ipv6) {
	$pack = inet_pton(&AF_INET6, $addr);
	$pack and return exists $localhost6{$pack};
    }
    faint(SP_INTERNET, $addr, "Can't figure out what this address is");
}

1;
