package Language::INTERCAL::INET::Extend;

# extend bytecode, interpreter, splats and RC information for INTERNET code

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use Carp;
use Fcntl qw(SEEK_SET SEEK_END);
use Language::INTERCAL::ByteCode '1.-94.-2.2',
    qw(bc_skip BC_GUP bytename BCget);
use Language::INTERCAL::Registers '1.-94.-2.2', qw(
    REG_spot REG_twospot REG_tail REG_hybrid REG_whp REG_dos DOS_AR DOS_IO
    reg_decode reg_nametype
);
use Language::INTERCAL::Splats '1.-94.-2.1',
    qw(faint SP_INTERNET SP_INTERNAL SP_SPECIAL SP_NODIM SP_SPOTS SP_ISSPECIAL);
use Language::INTERCAL::Server '1.-94.-2.1';
use Language::INTERCAL::Theft '1.-94.-2.3';
use Language::INTERCAL::Exporter '1.-94.-2';
use Language::INTERCAL::Interpreter '1.-94.-2.3',
    qw(reg_value reg_ignore reg_overload thr_ab_gerund thr_bytecode thr_opcode thr_registers);
use Language::INTERCAL::Interpreter::State '1.-94.-2.3',
    qw(encode_register clear_register register_extra decode_register);
use Language::INTERCAL::Numbers '1.-94.-2.2',
    qw(n_interleave n_uninterleave);
use Language::INTERCAL::ArrayIO '1.-94.-2.2', qw(read_array_16 read_array_32);
use Language::INTERCAL::Arrays '1.-94.-2.2',
    qw(make_array list_subscripts forall_elements set_element make_list partial_replace_array array_elements);
use Language::INTERCAL::Time '1.-94.-2.3', qw(current_time);
use Language::INTERCAL::INET::Interface '1.-94.-2.3', qw(address_multicast6);

use vars qw($VERSION $PERVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/INET INTERCAL/INET/Extend.pm 1.-94.-2.3") =~ /\s(\S+)$/;
@EXPORT_OK = qw(theft_server theft_default_server theft_callback);

my ($ipv6, $ip_class);
BEGIN {
    ($ipv6, $ip_class) = Language::INTERCAL::Server::has_ipv6();
    if ($ipv6) {
	import Socket qw(AF_INET6);
	import Socket6 qw(inet_pton inet_ntop);
    }
}

# our splats
use constant SP_CASE     => 900;
use constant SP_IPV6     => 901;
use constant SP_NONET    => 902;

# our opcodes
use constant BC_STE      =>  45;
use constant BC_SMU      =>  46;
use constant BC_CSE      =>  47;

# our register
use constant DOS_TH      =>  20;

my ($theft_default_server);

sub add_callback {
    my ($code, $ext, $module) = @_;
    $code->('new', \&_cb_new);
    $code->('run', \&_cb_run);
}

sub add_splat {
    my ($code, $ext, $module) = @_;
    $code->(SP_CASE, 'CASE', 'Implicit or explicit CASE failed: %');
	# A problem was encountered while looking for other INTERCAL
	# systems.
    $code->(SP_IPV6, 'IPV6', 'IPv6 Address Translation Problem: %');
	# The IPv6 Address Translation Table is full, or something
	# unexpected happened during the translation.
    $code->(SP_NONET, 'NONET', 'This program is not allowed to % or use the network');
	# The program is not talking to a theft server
}

sub add_opcode {
    my ($code, $ext, $module) = @_;
    $code->(BC_STE, 'STE', 'S', 'C(E)C(E)C(R)', 'STEal', \&_s_STE);
	# Followed by a count, I<count> expression, a second count, the
	# corresponding number of expressions, a third count and the
	# corresponding number of registers, defines a STEAL statement:
	# the first two counts should be #0 or #1, representing the presence
	# or absence of ON and FROM, respectively.
    $code->(BC_SMU, 'SMU', 'S', 'C(E)C(E)C(R)', 'SMUggle', \&_s_SMU);
	# Takes the same arguments as I<STE>, but defines a SMUGGLE statement.
    $code->(BC_CSE, 'CSE', 'S', 'EC(ES)', 'CaSE', \&_s_CSE);
	# Followed by an expression, a count and I<count> pairs of (expression,
	# statement), defines a CASE statement.
}

sub add_register {
    my ($code, $ext, $module) = @_;
    $code->('TH', '%', 'zeroone', DOS_TH, 0);
	# This register determines whether a program has been compiled
	# with INTERNET support. If the register is #0, the program
	# cannot be a victim of theft, but cannot steal or smuggle
	# anything; if the register is #1, the program has full network
	# support. If the register does not exist, the program will
	# splat trying to access it, but in any case would splat when
	# trying any network operation.
}

sub add_rcdef {
    my ($code, $ext, $module) = @_;
    $code->('BLURT', \&_c_blurt, undef, 0, 0, 'Default INETERNET port');
    $code->('READ', \&_c_read, \&_p_read, 1, 0, 'Default IPv6 multicast groups');
    $code->('THROW', \&_c_throw, \&_p_throw, 1, 0, 'Default IPv6 multicast hop limits');
}

sub _c_blurt {
    my ($rc, $mode, $ln) = @_;
    # port 0 means disable INTERNET functionality so we allow it
    $ln =~ /^(\d+)\s*$/ && $1 >= 0 && $1 < 0x10000 and return $1;
    die "Invalid value for $mode\: $ln\n";
}

sub _c_read {
    my ($rc, $mode, $ln) = @_;
    $ipv6 or return ''; # we won't be using this...
    my $limit;
    if ($ln =~ s/\b\s*THROWING\s*(\d+)\s*$//i) {
	$limit = $1;
	$limit >= 0 && $limit <= 255 or die "Invalid multicast hop limit: $limit\n";
    }
    my $v = inet_pton(&AF_INET6, $ln);
    defined $v or die "Invalid IPv6 address: $ln\n";
    address_multicast6($v) or die "Not a multicast address: $ln\n";
    [$v, $limit];
}

sub _p_read {
    my ($value) = @_;
    my ($addr, $limit) = @$value;
    my $prn = inet_ntop(&AF_INET6, $addr);
    defined $limit and $prn .= " THROWING $limit";
    $prn;
}

sub _c_throw {
    my ($rc, $mode, $ln) = @_;
    $ipv6 or return ''; # we won't be using this...
    my $scope;
    if ($ln =~ s/\b\s*TO\s*(\d+)\s*$//i) {
	$scope = $1;
	$scope >= 0 && $scope <= 15 or die "Invalid multicast scope: $scope\n";
    }
    $ln =~ /^\s*(\d+)\s*$/ && $1 >= 0 && $1 <= 255 or die "Invalid multicast hop limit: $ln\n";
    [$1, $scope];
}

sub _p_throw {
    my ($value) = @_;
    my ($limit, $scope) = @$value;
    defined $scope and $limit .= " TO $scope";
    $limit;
}

sub _add_server {
    my ($int) = @_;
    my $th = $int->{default}[thr_registers][REG_dos][DOS_TH];
    ! ($int->{compiling} & 1) && $th->[reg_value] or return;
    $int->{server} ||= Language::INTERCAL::Server->new;
    $theft_default_server ||=
	Language::INTERCAL::Theft->new($int->{server}, $int->{rc}, \&_theft, $int);
    $int->{theft_server} ||= $theft_default_server;
}

sub _cb_new {
    my ($int) = @_;
    $int->{theft_server} = $theft_default_server;
    $int->{theft_callback} = 0;
}

sub _cb_run {
    my ($int) = @_;
    _add_server($int);
}

# INTERPRETER functions we need
BEGIN {
    *_create_register = \&Language::INTERCAL::Interpreter::_create_register;
    *_run_e = \&Language::INTERCAL::Interpreter::_run_e;
    *_get_number = \&Language::INTERCAL::Interpreter::_get_number;
    *_run_a = \&Language::INTERCAL::Interpreter::_run_a;
    *_run_r = \&Language::INTERCAL::Interpreter::_run_r;
    *_run_s = \&Language::INTERCAL::Interpreter::_run_s;
    *_set_read_charset = \&Language::INTERCAL::Interpreter::_set_read_charset;
}

sub _theft {
    my ($what, $reg, $id, $theft, $int, $binary) = @_;
    my @res = eval {
	my $number = $reg;
	$number =~ s/^([\.,:;\@])//
	    or return '551 Invalid register type';
	my $type = reg_nametype($1);
	if (! $int->{default}[thr_registers][$type][$number]) {
	    $type == REG_whp and return '552 No such register';
	    # we'll have to create the register
	    _create_register($int, $int->{default}, $type, $number);
	}
	my $rp = $int->{default}[thr_registers][$type][$number];
	# check if they are allowed to steal it
	my $stealing = uc($what) eq 'STEAL';
	$stealing && $rp->[reg_ignore]
	    and return '553 Cannot steal this, try smuggling';
	! $stealing && ! $rp->[reg_ignore]
	    and return '554 Cannot smuggle this, try stealing';
	if ($int->{theft_callback}) {
	    &{$int->{theft_callback}}($int, $what, $reg, $type, $number)
		or return '555 Failed due to internal policy';
	}
	my $value = $rp->[reg_value];
	my ($port, $rcs, $wcs, $mode);
	if ($type == REG_whp) {
	    # export filehandle
	    my $fh = $value->{filehandle};
	    if ($fh) {
		$rcs = $fh->read_charset;
		$wcs = $fh->write_charset;
		$mode = $fh->mode;
		$port = _fh_export($theft->server, $fh);
		# the following prevents the filehandle being garbage-collected
		# after being stolen -- is it really necessary?
		$int->{stolen}{$fh} = $fh if $stealing;
	    }
	}
	if ($binary) {
	    my $hex = $binary > 1 ? 1 : 0;
	    my $export;
	    if (defined $port) {
		$export = pack('vvvva*a*a*',
			       $port, length $rcs, length $wcs, length $mode,
			       $rcs, $wcs, $mode);
	    } else {
		$export = pack('v', 0);
	    }
	    my $now = current_time();
	    my $data = $export . encode_register($rp, $type, $now);
	    $hex and $data =
		join('', map { sprintf("%02x", $_) } unpack('C*', $data));
	    my $extra = register_extra();
	    my $len = length $data;
	    my $server = $int->{server};
	    $server->read_out($id, "26$hex $len $extra");
	    $server->read_binary($id, $data);
	    $stealing and clear_register($type, $rp);
	    return ();
	} else {
	    my @val = ();
	    if ($type == REG_whp) {
		# export filehandle
		defined $port
		    and push @val, "$reg <- #$port BY ?$rcs BY ?$wcs BY ?$mode";
		# export lectures
		for my $subject (sort { $a <=> $b } grep { /^\d+$/ } keys %$value) {
		    my $lecture = $value->{$subject};
		    push @val, "$reg SUB #$subject <- #" . $lecture;
		}
	    } elsif ($type == REG_tail || $type == REG_hybrid) {
		# export array
		my @s = list_subscripts($value);
		@s or return "550 Array not dimensioned";
		push @val, "$reg <- " . join(' BY ', map { "#$_" } @s);
		forall_elements($value, sub {
		    my ($n, @e) = @_;
		    $n or return; # no need to send zeros
		    if ($n > 0xffff) {
			my ($n1, $n2) = n_uninterleave($n, 2);
			$n = "#$n1 \xa2 #$n2";
		    } else {
			$n = '#' . $n;
		    }
		    push @val, "$reg " . join(' ', map { "SUB #$_" } @e) . " <- $n";
		});
	    } else {
		# export number
		my $n;
		if ($value > 0xffff) {
		    my ($n1, $n2) = n_uninterleave($value, 2);
		    $n = "#$n1 \xa2 #$n2";
		} else {
		    $n = '#' . $value;
		}
		push @val, "$reg <- $n";
	    }
	    if ($rp->[reg_overload]) {
		# send overload code to the other end
		my @overload = sort keys %{$rp->[reg_overload]};
		for my $o (@overload) {
		    my $oc;
		    if ($o eq '') {
			$oc = '#0';
		    } else {
			$oc = join(' ', map { "#$_" } split(/\s+/, $o));
		    }
		    my $p = $rp->[reg_overload]{$o};
		    my $pc = join(' ', map { "#$_" } unpack('C*', $p));
		    push @val, "$reg <- $oc / $pc";
		}
	    }
	    $stealing and clear_register($type, $rp);
	    return ('250 Here it is', @val, '.');
	}
    };
    $@ or return @res;
    chomp $@;
    $@ =~ s/\s+/ /g;
    $@ =~ s/^ //;
    $@ =~ s/ $//;
    return "550 $@";
}

sub _s_SMU {
    my ($int, $tp, $cp, $ep) = @_;
    _ii_STE($int, $tp, $cp, $ep, 'SMUGGLE');
}

sub _s_STE {
    my ($int, $tp, $cp, $ep) = @_;
    _ii_STE($int, $tp, $cp, $ep, 'STEAL');
}

sub _ii_STE {
    my ($int, $tp, $cp, $ep, $operation) = @_;
    my $theft = $int->{theft_server};
    $theft or faint(SP_NONET, $operation);
    my $servertype = BCget($tp->[thr_bytecode], $cp, $ep);
    $servertype > 1
	and faint(SP_INTERNAL, "Too many FROM expressions for " . bytename($tp->[thr_opcode]));
    my ($server, $bc_mc);
    if ($servertype) {
	$server = _get_number($int, $tp, $cp, $ep);
	($server, $bc_mc) = $theft->decode_address($server, 1);
    }
    my $pid;
    my $pidtype = BCget($tp->[thr_bytecode], $cp, $ep);
    $pidtype > 1
	and faint(SP_INTERNAL, "Too many ON expressions for " . bytename($tp->[thr_opcode]));
    $pidtype
	and $pid = _get_number($int, $tp, $cp, $ep);
    if (! $servertype || defined $bc_mc) {
	# go looking for a server
	my @ips = $theft->find_theft_servers($bc_mc, $pid);
	@ips or faint(SP_CASE, 'No servers found admitting to run ' . ($pid ? $pid : 'INTERCAL'));
	$server = $ips[int(rand(scalar @ips))];
    }
    my $port;
    if (! $pidtype) {
	# get a random pid from server
	my %pids = $theft->pids_and_ports($server);
	my @pids = keys %pids;
	@pids or faint(SP_INTERNET, $server, 'Server does not run anything');
	$pid = $pids[int(rand(scalar @pids))];
	$port = $pids{$pid};
    }
    $theft->start_request($server, $pid, $port, $operation);
    eval {
	my $num = BCget($tp->[thr_bytecode], $cp, $ep);
	my $now = current_time();
	while ($num-- > 0) {
	    _x_STE($int, $tp, $cp, $ep, $server, $now);
	}
    };
    my $err = $@;
    # make sure we always call finish_request(), even if the theft splats
    $theft->finish_request;
    $err and die $err;
}

sub _x_STE {
    my ($int, $tp, $cp, $ep, $server, $now) = @_;
    my $ocp = $cp;
    my ($type, $number) = _run_r($int, $tp, $cp, $ep, 1);
    my $reg = reg_decode($type, $number);
    $type == REG_spot || $type == REG_twospot || $type == REG_tail || $type == REG_hybrid || $type == REG_whp
	or faint(SP_NONET, "STEAL/SMUGGLE $reg");
    _create_register($int, $tp, $type, $number);
    my ($extra, @v) = $int->{theft_server}->request($reg);
    my $r = $tp->[thr_registers][$type][$number];
    my $i = $r->[reg_ignore];
    return if $i;
    if (defined $extra) {
	# binary encoded register data
	eval {
	    my $data = $v[0];
	    length($data) >= 2 or die "Invalid\n";
	    my $port = unpack('v', substr($data, 0, 2, ''));
	    my ($rcs, $wcs, $mode);
	    if ($port) {
		length($data) >= 6 or die "Invalid\n";
		my ($rcslen, $wcslen, $modelen) =
		    unpack('vvv', substr($data, 0, 6, ''));
		length($data) >= ($rcslen + $wcslen + $modelen) or die "Invalid\n";
		$rcs = substr($data, 0, $rcslen, '');
		$wcs = substr($data, 0, $wcslen, '');
		$mode = substr($data, 0, $modelen, '');
	    }
	    decode_register($data, $type, $extra, $r, $now);
	    if ($port) {
		my $v = Language::INTERCAL::GenericIO->new
		    ('REMOTE', $mode, "$server:$port", $int->{server});
		$v->read_charset($rcs);
		$v->write_charset($wcs);
		$r->[reg_value]{filehandle} = $v;
	    }
	};
	$@ and faint(SP_INTERNET, $server, "Error decoding binary register data");
	return;
    }
    my $newval;
    my $overload;
    for my $v (@v) {
	$v =~ s/\s+//g;
	substr($v, 0, length($reg)) eq $reg
	    or faint(SP_INTERNET, $server, "Wrong register received ($v) expected ($reg)");
	substr($v, 0, length($reg)) = '';
	$v =~ s/^(.*)<-//
	    or faint(SP_INTERNET, $server, "Value received ($v) is not an assignment");
	my $d = $1;
	my @subscripts;
	if ($d ne '') {
	    $type == REG_tail || $type == REG_hybrid || $type == REG_whp
		or die(SP_INTERNET, $server, "Array elements received for non-array register $reg");
	    while ($d ne '') {
		my $orig = $d;
		$d =~ s/^SUB\s*#(\d+)\s*// && $1 < 0x10000
		    or faint(SP_INTERNET, $server, "Subscript ($orig) syntax error");
		push @subscripts, $1;
	    }
	    $type == REG_whp && @subscripts != 1
		and die(SP_INTERNET, $server, "Invalid lecture data received for $reg");
	}
	if ($v =~ /^#(\d+)BY\?(\S+)BY\?(\S+)BY\?(\S+)$/) {
	    $type == REG_whp
		or faint(SP_INTERNET, $server, "Filehandle data received for non-class register $reg");
	    my $port = $server . ':' . $1;
	    my $rcs = $2;
	    my $wcs = $3;
	    my $mode = $4;
	    $v = Language::INTERCAL::GenericIO->new('REMOTE', $mode, $port, $int->{server});
	    $v->read_charset($rcs);
	    $v->write_charset($wcs);
	    $newval ||= {};
	    $newval->{filehandle} = $v;
	} elsif ($v =~ s/^#(\d+)BY//i) {
	    my @sub = ($1);
	    $type == REG_tail || $type == REG_hybrid
		or faint(SP_INTERNET, $server, "Array dimension received for non array register $reg");
	    defined $newval
		and faint(SP_INTERNET, $server, "Array dimension received after already dimensioning $reg");
	    while ($v =~ s/^#(\d+)BY//i) {
		push @sub, $1;
	    }
	    $v =~ /^#(\d+)$/ or faint(SP_INTERNET, $server, "Invalid dimension ($v) received for $reg");
	    push @sub, $1;
	    my @big = grep { $_ < 1 || $_ > 0xffff } @sub;
	    @big and faint(SP_INTERNET, $server, "Invalid dimension ($big[0]) received for $reg");
	    $newval = make_array(\@sub);
	} else {
	    my $vtype;
	    if ($v =~ /^#(\d+)$/) {
		$v = $1;
		$v > 0xffff
		    and faint(SP_INTERNET, $server, "Data received ($v) is too large for one spot");
		$vtype = REG_spot;
	    } elsif ($v =~ /^#(\d+)\s*\xa2\s*#(\d+)$/) {
		my ($v1, $v2) = ($1, $2);
		$v = n_interleave($v1, $v2, 2);
		$v > 0xffff && ! ($type == REG_twospot || $type == REG_hybrid)
		    and faint(SP_INTERNET, $server, "Data received ($v) is too large for one spot");
		$v > 0xffffffff
		    and faint(SP_INTERNET, $server, "Data received ($v) is too large for two spots");
		$vtype = REG_twospot;
	    } elsif ($v =~ /^#(\d+(?:#\d+)*)\/#(\d+(?:#\d+)*)$/) {
		my ($oc, $pc) = ($1, $2);
		@subscripts == 0
		    or faint(SP_INTERNET, $server, "Invalid overload data: subscripted variable");
		my @oc = map { $_ + 0 } split(/#/, $oc);
		my $o;
		if (@oc == 1 && $oc[0] == 0) {
		    $o = '';
		} else {
		    $o = join(' ', @oc);
		}
		my @pc = map { $_ + 0 } split(/#/, $pc);
		my $p = pack('C*', @pc);
		$overload->{$o} = $p;
		next;
	    } else {
		faint(SP_INTERNET, $server, "Value ($v) syntax error");
	    }
	    if (@subscripts == 0) {
		$newval = $v;
	    } elsif ($type == REG_whp) {
		$v < 1000 and faint(SP_INTERNET, $server, "Invalid lecture data, for $reg, ($v) is too early");
		$newval ||= {};
		$newval->{$subscripts[0]} = $v;
	    } else {
		$newval or faint(SP_INTERNET, $server, "Elements received before dimensioning array $reg");
		set_element($newval, $type, $v, $vtype, @subscripts);
	    }
	}
    }
    # OK, if we got here we received all data correctly so we now overwrite the local register
    $r->[reg_value] = $newval;
    $r->[reg_overload] = $overload;
}

sub _s_CSE {
    my ($int, $tp, $cp, $ep) = @_;
    my $theft = $int->{theft_server};
    $theft or faint(SP_NONET, "CASE");
    my ($value, $type) = _run_e($int, $tp, $cp, $ep);
    my @l = ();
    if ($type == REG_spot || $type == REG_twospot) {
	my ($addr, $bc) = $theft->decode_address($value, 1);
	if (defined $bc) {
	    my @ips = $theft->find_theft_servers($bc);
	    @l = map { $theft->encode_address($_) } @ips;
	} else {
	    @l = $theft->pids($addr);
	}
    } elsif ($type == REG_tail || $type == REG_hybrid) {
	my $io = $tp->[thr_registers][REG_dos][DOS_IO][reg_value];
	_create_register($int, $tp, REG_dos, DOS_AR);
	my $ar = $tp->[thr_registers][REG_dos][DOS_AR][reg_value];
	my @v = make_list($value);
	@v or faint(SP_NODIM);
	my $data = '';
	my $fh = Language::INTERCAL::GenericIO->new('STRING', 'r', \$data);
	_set_read_charset($tp, $fh);
	if ($type == REG_tail) {
	    read_array_16($io, \$ar, $fh, \@v, 0);
	} else {
	    read_array_32($io, \$ar, $fh, \@v, 0);
	}
	$tp->[thr_registers][REG_dos][DOS_AR][reg_value] = $ar;
	@l = $theft->dns_lookup($data);
    } else {
	# XXX figure out something useful to do with whirlpool registers in CASE
	faint(SP_ISSPECIAL);
    }
    my $num = BCget($tp->[thr_bytecode], $cp, $ep);
    # I don't think the grammar makes it possible to have $num == 0
    # however an assembler program can do anything, and so anybody who
    # can use a CREATE statement: so we might as well check; if there
    # are no expressions, then by definition all values are discarded.
    $num > 0 or return;
    # the documentation and the original post to alt.lang.intercal require
    # to first assign to all expressions, then execute all statements; this
    # is obviously awkward both to the programmer and to the implementer
    # but there we go...
    my @stmt;
    while ($num-- > 0) {
	if (@l) {
	    # first see if it's a register
	    my ($rtype, $rnumber);
	    eval {
		my $rcp = $$cp;
		($rtype, $rnumber) = _run_r($int, $tp, \$rcp, $ep);
		$$cp = $rcp;
	    };
	    if ($@) {
		# treat it as a number
		my $val = shift(@l);
		my $spot = $val < 0x10000 ? REG_spot : REG_twospot;
		_run_a($int, $tp, $cp, $ep, $val, $spot);
	    } else {
		# it's a register
		_create_register($int, $tp, $rtype, $rnumber);
		my $e = $tp->[thr_registers][$rtype][$rnumber];
		my $i = $e->[reg_ignore];
		if ($rtype == REG_spot || $rtype == REG_twospot) {
		    # assigning to a scalar register, we'll take one value
		    my $val = shift(@l);
		    if ($rtype == REG_spot) {
			$val > 0xffff and faint(SP_SPOTS, $val, 'one spot');
		    } else {
			$val > 0xffffffff and faint(SP_SPOTS, $val, 'two spots');
		    }
		    $e->[reg_value] = $val unless $i;
		} elsif ($rtype == REG_tail || $rtype == REG_hybrid) {
		    # assigning to an array, we need to iterate over all elements
		    # until we either run out of array or run out of values
		    my $dim = array_elements($e->[reg_value]) or faint(SP_NODIM);
		    if ($i) {
			$dim > @l and $dim = @l;
			splice(@l, 0, $dim);
		    } else {
			partial_replace_array($e->[reg_value], $rtype, \@l);
		    }
		} elsif ($rtype == REG_whp) {
		    # we do not know how to assign to a whirlpool
		    faint(SP_SPECIAL, reg_decode($rtype, $rnumber));
		} else {
		    # we do not know how to assign to an unknown register type
		    faint(SP_SPECIAL, reg_decode($rtype, $rnumber));
		}
	    }
	} else {
	    # no values left, so just skip this expression
	    bc_skip($tp->[thr_bytecode], $cp, $ep)
		or faint(SP_INTERNAL, "Missing expression in " . bytename($tp->[thr_opcode]));
	}
	# then skip the statement and remember where it was
	my $start = $$cp;
	bc_skip($tp->[thr_bytecode], $cp, $ep)
	    or faint(SP_INTERNAL, "Missing statement in " . bytename($tp->[thr_opcode]));
	$start == $$cp
	    and faint(SP_INTERNAL, "Empty statement in " . bytename($tp->[thr_opcode]));
	my $ge = vec($tp->[thr_bytecode], $start, 8);
	my $ab = $ge != BC_GUP && exists $tp->[thr_ab_gerund]{$ge}
	       ? $tp->[thr_ab_gerund]{$ge}[0]
	       : 0;
	$ab or push @stmt, [$start, $$cp];
    }
    for my $stmt (@stmt) {
	my ($st, $se) = @$stmt;
	_run_s($int, $tp, \$st, $se);
    }
}

# functions used while exporting a filehandle

sub _fh_export {
    my ($server, $fh) = @_;
    $fh->{exported} and return $fh->{exported};
    my $port = $server->tcp_listen(\&_fh_open, \&_fh_line, \&_fh_close, $fh);
    $fh->{exported} = $port;
    $port;
}

sub _fh_open {
    my ($id, $sockhost, $peerhost, $close, $fh) = @_;
    $fh->{importers}{$id} = 0;
    return "202 $sockhost ($VERSION)";
}

sub _fh_line {
    my ($server, $id, $close, $line, $fh) = @_;
    exists $fh->{importers}{$id}
	or return "580 Internal error in server";
    my $filepos = $fh->{importers}{$id};
    if ($line =~ /^\s*TELL/i) {
	my $pos = eval { $fh->tell; };
	$@ || ! defined $pos and return "581 Not seekable";
	return "280 $filepos is the current file position";
    }
    if ($line =~ /^\s*SEEK\s+(-?\d+)\s+(SET|CUR|END)/i) {
	my ($delta, $whence) = ($1, uc $2);
	exists $fh->{seek_code} or return "581 Not seekable";
	if ($whence eq 'SET') {
	    $delta < 0 and return "582 Invalid file position";
	    $filepos = $delta;
	} elsif ($whence eq 'CUR') {
	    $filepos += $delta;
	    $filepos < 0 and return "582 Invalid file position";
	} else {
	    my $delta = $delta;
	    my $curpos;
	    $@ = '';
	    eval {
		my $oldpos = $fh->tell;
		$fh->seek(0, SEEK_END);
		$curpos = $fh->tell;
		$oldpos = $fh->seek($oldpos, SEEK_SET);
	    };
	    $@ and return "583 Cannot use SEEK_END on this filehandle";
	    $filepos = $curpos + $delta;
	    $filepos < 0 and return "582 Invalid file position";
	}
	$fh->{importers}{$id} = $filepos;
	return "281 $filepos is the new file position";
    }
    if ($line =~ /^\s*WRITE\s+(\d+)/i) {
	my $size = $1;
	exists $fh->{seek_code} and $fh->{seek_code}->($filepos, SEEK_SET);
	$@ = '';
	my $data = eval { $fh->write_binary($size) };
	if ($@) {
	    $@ =~ s/\n+/ /g;
	    return "584 $@";
	}
	eval {
	    exists $fh->{tell_code}
		and $fh->{importers}{$id} = &{$fh->{tell_code}}();
	};
	my $len = length $data;
	$server->read_out($id, "282 $len");
	$server->read_binary($id, $data);
	return ();
    }
    if ($line =~ /^\s*WRITE\s+TEXT\s+\/(\S*)\//i) {
	my $newline = $1;
	$newline =~ s/!(\d{3})/chr($1)/ge;
	$@ = '';
	my $data = eval {
	    exists $fh->{seek_code}
		and $fh->{seek_code}->($filepos, SEEK_SET);
	    $fh->write_text($newline);
	};
	if ($@) {
	    $@ =~ s/\n+/ /g;
	    return "584 $@";
	}
	eval {
	    exists $fh->{tell_code}
		and $fh->{importers}{$id} = &{$fh->{tell_code}}();
	};
	my $len = length $data;
	$server->read_out($id, "282 $len");
	$server->read_binary($id, $data);
	return ();
    }
    if ($line =~ /^\s*READ\s+(\d+)/i) {
	my $len = $1;
	my $code = sub {
	    my $data = shift;
	    defined $data && length($data) == $len
		or return "585 Data size mismatch";
	    $@ = '';
	    eval {
		exists $fh->{seek_code}
		    and $fh->{seek_code}->($filepos, SEEK_SET);
		$fh->read_binary($data);
	    };
	    if ($@) {
		$@ =~ s/\n+/ /g;
		return "586 $@";
	    }
	    eval {
		exists $fh->{tell_code}
		    and $fh->{importers}{$id} = &{$fh->{tell_code}}();
	    };
	    return "283 OK";
	};
	$server->alternate_callback($id, $len, $code);
	return "383 OK, send the data";
    }
    if ($line =~ /^\s*THANKS/i) {
	$$close = 1;
	return "284 You are welcome";
    }
    if ($line =~ /^\s*ISTERM/i) {
	my $isit = eval { $fh->is_terminal; };
	$@ || ! defined $isit and return "587 Information not available";
	$isit and return "285 Yes";
	return "286 No";
    }
    return "589 Command not understood";
}

sub _fh_close {
    my ($id, $fh) = @_;
    delete $fh->{importers}{$id};
}


# The following functions are supposed to be called with an INTERPRETER

sub theft_callback {
    @_ == 1 || @_ == 2
	or croak "Usage: theft_callback(INTERPRETER [, CODE])";
    my ($int) = shift;
    my $rv = $int->{theft_callback};
    $int->{theft_callback} = shift if @_;
    $rv;
}

sub theft_server {
    @_ == 1 || @_ == 2
	or croak "Usage: theft_server(INTERPRETER [, NEW_SERVER])";
    my $int = shift;
    my $old_server = $int->{theft_server};
    $int->{theft_server} = shift if @_;
    $old_server;
}

sub theft_default_server {
    @_ == 0 || @_ == 1
	or croak "Usage: theft_default_server [(NEW_SERVER)]";
    my $old_server = $theft_default_server;
    $theft_default_server = shift if @_;
    $old_server;
}

1
