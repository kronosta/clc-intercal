# test INTERcal NETworking -- CASE statements

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/INET t/07case.t 1.-94.-2.2

use Language::INTERCAL::Extensions '1.-94.-2', qw(load_extension);
BEGIN { load_extension('INET'); }
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(:BC BC);
use Language::INTERCAL::TestBC '1.-94.-2', qw(test_newint test_rc test_bc test_str);
use Language::INTERCAL::Theft '1.-94.-2.2';
use Language::INTERCAL::Rcfile '1.-94.-2.2';
use Language::INTERCAL::ReadNumbers '1.-94.-2', qw(roman_type_default roman);

%Language::INTERCAL::Theft::dns_tests = (
    'test0.dns' => [],
    'test1.dns' => [qw(12.34.56.78)],
    'test2.dns' => [qw(223.127.42.81 219.255.0.1)],
    'test3.dns' => [qw(223.127.42.81 12.34.56.78 219.255.0.1)],
);

my $res1 = roman((12 << 24) | (34 << 16) | (56 << 8) | 78, roman_type_default);
my $res2 = roman((223 << 24) | (127 << 16) | (42 << 8) | 81, roman_type_default);
my $res3 = roman((219 << 24) | (255 << 16) | 1, roman_type_default);

my @all_tests = (
    ['CASE, no result', undef, 'test0.dns', "I\nII\nIII\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :1 THEN :42 <- #42', [], [BC_CSE, BC_TAI, BC(9), BC(1),
		    BC_TSP, BC(1), BC_STO, BC_TSP, BC(42), BC(42)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, one expression, one result', undef, 'test1.dns', "$res1\nII\nIII\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :9', [], [BC_CSE, BC_TAI, BC(9), BC(1),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(9), BC_TSP, BC(1)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, one expression, two results', undef, 'test2.dns', "$res2\nII\nIII\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :9', [], [BC_CSE, BC_TAI, BC(9), BC(1),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(9), BC_TSP, BC(1)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, two expressions, one result', undef, 'test1.dns', "NIHIL\n$res1\nIII\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :8 OR :8 THEN :2 <- :9', [], [BC_CSE, BC_TAI, BC(9), BC(2),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(8), BC_TSP, BC(1),
		    BC_TSP, BC(8), BC_STO, BC_TSP, BC(9), BC_TSP, BC(2)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, two expressions, two results', undef, 'test2.dns', "$res3\n$res2\nIII\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :8 OR :8 THEN :2 <- :9', [], [BC_CSE, BC_TAI, BC(9), BC(2),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(8), BC_TSP, BC(1),
		    BC_TSP, BC(8), BC_STO, BC_TSP, BC(9), BC_TSP, BC(2)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, two expressions, three results', undef, 'test3.dns', "$res1\n$res2\nIII\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :8 OR :8 THEN :2 <- :9', [], [BC_CSE, BC_TAI, BC(9), BC(2),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(8), BC_TSP, BC(1),
		    BC_TSP, BC(8), BC_STO, BC_TSP, BC(9), BC_TSP, BC(2)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, three expressions, one result', undef, 'test1.dns', "NIHIL\n$res1\nNIHIL\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :8 OR :8 THEN :2 <- :9 OR :7 THEN :3 <- :7', [], [BC_CSE, BC_TAI, BC(9), BC(3),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(8), BC_TSP, BC(1),
		    BC_TSP, BC(8), BC_STO, BC_TSP, BC(9), BC_TSP, BC(2),
		    BC_TSP, BC(7), BC_STO, BC_TSP, BC(7), BC_TSP, BC(3)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, three expressions, two results', undef, 'test2.dns', "$res3\n$res2\nNIHIL\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :8 OR :8 THEN :2 <- :9 OR :7 THEN :3 <- :7', [], [BC_CSE, BC_TAI, BC(9), BC(3),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(8), BC_TSP, BC(1),
		    BC_TSP, BC(8), BC_STO, BC_TSP, BC(9), BC_TSP, BC(2),
		    BC_TSP, BC(7), BC_STO, BC_TSP, BC(7), BC_TSP, BC(3)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, three expressions, three results', undef, 'test3.dns', "$res1\n$res2\n$res3\n", undef, undef,
     'DO :1 <- #1', [], [BC_STO, BC(1), BC_TSP, BC(1)],
     'DO :2 <- #2', [], [BC_STO, BC(2), BC_TSP, BC(2)],
     'DO :3 <- #3', [], [BC_STO, BC(3), BC_TSP, BC(3)],
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO CASE ,9 IN :9 THEN :1 <- :8 OR :8 THEN :2 <- :9 OR :7 THEN :3 <- :7', [], [BC_CSE, BC_TAI, BC(9), BC(3),
		    BC_TSP, BC(9), BC_STO, BC_TSP, BC(8), BC_TSP, BC(1),
		    BC_TSP, BC(8), BC_STO, BC_TSP, BC(9), BC_TSP, BC(2),
		    BC_TSP, BC(7), BC_STO, BC_TSP, BC(7), BC_TSP, BC(3)],
     'DO READ OUT :1 + :2 + :3', [], [BC_ROU, BC(3), BC_TSP, BC(1), BC_TSP, BC(2), BC_TSP, BC(3)]],
    ['CASE, array expression, one result', undef, 'test1.dns', "XLII\n$res1\nII\nIII\n", undef, undef,
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO ;9 <- #3', [], [BC_STO, BC(3), BC_HYB, BC(9)],
     'DO ;9 SUB #1 <- #1', [], [BC_STO, BC(1), BC_SUB, BC(1), BC_HYB, BC(9)],
     'DO ;9 SUB #2 <- #2', [], [BC_STO, BC(2), BC_SUB, BC(2), BC_HYB, BC(9)],
     'DO ;9 SUB #3 <- #3', [], [BC_STO, BC(3), BC_SUB, BC(3), BC_HYB, BC(9)],
     'DO CASE ,9 IN ;9 THEN :1 <- #42', [], [BC_CSE, BC_TAI, BC(9), BC(1),
		    BC_HYB, BC(9), BC_STO, BC(42), BC_TSP, BC(1)],
     'DO READ OUT :1 + ;9 SUB #1 + ;9 SUB #2 + ;9 SUB #3', [],
		    [BC_ROU, BC(4), BC_TSP, BC(1), BC_SUB, BC(1), BC_HYB, BC(9),
		     BC_SUB, BC(2), BC_HYB, BC(9), BC_SUB, BC(3), BC_HYB, BC(9)]],
    ['CASE, array expression, two results', undef, 'test2.dns', "XLII\n$res2\n$res3\nIII\n", undef, undef,
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO ;9 <- #3', [], [BC_STO, BC(3), BC_HYB, BC(9)],
     'DO ;9 SUB #1 <- #1', [], [BC_STO, BC(1), BC_SUB, BC(1), BC_HYB, BC(9)],
     'DO ;9 SUB #2 <- #2', [], [BC_STO, BC(2), BC_SUB, BC(2), BC_HYB, BC(9)],
     'DO ;9 SUB #3 <- #3', [], [BC_STO, BC(3), BC_SUB, BC(3), BC_HYB, BC(9)],
     'DO CASE ,9 IN ;9 THEN :1 <- #42', [], [BC_CSE, BC_TAI, BC(9), BC(1),
		    BC_HYB, BC(9), BC_STO, BC(42), BC_TSP, BC(1)],
     'DO READ OUT :1 + ;9 SUB #1 + ;9 SUB #2 + ;9 SUB #3', [],
		    [BC_ROU, BC(4), BC_TSP, BC(1), BC_SUB, BC(1), BC_HYB, BC(9),
		     BC_SUB, BC(2), BC_HYB, BC(9), BC_SUB, BC(3), BC_HYB, BC(9)]],
    ['CASE, array expression, three results', undef, 'test3.dns', "XLII\n$res2\n$res1\n$res3\n", undef, undef,
     'DO ,9 <- #10', [], [BC_STO, BC(20), BC_TAI, BC(9)],
     'DO WRITE IN ,9', [], [BC_WIN, BC(1), BC_TAI, BC(9)],
     'DO ;9 <- #3', [], [BC_STO, BC(3), BC_HYB, BC(9)],
     'DO ;9 SUB #1 <- #1', [], [BC_STO, BC(1), BC_SUB, BC(1), BC_HYB, BC(9)],
     'DO ;9 SUB #2 <- #2', [], [BC_STO, BC(2), BC_SUB, BC(2), BC_HYB, BC(9)],
     'DO ;9 SUB #3 <- #3', [], [BC_STO, BC(3), BC_SUB, BC(3), BC_HYB, BC(9)],
     'DO CASE ,9 IN ;9 THEN :1 <- #42', [], [BC_CSE, BC_TAI, BC(9), BC(1),
		    BC_HYB, BC(9), BC_STO, BC(42), BC_TSP, BC(1)],
     'DO READ OUT :1 + ;9 SUB #1 + ;9 SUB #2 + ;9 SUB #3', [],
		    [BC_ROU, BC(4), BC_TSP, BC(1), BC_SUB, BC(1), BC_HYB, BC(9),
		     BC_SUB, BC(2), BC_HYB, BC(9), BC_SUB, BC(3), BC_HYB, BC(9)]],
);

my $rc = Language::INTERCAL::Rcfile->new();
$rc->setoption(nouserrc => 1);
$rc->setoption(nosystemrc => 1);
$rc->rcfind('system');
$rc->rcfind('INET');
$rc->load;

my $theft = Language::INTERCAL::Theft->new(undef, $rc, '', []);
test_rc($rc);
test_newint(\&setup);
test_bc(@all_tests);

sub setup {
    my ($int) = @_;
    $int->{theft_server} = $theft;
}

