# Check the suffix detection mechanism

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/15suffix.t 1.-94.-2.2

use Language::INTERCAL::Rcfile '1.-94.-2.1';
use Language::INTERCAL::Sick '1.-94.-2.1';

my @tests_nooption = (
    [qw(.iacc       iacc)],
    [qw(.iasm       asm)],
    [qw(.1972       1972)],
    [qw(.1972i      1972)],
    # test that the "r" suffix is not recognised
    [qw(.ri)],
    [qw(.nri)],
    [qw(.rni)],
);

my @tests_option = (
    [qw(.clci       sick)],
    [qw(.ci         ick)],
    [qw(.i          sick)],
    [qw(.ti         ick thick)],
    [qw(.cti        ick thick)],
    [qw(.tci        ick thick)],
    [qw(.tclci      sick thick)],
    [qw(.clcti      sick thick)],
);

my @options = (
    [],
    [qw(2 2)],
    [qw(3 3)],
    [qw(4 4)],
    [qw(5 5)],
    [qw(6 6)],
    [qw(7 7)],
    [qw(65 6)],
    [qw(45 5)],
    [qw(342 4)],
    [qw(32 3)],
    [qw(22 2)],
    [qw(d bitwise-divide)],
    [qw(7d bitwise-divide 7)],
    [qw(g come-from-gerund)],
    [qw(g2 come-from-gerund 2)],
    [qw(h class-helpers)],
    [qw(h6 class-helpers 6)],
    [qw(l computed-labels)],
    [qw(3l computed-labels 3)],
    [qw(n next)],
    [qw(n4 next 4)],
    [qw(s syscall)],
    [qw(5s syscall 5)],
    [qw(w wimp)],
    [qw(w6 wimp 6)],
    [qw(nw3s next wimp syscall 3)],
    # another "r" suffix test
    [qw(r)],
);

my @optimise = (
    [qw(0)],
    [qw(1 optimise)],
);

my $rc = Language::INTERCAL::Rcfile->new;
$rc->rcfind('system');
$rc->load;

my $sick = Language::INTERCAL::Sick->new($rc);
$sick->setoption('default_suffix', $_)
    for $rc->getitem('UNDERSTAND');

$| = 1;
my $ntests = 2 * (scalar(@tests_nooption) + scalar(@tests_option) * scalar(@options));
print "1..$ntests\n";

run(\@tests_nooption, [[]]);
run(\@tests_option, \@options);
exit 0;

sub run {
    my ($tests, $options) = @_;
    for my $test (@$tests) {
	my ($base_suffix, @test_preloads) = @$test;
	for my $option (@$options) {
	    my ($option_suffix, @option_preloads) = @$option;
	    my $suffix = substr($base_suffix, 0, 1) . $option_suffix . substr($base_suffix, 1);
	    my $succeeds = ($option_suffix eq '' || @option_preloads) && @test_preloads;
	    for my $op (@optimise) {
		my ($optimise, @optimise_preloads) = @$op;
		eval {
		    my @expected = sort (@test_preloads, @option_preloads, @optimise_preloads);
		    my @found = $sick->guess_preloads($suffix, $optimise);
		    $succeeds or die "Suffix was supposed to be unknown, retured (@found) instead\n";
		    my $ok = 0;
		    if (@found == @expected) {
			my @F = sort @found;
			join(' + ', @F) eq join(' + ', @expected)
			    and $ok = 1;
		    }
		    $ok or die "$suffix ($optimise) --> expected (@expected), found (@found)\n";
		};
		if ($@ && ($succeeds || $@ !~ /\bcannot\s+guess\b/i)) {
		    print "not ok\n";
		    print STDERR "$suffix: $@";
		} else {
		    print "ok\n";
		}
	    }
	}
    }
}

