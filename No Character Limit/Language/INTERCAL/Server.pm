package Language::INTERCAL::Server;

# INTERNET (INTERcal NETworking) server

# This file is part of CLC-INTERCAL

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Server.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Socket;
use IO::Socket::INET;
my ($ip_class, $ipv6);
BEGIN {
    $ip_class = 'IO::Socket::INET';
    $ipv6 = 0;
    eval {
	require Socket6;
	import Socket6 qw(inet_ntop);
	require IO::Socket::INET6;
	import Socket qw(IPPROTO_IPV6 IPV6_JOIN_GROUP);
	$ip_class = 'IO::Socket::INET6';
	$ipv6 = 1;
    };
}
use Getopt::Long;
use Carp;
use Language::INTERCAL::Splats '1.-94.-2', qw(faint SP_INTERNET);

sub has_ipv6 {
    wantarray ? ($ipv6, $ip_class) : $ipv6;
}

# note we are not assuming the perl interpreter is threaded - a future release
# may have two versions of the server, one threaded and one unthreaded, but for
# now we just have the unthreaded one - using select and friends to avoid
# deadlocks when we are doing things like stealing from self.

sub new {
    @_ == 1 or croak "Usage: Language::INTERCAL::Server->new";
    my ($class) = @_;
    bless {
	write_in_bitmap => '',
	read_out_bitmap => '',
	tcp_listen => {},
	tcp_socket => {},
	udp_listen => {},
	file_listen => {},
	children => {},
	debug => 0,
	active => time,
    }, $class;
}

sub debug {
    @_ == 1 or croak "Usage: SERVER->debug";
    my ($server) = @_;
    $server->{debug} = 1;
}

sub file_listen {
    @_ == 3 or croak "Usage: SERVER->file_listen(ID, CALLBACK)";
    my ($server, $id, $code) = @_;
    $server->{file_listen}{$id} = $code;
    vec($server->{write_in_bitmap}, $id, 1) = 1;
    $server;
}

sub file_listen_close {
    @_ == 2 or croak "Usage: SERVER->file_listen_close(ID)";
    my ($server, $id) = @_;
    exists $server->{file_listen}{$id}
	or croak "file_listen_close: unknown ID";
    delete $server->{file_listen}{$id};
    vec($server->{write_in_bitmap}, $id, 1) = 0;
    $server;
}

sub tcp_listen {
    @_ == 5 || @_ == 6
	or croak "Usage: SERVER->tcp_listen(OPEN, LINE, CLOSE, ARG [, PORT])";
    my ($server, $open, $line, $close, $arg, $port) = @_;
    my @port = $port ? (LocalPort => $port) : ();
    my @has_socket = ();
    my $err;
    if ($ipv6) {
	# some systems require separate IPv4 and IPv6 sockets
	my $sock6 = $ip_class->new(
	    @port,
	    Listen    => 128,
	    Proto     => 'tcp',
	    Type      => SOCK_STREAM,
	    ReuseAddr => 1,
	    Domain    => &AF_INET6,
	);
	if ($sock6) {
	    my $fn6 = fileno($sock6);
	    $server->{tcp_listen}{$fn6} = [$sock6, $open, $line, $close, $arg];
	    vec($server->{write_in_bitmap}, $fn6, 1) = 1;
	    push @has_socket, 'IPv6';
	    $port = $sock6->sockport;
	    @port = (LocalPort => $port);
	} else {
	    $err = $!;
	}
    }
    my $sock4 = $ip_class->new(
	@port,
	Listen    => 128,
	Proto     => 'tcp',
	Type      => SOCK_STREAM,
	ReuseAddr => 1,
	Domain    => &AF_INET,
    );
    if ($sock4) {
	my $fn4 = fileno($sock4);
	$server->{tcp_listen}{$fn4} = [$sock4, $open, $line, $close, $arg];
	vec($server->{write_in_bitmap}, $fn4, 1) = 1;
	unshift @has_socket, 'IPv4';
	$port = $sock4->sockport;
	@port = (LocalPort => $port);
    } elsif (! $err) {
	$err = $!;
    }
    @has_socket or die "Listening on port $port: $err\n";
    $server->{debug} and print STDERR "Listening on TCP port $port (", join(' and ', @has_socket), ")\n";
    $port;
}

sub tcp_socket {
    @_ == 3 or croak "Usage: SERVER->tcp_socket(HOST, PORT)";
    my ($server, $host, $port) = @_;
    my $socket = $ip_class->new(
	PeerAddr   => $host,
	PeerPort   => $port,
	Proto      => 'tcp',
	Type       => SOCK_STREAM,
	Blocking   => 1,
	MultiHomed => 1,
    ) or faint(SP_INTERNET, "$host:$port", $!);
    # IO::Socket::INET6 returns a real socket, but without connecting, if MultiHomed is 1;
    # looking at the sources, there's a missing check for connection error, so no surprise
    # it doesn't work correctly; yes, I could send a bug report, but can't assume that
    # everybody will have a working version... however there's a workaround:
    my $error = $!; # save last error from inside $ip_class->new()
    defined $socket->peerhost() or faint(SP_INTERNET, "$host:$port", $error);
    my $fn = fileno($socket);
    $server->{tcp_socket}{$fn} = [$socket, '', '', 0, 0];
    vec($server->{write_in_bitmap}, $fn, 1) = 1;
    $server->{debug} and print STDERR "Connected to $host:$port\n";
    $fn;
}

sub udp_listen {
    @_ == 3 || @_ == 5
	or croak "Usage: SERVER->udp_listen(CALLBACK, PORT, [MC_GROUPS, IFINDEX])";
    my ($server, $callback, $port, $mc_groups, $ifindex) = @_;
    my $pp = $port ? " on $port" : '';
    my @has_socket = ();
    my $err;
    if ($ipv6) {
	# some system require separate IPv6 and IPv4 listening sockets
	my $sock6 = $ip_class->new(
	    LocalPort => $port,
	    Proto     => 'udp',
	    Type      => SOCK_DGRAM,
	    ReuseAddr => 1,
	    Domain    => &AF_INET6,
	);
	if ($sock6) {
	    my $fn6 = fileno($sock6);
	    $server->{udp_listen}{$fn6} = [&AF_INET6, $sock6, $port, $callback];
	    vec($server->{write_in_bitmap}, $fn6, 1) = 1;
	    push @has_socket, 'IPv6';
	} else {
	    $err = $!;
	}
	if ($mc_groups) {
	    # join any requested multicast groups on the IPv6 socket;
	    # the group is provided as a packed 128-bit address - note,
	    # not as a 128-bit number forced into a 32-bit register using
	    # a very large hammer, because that requires the INET extension
	    $sock6 or die "Cannot listen on MC groups, no IPv6 socket: $err\n";
	    $ifindex ||= [0];
	    for my $group (@$mc_groups) {
		length($group) == 16 or die "Invalid MC group\n";
		for my $if (@$ifindex)  {
		    # there doesn't appear to be a "pack" function for this
		    # but the struct is the in6_addr followed by the
		    # interfce index in local byte order (not network);
		    # Linux wants this an "int" and NetBSD an "unsigned int"
		    # which makes more sense as the index is never negative;
		    # we use an unsigned int here
		    my $mreq = $group . pack('I', $if);
		    setsockopt($sock6, &IPPROTO_IPV6, &IPV6_JOIN_GROUP, $mreq)
			or die "Listening on " . inet_ntop(&AF_INET6, $group) . ", if=$if: $!\n";
		}
	    }
	}
    }
    my $sock4 = $ip_class->new(
	LocalPort => $port,
	Proto     => 'udp',
	Type      => SOCK_DGRAM,
	ReuseAddr => 1,
	Domain    => &AF_INET,
    );
    if ($sock4) {
	my $fn4 = fileno($sock4);
	$server->{udp_listen}{$fn4} = [&AF_INET, $sock4, $port, $callback];
	vec($server->{write_in_bitmap}, $fn4, 1) = 1;
	unshift @has_socket, 'IPv4';
    } elsif (! $err) {
	$err = $!;
    }
    @has_socket or die "Listening on port $port: $err\n";
    $server->{debug} and print STDERR "Listening on UDP port $port (", join(' and ', @has_socket), ")\n";
    $port;
}

sub read_out {
    @_ > 2 or croak "Usage: SERVER->read_out(ID, DATA)";
    my ($server, $fn, @data) = @_;
    my $data = join('', map { "$_\015\012" } @data);
    _read($server, $fn, $data);
    $server;
}

sub read_binary {
    @_ > 2 or croak "Usage: SERVER->read_binary(ID, DATA)";
    my ($server, $fn, @data) = @_;
    my $data = join('', @data);
    _read($server, $fn, $data);
    $server;
}

sub _read {
    my ($server, $fn, $data) = @_;
    if (exists $server->{tcp_socket}{$fn}) {
	$server->{tcp_socket}{$fn}[1] .= $data;
    } elsif (exists $server->{children}{$fn}) {
	$server->{children}{$fn}[1] .= $data;
    } else {
	croak "No such ID: $fn";
    }
    vec($server->{read_out_bitmap}, $fn, 1) = 1;
}

sub alternate_callback {
    @_ == 4 or croak "Usage: SERVER->alternate_callback(ID, SIZE, CODE)";
    my ($server, $fn, $size, $code) = @_;
    exists $server->{children}{$fn} or croak "No such ID";
    $server->{children}{$fn}[8] = [$size, $code];
    $server;
}

sub write_in {
    @_ == 2 || @_ == 3
	or croak "Usage: SERVER->write_in(ID [, PROGRESS])";
    my ($server, $fn, $progress) = @_;
    exists $server->{tcp_socket}{$fn} or croak "No such ID";
    my $data = $server->{tcp_socket}{$fn};
    if ($data->[2] =~ s/^(.*?)\012//) {
	my $line = $1;
	$line =~ s/\015$//;
	return $line;
    }
    if ($data->[4]) {
	my $line = $data->[2];
	$data->[2] = '';
	return $line;
    }
    $progress or return undef;
    while (1) {
	$server->progress;
	exists $server->{tcp_socket}{$fn} or return undef;
	if ($data->[2] =~ s/^(.*?)\012//) {
	    my $line = $1;
	    $line =~ s/\015$//;
	    return $line;
	}
	if ($data->[4]) {
	    my $line = $data->[2];
	    $data->[2] = '';
	    return $line;
	}
    }
}

sub write_binary {
    @_ == 3 || @_ == 4
	or croak "Usage: SERVER->write_binary(ID, SIZE [, PROGRESS])";
    my ($server, $fn, $size, $progress) = @_;
    exists $server->{tcp_socket}{$fn} or croak "No such ID";
    my $data = $server->{tcp_socket}{$fn};
    if (length($data->[2]) >= $size || ! $progress || $data->[4]) {
	return substr($data->[2], 0, $size, '');
    }
    while (1) {
	$server->progress;
	exists $server->{tcp_socket}{$fn} or return undef;
	if (length($data->[2]) >= $size || $data->[4]) {
	    return substr($data->[2], 0, $size, '');
	}
    }
}

sub data_count {
    @_ == 2 || @_ == 3
	or croak "Usage: SERVER->data_count(ID [, PROGRESS])";
    my ($server, $fn, $progress) = @_;
    exists $server->{tcp_socket}{$fn} or return undef;
    my $data = $server->{tcp_socket}{$fn};
    index($data->[2], "\012") >= 0 and return 1;
    $progress or return 0;
    while (1) {
	$server->progress;
	exists $server->{tcp_socket}{$fn} or return undef;
	index($data->[2], "\012") >= 0 and return 1;
    }
}

sub tcp_socket_close {
    @_ == 2 or croak "Usage: SERVER->tcp_socket_close(ID)";
    my ($server, $fn) = @_;
    exists $server->{tcp_socket}{$fn} or return undef;
    _close_id($server, $fn, time);
}

sub progress {
    @_ == 1 || @_ == 2
	or croak "Usage: SERVER->progress [(TIMEOUT)]";
    my ($server, $timeout) = @_;
    while (1) {
	my $wibm = $server->{write_in_bitmap};
	my $robm = $server->{read_out_bitmap};
	my $ebm = $wibm | $robm;
	my $nfound = select $wibm, $robm, $ebm, $timeout;
	$nfound > 0 or return $server;
	$@ = '';
	eval {
	    $timeout = 0.01;
	    my $debug = $server->{debug};
	    my $now = time;
	    # file activity?
	    for my $fid (keys %{$server->{file_listen}}) {
		vec($wibm, $fid, 1) or next;
		&{$server->{file_listen}{$fid}}();
	    }
	    # are they opening a new connection?
	    for my $tcp (keys %{$server->{tcp_listen}}) {
		vec($wibm, $tcp, 1) or next;
		my ($tcp_listen, $ocode, $lcode, $ccode, $arg) =
		    @{$server->{tcp_listen}{$tcp}};
		my $sock = $tcp_listen->accept;
		if ($sock) {
		    $sock->blocking(0);
		    my $child = fileno $sock;
		    my $sockhost = $sock->sockhost;
		    $sockhost =~ s/^::ffff\:(\d+(?:\.\d+){0,3})$/$1/;
		    my $peerhost = $sock->peerhost;
		    $peerhost =~ s/^::ffff\:(\d+(?:\.\d+){0,3})$/$1/;
		    my $close = 0;
		    # make sure we don't get back into this bit of code if
		    # the callback happens to call progress()
		    vec($server->{write_in_bitmap}, $tcp, 1) = 0;
		    my @w = $ocode->($child, $sockhost, $peerhost, \$close, $arg);
		    vec($server->{write_in_bitmap}, $tcp, 1) = 1;
		    $peerhost .= ':' . $sock->peerport;
		    $debug
			and print STDERR "$now:$peerhost: accepting connection\n";
		    my $w = join('', map { "$_\015\012" } @w);
		    $server->{children}{$child} =
			[$sock, $w, '', $peerhost, $close, $lcode, $ccode, $arg, 0];
		    vec($server->{read_out_bitmap}, $child, 1) = 1 if @w;
		    vec($server->{write_in_bitmap}, $child, 1) = 1;
		    $server->{active} = $now;
		}
	    }
	    # any UDP packets?
	    my %seen;
	    for my $udp (keys %{$server->{udp_listen}}) {
		vec($wibm, $udp, 1) or next;
		my ($family, $udp_listen, $port, $callback) = @{$server->{udp_listen}{$udp}};
		my $x = '';
		my $them = $udp_listen->recv($x, 256, 0);
		# we seem to receive duplicates, same sender, same data different
		# incoming socket: this is probably because we receive some
		# multicasts over many interfaces, or because we get IPv4 packets
		# via IPv6 sockets too. So we decode the address/port and check
		my ($theirport, $theirip);
		if ($family == &AF_INET6) {
		    ($theirport, $theirip) = unpack_sockaddr_in6($them);
		} else {
		    ($theirport, $theirip) = unpack_sockaddr_in($them);
		}
		if ($ipv6) {
		    $theirip = eval { inet_ntop($family, $theirip) };
		    defined $theirip or $theirip = '(unknown)';
		    $theirip =~ s/^::ffff\:(\d+(?:\.\d+){0,3})$/$1/i
		} else {
		    $theirip = eval { inet_ntoa($theirip) };
		    defined $theirip or $theirip = '(unknown)';
		}
		exists $seen{$theirip}{$theirport}{$x} and next;
		$seen{$theirip}{$theirport}{$x} = 1;
		$debug and print STDERR "$now:$theirip:$theirport: received ($x)\n";
		# make sure we don't get back into this bit of code if the callback
		# happens to call progress()
		vec($server->{write_in_bitmap}, $udp, 1) = 0;
		$callback->($udp_listen, $port, $them, $theirip, $theirport, $x);
		vec($server->{write_in_bitmap}, $udp, 1) = 1;
		$server->{active} = $now;
	    }
	    for my $child (keys %{$server->{children}}) {
		if (vec($ebm, $child, 1)) {
		    # closed connections?
		    _close_child($server, $child, $now);
		} elsif (vec($robm, $child, 1) || vec($wibm, $child, 1)) {
		    my ($sock, $out, $in, $peerhost, $close,
			$lcode, $ccode, $arg, $alternate) =
			    @{$server->{children}{$child}};
		    if (vec($robm, $child, 1)) {
			# send data out
			my $len = syswrite $sock, $out;
			if (! defined $len) {
			    $close or faint(SP_INTERNET, $peerhost, $!);
			    $len = 0;
			    $out = '';
			}
			if ($debug) {
			    my $done = substr($out, 0, $len, '');
			    $done =~ s/\\/\\\\/g;
			    $done =~ s/\015\012/\\n/g;
			    $done =~ s/([\000-\037])/sprintf("\\%03o", $1)/ge;
			    print STDERR "$now:$peerhost> $done\n";
			} else {
			    substr($out, 0, $len) = '';
			}
			$server->{children}{$child}[1] = $out;
			$server->{active} = $now;
			if ($out eq '') {
			    if ($close) {
				_close_child($server, $child, $now);
				next;
			    } else {
				vec($server->{read_out_bitmap}, $child, 1) = 0;
			    }
			}
		    }
		    if (vec($wibm, $child, 1)) {
			# get new data in
			my $line = '';
			if (sysread($sock, $line, 1024)) {
			    $in .= $line;
			    if ($debug) {
				$line =~ s/\\/\\\\/g;
				$line =~ s/\015\012/\\n/g;
				$line =~ s/([\000-\037])/sprintf("\\%03o", $1)/ge;
				print STDERR "$now:$peerhost< $line\n";
			    }
			    my $ptr = $server->{children}{$child};
			    $server->{active} = $now;
			    PROCESS:
			    while ($in ne '') {
				# note that this can be changed inside the callback,
				# which is why we don't use $alternate
				my @w = ();
				if ($ptr->[8]) {
				    # alternate callback in operation
				    my ($size, $code) = @{$ptr->[8]};
				    length($in) < $size && ! $ptr->[4]
					and last PROCESS;
				    my $data = $in eq '' ? undef : substr($in, 0, $size, '');
				    $ptr->[8] = 0;
				    # make sure we don't get back into this bit of code if
				    # the callback calls progress()
				    vec($server->{write_in_bitmap}, $child, 1) = 0;
				    @w = $code->($data);
				    vec($server->{write_in_bitmap}, $child, 1) = 1;
				} elsif ($in =~ s/^(.*?)\012//) {
				    $line = $1;
				    $line =~ s/\015$//;
				    $debug and print STDERR "$now:$peerhost<< $line\n";
				    # make sure we don't get back into this bit of code if
				    # the callback calls progress()
				    vec($server->{write_in_bitmap}, $child, 1) = 0;
				    @w = $lcode->($server, $child, \$close, $line, $arg);
				    vec($server->{write_in_bitmap}, $child, 1) = 1;
				    if ($close) {
					$ptr->[4] = 1;
					vec($server->{write_in_bitmap}, $child, 1) = 0;
				    }
				} else {
				    last PROCESS;
				}
				if (@w) {
				    my $w = join('', map { "$_\015\012" } @w);
				    $ptr->[1] .= $w;
				    vec($server->{read_out_bitmap}, $child, 1) = 1;
				}
			    }
			    $ptr->[2] = $in;
			} else {
			    _close_child($server, $child, $now);
			}
		    }
		}
	    }
	    for my $id (keys %{$server->{tcp_socket}}) {
		if (vec($ebm, $id, 1)) {
		    # closed connections?
		    $server->{tcp_socket}[4] = 1;
		    vec($server->{write_in_bitmap}, $id, 1) = 0;
		} else {
		    my ($sock, $out, $in, $peerhost, $close) =
			@{$server->{tcp_socket}{$id}};
		    if (vec($robm, $id, 1)) {
			# send data out
			my $len = syswrite $sock, $out;
			if (! defined $len) {
			    $close or faint(SP_INTERNET, $peerhost, $!);
			    $len = 0;
			    $out = '';
			}
			if ($debug) {
			    my $done = substr($out, 0, $len, '');
			    $done =~ s/\\/\\\\/g;
			    $done =~ s/\015\012/\\n/g;
			    $done =~ s/([\000-\037])/sprintf("\\%03o", ord($1))/ge;
			    print STDERR "$now:$peerhost> $done\n";
			} else {
			    substr($out, 0, $len) = '';
			}
			$server->{tcp_socket}{$id}[1] = $out;
			$server->{active} = $now;
			if ($out eq '') {
			    vec($server->{read_out_bitmap}, $id, 1) = 0;
			    _close_id($server, $id, $now) if $close;
			}
		    }
		    if (vec($wibm, $id, 1)) {
			# get new data in
			my $line = '';
			if (sysread($sock, $line, 1024)) {
			    $in .= $line;
			    if ($debug) {
				$line =~ s/\\/\\\\/g;
				$line =~ s/\015\012/\\n/g;
				$line =~ s/([\000-\037])/sprintf("\\%03o", ord($1))/ge;
				print STDERR "$now:$peerhost< $line\n";
			    }
			    $server->{tcp_socket}{$id}[2] = $in;
			} else {
			    $server->{tcp_socket}{$id}[4] = 1;
			    vec($server->{write_in_bitmap}, $id, 1) = 0;
			}
			$server->{active} = $now;
		    }
		}
	    }
	};
	$@ and die $@;
    }
}

sub active {
    @_ == 1 or croak "Usage: SERVER->active";
    my ($server) = @_;
    $server->{active};
}

sub connections {
    @_ == 1 or croak "Usage: SERVER->connections";
    my ($server) = @_;
    scalar %{$server->{children}};
}

sub _close_child {
    my ($server, $child, $now) = @_;
    my ($sock, $out, $in, $peerhost, $close, $lcode, $ccode, $arg) =
	@{$server->{children}{$child}};
    $server->{debug} and print STDERR "$now:$peerhost: closing connection\n";
    vec($server->{write_in_bitmap}, $child, 1) = 0;
    vec($server->{read_out_bitmap}, $child, 1) = 0;
    $ccode->($child, $arg);
    close $sock;
    delete $server->{children}{$child};
}

sub _close_id {
    my ($server, $id, $now) = @_;
    my ($sock, $out, $in, $peerhost, $close) = @{$server->{tcp_socket}{$id}};
    $server->{debug} and print STDERR "$now:$peerhost: closing connection\n";
    vec($server->{write_in_bitmap}, $id, 1) = 0;
    vec($server->{read_out_bitmap}, $id, 1) = 0;
    close $sock;
    delete $server->{tcp_socket}{$id};
}

1;
