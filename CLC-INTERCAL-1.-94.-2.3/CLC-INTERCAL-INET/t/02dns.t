# test INTERcal NETworking

# Copyright (c) 2007-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/INET t/02dns.t 1.-94.-2.1

use Socket qw(inet_ntoa);
use Language::INTERCAL::Rcfile '1.-94.-2.1';
use Language::INTERCAL::Server '1.-94.-2.1';
use Language::INTERCAL::Theft '1.-94.-2.2';

my $ipv6 = Language::INTERCAL::Server::has_ipv6();

if ($ipv6) {
    push @tests, (
	[\&dns, 'ff1e::42', IPv6(127, 0, 2, 0)],
	[\&dns, 'ff02::1', IPv6(127, 0, 1, 0)],
    );
}

%Language::INTERCAL::Theft::dns_tests = (
    'test1.dns'  => [qw(12.34.56.78 127.0.0.1),
		     $ipv6 ? (qw(2001:db8::1 2fff:1234:5678:9abc:def0:1:2:3)) : ()],
    'test2.here' => [qw(223.127.42.81 219.255.0.1),
		     $ipv6 ? (qw(2001:db8::2 2001:db8::3)) : ()],
);

push @tests, (
    [\&dns, 'test1.dns',  IPv4(12, 34, 56, 78), IPv4(127, 0, 0, 1),
			  IPv6(224, 0, 0, 1), IPv6(224, 0, 0, 2)],
    [\&dns, 'test2.here', IPv4(223, 127, 42, 81), IPv4(219, 255, 0, 1),
			  IPv6(224, 0, 0, 3), IPv6(224, 0, 0, 4)],
);

if (! @tests) {
    print "1..0 # skipped: all tests disabled by configuration or environment\n";
    exit 0;
}

my $rc = Language::INTERCAL::Rcfile->new();
$rc->setoption(nouserrc => 1);
$rc->setoption(nosystemrc => 1);
$rc->rcfind('system');
$rc->rcfind('INET');
$rc->load;
my $t = Language::INTERCAL::Theft->new(undef, $rc, '', []);

my $count = @tests;
print "1..$count\n";

for my $test (@tests) {
    my ($run, $data, @result) = @$test;
    my @found = $run->($data);
    if (@found == @result) {
	if (join(chr(0), sort @found) eq join(chr(0), sort @result)) {
	    print "ok\n";
	    next;
	}
    }
    print STDERR "Failed $data: expected (",
		 join(' ', map { inet_ntoa(pack('N', $_)) } @result),
		 ") but result was (",
		 join(' ', map { inet_ntoa(pack('N', $_)) } @found), ")\n";
    print "not ok\n";
}

sub dns {
    my ($data) = @_;
    $t->dns_lookup($data);
}

sub IPv4 {
    my ($n1, $n2, $n3, $n4) = @_;
    ($n1 << 24) | ($n2 << 16) | ($n3 << 8) | $n4;
}

sub IPv6 {
    $ipv6 and goto &IPv4;
    ();
}

