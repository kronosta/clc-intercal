# test optimiser

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/14optimise.t 1.-94.-2.2

# test the predefined optimisations; later we'll test adding rules etc

use Language::INTERCAL::Optimiser '1.-94.-2.2';
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(BC :BC);

my @tests = (
    ['RIN 1',
     pack('C*', BC_RIN, BC(1), BC(2)),
     pack('C*', BC_INT, BC(2), BC(1)) ],
    ['RIN 2',
     pack('C*', BC_RIN, BC_SPO, BC(1), BC_SPO, BC(2)),
     pack('C*', BC_INT, BC_SPO, BC(2), BC_SPO, BC(1)) ],
    ['RIN 3',
     pack('C*', BC_STO, BC_RIN, BC_SPO, BC(1), BC_SPO, BC(2), BC_TSP, BC(1)),
     pack('C*', BC_STO, BC_INT, BC_SPO, BC(2), BC_SPO, BC(1), BC_TSP, BC(1)) ],
    ['RSE 1',
     pack('C*', BC_RSE, BC(1), BC(2)),
     pack('C*', BC_SEL, BC(2), BC(1)) ],
    ['RSE 2',
     pack('C*', BC_RSE, BC_SPO, BC(1), BC_SPO, BC(2)),
     pack('C*', BC_SEL, BC_SPO, BC(2), BC_SPO, BC(1)) ],
    ['RSE 3',
     pack('C*', BC_STO, BC_RSE, BC_SPO, BC(1), BC_SPO, BC(2), BC_TSP, BC(1)),
     pack('C*', BC_STO, BC_SEL, BC_SPO, BC(2), BC_SPO, BC(1), BC_TSP, BC(1)) ],
    ['RIN RSE 1',
     pack('C*', BC_RIN, BC_RSE, BC(1), BC_SPO, BC(2), BC_RIN, BC_SPO, BC(3), BC(4)),
     pack('C*', BC_INT, BC_INT, BC(4), BC_SPO, BC(3), BC_SEL, BC_SPO, BC(2), BC(1)) ],
    ['RSE RIN 1',
     pack('C*', BC_RSE, BC_RSE, BC(1), BC_SPO, BC(2), BC_RIN, BC_SPO, BC(3), BC(4)),
     pack('C*', BC_SEL, BC_INT, BC(4), BC_SPO, BC(3), BC_SEL, BC_SPO, BC(2), BC(1)) ],
);

$| = 1;
print "1..", scalar(@tests), "\n";
my $opt = Language::INTERCAL::Optimiser->new;
for (my $num = 1; $num <= @tests; $num++) {
    my ($name, $before, $after) = @{$tests[$num - 1]};
    my $optimised = $opt->optimise($before);
    if ($after eq $optimised) {
	print "ok $num\n";
    } else {
	print "not ok $num\n";
	print STDERR "$name:\n";
	print STDERR "BYTECODE:", (map { sprintf " %02X", $_ } unpack('C*', $before)), "\n";
	print STDERR "EXPECTED:", (map { sprintf " %02X", $_ } unpack('C*', $after)), "\n";
	print STDERR "OBTAINED:", (map { sprintf " %02X", $_ } unpack('C*', $optimised)), "\n";
    }
}

