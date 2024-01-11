# test INTERcal NETworking -- theft server

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/INET t/05theft-server.t 1.-94.-2.3

use strict;
use warnings;

use Socket qw(pack_sockaddr_in IPPROTO_IPV6 IPV6_MULTICAST_LOOP IPV6_MULTICAST_IF IPV6_MULTICAST_HOPS);
use IO::Socket::INET;
use POSIX qw(WNOHANG);
use FindBin '$Bin';
use File::Spec::Functions;
use Language::INTERCAL::Theft '1.-94.-2.3';
use Language::INTERCAL::INET::Interface '1.-94.-2.3', qw(
    interface_list iflags_up iflags_multicast
    ifitem_flags ifitem_index ifitem_broadcast
    iflags_loopback iflags_broadcast iflags_multicast
);

if (-f 't/.skip-localhost') {
    print "1..0 # skipped: this test requires network to localhost\n";
    exit 0;
}

my $toplevel = @ARGV && $ARGV[0] eq 'toplevel';
my $net_tests = ! -f 't/.skip-network';
my $ipv6 = Language::INTERCAL::Server::has_ipv6();
if ($ipv6) {
    require Socket6;
    import Socket6 qw(inet_pton pack_sockaddr_in6);
    require IO::Socket::INET6;
}

# find interfaces for IPv4 broadcast and IPv6 multicast
my ($if4, $if6);
for my $if (interface_list(iflags_up)) {
    my $flags = $if->[ifitem_flags];
    if ($net_tests && ($flags & iflags_broadcast) && (! defined $if4 || ($flags & iflags_loopback))) {
	my $b = $if->[ifitem_broadcast];
	@$b and $if4 = $b->[0];
    }
    $net_tests && $ipv6 && ($flags & iflags_multicast) && (! defined $if6 || ($flags & iflags_loopback))
	and $if6 = $if->[ifitem_index];
}

my $server = Language::INTERCAL::Server->new;

use constant ALWAYS            =>  0;
use constant HAS_THEFT_PID     =>  1;
use constant HAS_THEFT_PORT    =>  2;
use constant HAS_THEFT_SOCKET  =>  4;
use constant HAS_VICTIM_PID    =>  8;
use constant HAS_VICTIM_PORT   => 16;

# on OpenBSD for some reason we fail to receive multicast packets with
# local scope, but global scope is fine: further investigation shows that
# when everybody else says "local" they treat is as "global" and vice versa,
# and we can't do much about that. Maybe we could donate a dictionary to
# the OpenBSD project.
# We use 32 bits of randomness in the group so different "make test"
# on the same host have less chance to interfere with each other
use constant MULTICAST_GROUP   => ($^O eq 'openbsd' ? 'ff1e::' : 'ff11::')
				. sprintf("%x", 1 + int(rand(65535))) . ':'
				. sprintf("%x", 1 + int(rand(65535)));
use constant MESSAGE           => 'The Magic Words are Squeamish Ossifrage';

my @tests = (
    # start a theft-server
    [ALWAYS,            'START',         \&start_theft],
    # test the theft-server itself
    [HAS_THEFT_PORT,    'CONNECT',       \&theft_connect],
    [HAS_THEFT_SOCKET,  'VICTIM',        \&theft_victim],
    [HAS_THEFT_SOCKET,  'CASE PID',      \&theft_case_pid],
    [HAS_THEFT_SOCKET,  'CASE PORT',     \&theft_case_port],
    [HAS_THEFT_SOCKET,  'DISCONNECT',    \&theft_disconnect],
    # now test queries, STEAL and SMUGGLE
    [HAS_THEFT_PORT,    'RUN',           \&victim_start],
    [HAS_VICTIM_PORT,   'CONNECT',       \&theft_connect],
    [HAS_THEFT_SOCKET,  'CASE PID',      \&victim_case_pid],
    [HAS_THEFT_SOCKET,  'CASE PORT',     \&victim_case_port],
    [HAS_THEFT_SOCKET,  'DISCONNECT',    \&theft_disconnect],
    [HAS_VICTIM_PORT,   'STEAL V4',      \&victim_steal, 'STEAL', '127.0.0.1'],
    [HAS_VICTIM_PORT,   'SMUGGLE V4',    \&victim_steal, 'SMUGGLE', '127.0.0.1'],
(defined $if4 ? (
    # test broadcasts
    [HAS_VICTIM_PORT,   'BROADCAST',     \&theft_broadcast, 0],
    [HAS_VICTIM_PORT,   'BROADCAST PID', \&theft_broadcast, 1],
) : ()),
(defined $if6 ? (
    # test multicasts
    [HAS_VICTIM_PORT,   'MULTICAST',     \&theft_multicast, 0],
    [HAS_VICTIM_PORT,   'MULTICAST PID', \&theft_multicast, 1],
) : ()),
($ipv6 ? (
    [HAS_VICTIM_PORT,   'STEAL V6',      \&victim_steal, 'STEAL', '::1'],
    [HAS_VICTIM_PORT,   'SMUGGLE V6',    \&victim_steal, 'SMUGGLE', '::1'],
) : ()),
    [HAS_VICTIM_PID,    'FINISH',        \&victim_stop],
    # stop the theft-server
    [HAS_THEFT_PID,     'STOP',          \&stop_theft],
);

my ($theft_port, $theft_pid, $theft_id, $victim_pid, $victim_port);

print "1..", scalar(@tests), "\n";
for my $test (@tests) {
    my ($started, $name, $code, @args) = @$test;
    if (($started & HAS_THEFT_PORT) && ! defined $theft_port) {
	print "not ok Cannot run test $name without a theft-server port\n";
	$toplevel or print STDERR "Cannot run test $name without a theft-server port\n";
    } elsif (($started & HAS_THEFT_PID) && ! defined $theft_pid) {
	print "not ok Cannot run test $name without a theft-server PID\n";
	$toplevel or print STDERR "Cannot run test $name without a theft-server PID\n";
    } elsif (($started & HAS_THEFT_SOCKET) && ! defined $theft_id) {
	print "not ok Cannot run test $name without a theft-server connection\n";
	$toplevel or print STDERR "Cannot run test $name without a theft-server connection\n";
    } elsif (($started & HAS_VICTIM_PID) && ! defined $victim_pid) {
	print "not ok Cannot run test $name without a victim PID\n";
	$toplevel or print STDERR "Cannot run test $name without a victim PID\n";
    } elsif (($started & HAS_VICTIM_PORT) && ! defined $victim_port) {
	print "not ok Cannot run test $name without a victim PORT\n";
	$toplevel or print STDERR "Cannot run test $name without a victim PORT\n";
    } else {
	eval { $code->(@args); };
	if ($@) {
	    print "not ok $@";
	    $toplevel or print STDERR "$@";
	} else {
	    print "ok\n";
	}
    }
}

exit 0;

sub start_theft {
    # server is in blib/script and we don't want to search for it or we may
    # get the wrong one
    open(SERVER, '-|', $^X,
		       (map { ('-I', $_) } @INC),
		       catfile($Bin, updir(), qw(blib script theft-server)),
		       qw(--port 0 --show-port --show-pid --linger 15),
		       $ipv6 ? ('--group', MULTICAST_GROUP) : ())
	or die "theft-server: $!\n";
    while (<SERVER>) {
	/^PID:\s*(\d+)\b/ and $theft_pid = $1;
	/^PORT:\s*(\d+)\b/ and $theft_port = $1;
    }
    if (! close SERVER) {
	$? == -1 and die "theft-server: $!\n";
	$? & 0x7f and die "theft-server terminated by signal " . ($? & 0x7f) . "\n";
	die "theft-server exited with status " . ($? >> 8) . "\n";
    }
    defined $theft_port or die "theft-server did not indicate listening port\n";
    defined $theft_pid or die "theft-server did not indicate its PID\n";
}

sub _stop {
    my ($pid, $name) = @_;
    my $retry = 0;
    while (kill 0, $pid) {
	waitpid $pid, WNOHANG;
	$retry > 30 and die "Don't seem to be able to stop $name\n";
	kill $retry < 5 ? 'TERM' : 'KILL', $pid;
	select undef, undef, undef, 0.1;
    }
}

sub stop_theft {
    _stop($theft_pid, 'theft-server');
    undef $theft_pid;
    undef $theft_port;
}

sub theft_connect {
    $theft_id = $server->tcp_socket('localhost', $theft_port);
    get_reply($theft_id);
}

sub theft_victim {
    command($theft_id, 'VICTIM', $$, 'ON PORT', 1);
}

sub theft_case_pid {
    command($theft_id, 'CASE PID');
    my @pids = get_list($theft_id);
    @pids == 1 && $pids[0] eq "$$ ON PORT 1"
	or die "theft-server reported invalid PIDs (@pids), I am $$\n";
}

sub theft_case_port {
    my $line = command($theft_id, 'CASE PORT', $$);
    $line =~ /^\d+\s+1\b/ or die "theft-server reported invalid port: $line\n";
}

sub theft_disconnect {
    command($theft_id, 'THANKS');
    $server->tcp_socket_close($theft_id);
    $theft_id = undef;
}

sub get_reply {
    my ($id) = @_;
    my $line = $server->write_in($id, 1);
    defined $line or die "No reply from theft-server\n";
    $line =~ /^2/ or die "Error from theft-server: $line\n";
    $line;
}

sub command {
    my ($id, @data) = @_;
    $server->read_out($id, join(' ', @data));
    get_reply($id);
}

sub get_list {
    my ($id) = @_;
    my @list;
    while (1) {
	my $line = $server->write_in($id, 1);
	defined $line or die "Missing list in reply from theft-server\n";
	$line eq '.' and last;
	$line =~ s/^\.//;
	push @list, $line;
    }
    @list;
}

sub victim_start {
    $victim_pid = open(VICTIM, '-|');
    defined $victim_pid or die "Cannot start victim process: $!\n";
    if ($victim_pid) {
	my $line = <VICTIM>;
	if (defined $line && $line =~ /^(\d+)\s+(\d+)\b/) {
	    $victim_pid = $1;
	    $victim_port = $2;
	    return;
	}
	chomp $line;
	die "Invalid reply from victim process: $line\n";
    }
    # if we get here we are the victim process
    undef $server;
    # we are called in an eval from the parent... if we have an exception
    # the perl interpreter will be very confused; so we have another eval
    eval {
	my $srv = Language::INTERCAL::Server->new;
	my $theft = Language::INTERCAL::Theft->_new(
	    $srv,
	    $theft_port,
	    $ipv6 ? [ [inet_pton(AF_INET6, MULTICAST_GROUP), 0] ] : [],
	    [(0) x 16],
	    sub {
		# steal/smuggle callback
		my ($op, $reg, $id) = @_;
		return "200 $op $reg";
	    },
	    undef,
	);
	my $myport = $theft->victim_port;
	$| = 1;
	print "$$ $myport\n";
	close STDOUT;
	# now pretend to be a happy program
	while (1) {
	    $srv->progress;
	}
    };
    $@ and print STDERR $@;
    exit $@ ? 1 : 0;
}

sub victim_case_pid {
    command($theft_id, 'CASE PID');
    my @pids = get_list($theft_id);
    @pids == 1 && $pids[0] =~ /^$victim_pid ON PORT (\d+)\b/
	or die "theft-server reported invalid PIDs (@pids)\n";
    $victim_port = $1;
}

sub victim_case_port {
    my $line = command($theft_id, 'CASE PORT', $victim_pid);
    $line =~ /^\d+\s+$victim_port\b/ or die "theft-server reported invalid port: $line\n";
}

sub victim_stop {
    _stop($victim_pid, 'victim');
    undef $victim_pid;
    undef $victim_port;
}

sub victim_steal {
    my ($op, $addr) = @_;
    local $SIG{ALRM} = sub { die "Timeout talking to $addr\n"; };
    alarm 2;
    eval {
	my $id = $server->tcp_socket($addr, $victim_port);
	get_reply($id);
	my $line = command($id, $op, ':1');
	$line =~ /^\d+\s+(\S+)\s+:1\b/ && $1 eq $op
	    or die "Invalid reply when ${op}ing :1: $line\n";
	command($id, 'THANKS');
	$server->tcp_socket_close($id);
    };
    alarm 0;
    $@ and die $@;
}

sub find {
    my ($what, $socket, $pid) = @_;
    my $data = '';
    local $SIG{ALRM} = sub { die "Timeout waiting for $what\n"; };
    alarm 2;
    eval {
	$socket->recv($data, 100, 0)
	    or die "Receiving answer to $what: $!\n";
	my $expected = $pid
		     ? "$victim_pid " . MESSAGE . " $victim_port"
		     : MESSAGE . " $victim_pid $victim_port";
	$data eq $expected
	    or die "Wrong reply received in answer to $what expected ($expected) received ($data)\n";
    };
    alarm 0;
    $@ and die $@;
    undef $socket;
}

sub theft_broadcast {
    my ($pid) = @_;
    my $socket = IO::Socket::INET->new(
	PeerPort  => $theft_port,
	Proto     => 'udp',
	Type      => SOCK_DGRAM,
	Broadcast => 1,
	ReuseAddr => 1,
	Domain    => AF_INET,
    ) or die "Socket($theft_port/udp); $!\n";
    my $request = $pid ? "$victim_pid " : '';
    defined $socket->send($request . MESSAGE, 0, pack_sockaddr_in($theft_port, $if4))
	or die "Sending broadcast to $theft_port: $!\n";
    find('broadcast', $socket, $pid);
}

sub theft_multicast {
    my ($pid) = @_;
    my $socket = IO::Socket::INET6->new(
	PeerPort  => $theft_port,
	Proto     => 'udp',
	Type      => SOCK_DGRAM,
	ReuseAddr => 1,
	Domain    => AF_INET6,
    ) or die "Socket($theft_port/udp); $!\n";
    setsockopt($socket, IPPROTO_IPV6, IPV6_MULTICAST_LOOP, pack("I", 1));
    setsockopt($socket, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, pack("I", 0));
    setsockopt($socket, IPPROTO_IPV6, IPV6_MULTICAST_IF, pack('I', $if6));
    my $request = $pid ? "$victim_pid " : '';
    defined $socket->send($request . MESSAGE, 0,
			  pack_sockaddr_in6($theft_port, inet_pton(AF_INET6, MULTICAST_GROUP)))
	or die "Sending multicast to $theft_port: $!\n";
    find('multicast', $socket, $pid);
}

