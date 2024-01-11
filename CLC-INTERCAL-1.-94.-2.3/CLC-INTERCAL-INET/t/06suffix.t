# Check the suffix detection mechanism

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/INET t/06suffix.t 1.-94.-2.1

use Language::INTERCAL::Rcfile '1.-94.-2.1';
use Language::INTERCAL::Sick '1.-94.-2.1';

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
    [qw(r internet)],
    [qw(r4 internet 4)],
    [qw(wrn wimp internet next)],
    [qw(glr come-from-gerund computed-labels internet)],
);

my @optimise = (
    [qw(0)],
    [qw(1 optimise)],
);

my $rc = Language::INTERCAL::Rcfile->new;
$rc->setoption(nouserrc => 1);
$rc->setoption(nosystemrc => 1);
$rc->rcfind('system');
$rc->rcfind('INET');
$rc->load;

my $sick = Language::INTERCAL::Sick->new($rc);
$sick->setoption('default_suffix', $_)
    for $rc->getitem('UNDERSTAND');

$| = 1;
my $ntests = 2 * (scalar(@tests_nooption) + scalar(@tests_option) * scalar(@options));
print "1..$ntests\n";

run(\@tests_nooption, [[]]);
run(\@tests_option, \@options);

sub run {
    my ($tests, $options) = @_;
    for my $test (@$tests) {
	my ($base_suffix, @test_preloads) = @$test;
	for my $option (@$options) {
	    my ($extra, @option_preloads) = @$option;
	    my $suffix = substr($base_suffix, 0, 1) . $extra . substr($base_suffix, 1);
	    for my $op (@optimise) {
		my ($optimise, @optimise_preloads) = @$op;
		eval {
		    my @expected = sort (@test_preloads, @option_preloads, @optimise_preloads);
		    my @found = $sick->guess_preloads($suffix, $optimise);
		    my $ok = 0;
		    if (@found == @expected) {
			my @F = sort @found;
			join(' + ', @F) eq join(' + ', @expected)
			    and $ok = 1;
		    }
		    $ok or die "$suffix ($optimise) --> expected (@expected), found (@found)\n";
		};
		if ($@) {
		    print "not ok\n";
		    print STDERR "$suffix: $@";
		} else {
		    print "ok\n";
		}
	    }
	}
    }
}

