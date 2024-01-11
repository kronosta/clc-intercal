# test intercalc's save and restore state

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/ICALC t/06intercalc-state.t 1.-94.-2.3

use File::Temp 'tempdir';
use Language::INTERCAL::Time qw(current_time);

my $begin = current_time;

require './t/run-calculator';

my $debug = scalar (grep { $_ =~ /debug/i } @ARGV);

my @tests = (
    # name, statements to create state, statements to check state
    ['EMPTY STATE', [], {
	'.1' => 'NIHIL',
    }],
    ['SPOT REGISTERS', [
	'DO .1 <- #42',
	'DO .2 <- #1',
    ], {
	'.1' => 'XLII',
	'.2' => 'I',
    }],
    ['TWO SPOT REGISTERS', [
	'DO :1 <- #42',
	'DO :2 <- #1',
    ], {
	':1' => 'XLII',
	':2' => 'I',
    }],
    ['TAIL REGISTERS', [
	'DO ,1 <- #2',
	'DO ,1 SUB #1 <- #42',
	'DO ,1 SUB #2 <- #1',
    ], {
	',1 SUB #1' => 'XLII',
	',1 SUB #2' => 'I',
    }],
    ['HYBRID REGISTERS', [
	'DO ;1 <- #2',
	'DO ;1 SUB #1 <- #42',
	'DO ;1 SUB #2 <- #1',
    ], {
	';1 SUB #1' => 'XLII',
	';1 SUB #2' => 'I',
    }],
    ['WHIRLPOOLS', [
	'DO STUDY #1 AT (1000) IN CLASS @1',
	'DO STUDY #2 AT (2000) IN CLASS @1',
    ], {
	'@1 SUB #1' => 'M',
	'@1 SUB #2' => 'MM',
    }],
    ['OVERLOADING', [
	'DO .3 <- #1',
	'DO .9 <- .1 / .2',
	'DO .9 <- .3 / .1',
    ], {
	'.1' => 'XLII',
	'.3' => 'XLII',
	'.9' => 'I',
    }, [
	'DO .2 <- #42',
    ]],
    ['BELONGING', [
	'DO .1 <- #1',
	'DO .2 <- #2',
	'DO .3 <- #3',
	'DO MAKE .1 BELONG TO .2',
	'DO MAKE .1 BELONG TO .3',
    ], {
	'.1' => 'I',
	'.2' => 'II',
	'.3' => 'III',
	'$.1' => 'III',
	'2.1' => 'II',
    }],
    ['ABSTAIN (LABEL)', [
	'DO ABSTAIN FROM (1)',
	'DO .1 <- #2',
    ], {
	'.1' => 'I',
    }, [
	'DO .1 <- #1',
	'(1) DO .1 <- #42',
    ]],
    ['ABSTAIN (GERUND)', [
	'DO .1 <- #2',
	'DO ABSTAIN FROM CALCULATING',
    ], {
	'.1' => 'II',
    }, [
	'DO .1 <- #1',
	'(1) DO .1 <- #42',
    ]],
    ['IGNORE', [
	'DO .1 <- #2',
	'DO IGNORE .1',
    ], {
	'.1' => 'II',
    }, [
	'DO .1 <- #1',
    ]],
    ['TRICKLE DOWN', [
	'DO TRICKLE .1 DOWN TO .2 AFTER #10',
	'DO .2 <- #2',
	'DO .1 <- #1',
	'(2) DO COME FROM .2',
    ], {
	'.1' => 'I',
	'.2' => 'I',
    }],
    ['PENDING 1', [
	'DO TRICKLE .1 DOWN TO .2 AFTER #1000',
	'DO .2 <- #2',
	'DO .1 <- #1',
    ], {
	'.1' => 'I',
	'.2' => 'II',
    }],
    ['PENDING 2', [
	'DO TRICKLE .1 DOWN TO .2 AFTER #1000',
	'DO .2 <- #2',
	'DO .1 <- #1',
    ], {
	'.1' => 'I',
	'.2' => 'I',
    }, [
	'(2) DO COME FROM .2',
    ]],
    ['EVENTS', [
	'DO * WHILE READ OUT #42',
    ], {
	'*' => ['XLII', '\*456'],
    }],
);

my $num_tests = 1;
for my $test (@tests) {
    my ($name, $run, $check, $precheck) = @$test;
    $num_tests += 3 + scalar(@$run) + 2 * scalar(keys %$check);
    $precheck and $num_tests += 2 * scalar(@$precheck);
}

$| = 1;
print "1..$num_tests\n";
my $num = 0;

END {
    print "not ok ", ++$num, "\n" while $num < $num_tests;
}

# start two calculators
my (@pid, @read, @write);
for (my $calc = 0; $calc < 2; $calc++) {
    ($pid[$calc], $read[$calc], $write[$calc]) = run_calculator('full', 'sick');
    my ($rfh, $wfh) = ($read[$calc], $write[$calc]);
}

# save initial state
my $tmp = tempdir(CLEANUP => 1);
my $ifn = "$tmp/initial";
my $sfn = "$tmp/save";

my $timeout = 0;

statement(0, "`r$ifn", qr/state saved to/i);

# guess timeout value based on how long the above statement took
# and make sure it's at least 2 seconds (trickle down tests take 1 second)
$timediff = current_time;
$timediff->bsub($begin);
$timediff->badd(399999);
$timediff->bdiv(400000);
$timeout = $timediff->numify;
$timeout < 2 and $timeout = 2;

# run all tests
for my $test (@tests) {
    my ($name, $run, $check, $precheck) = @$test;
    my $end = $num + 3 + scalar(@$run) + 2 * scalar(keys %$check);
    eval {
	# restore empty state
	statement(0, "`w$ifn", qr/loaded state from/i);
	# set up required state
	for my $stmt (@$run) {
	    statement(0, $stmt);
	}
	# save state
	unlink $sfn;
	statement(0, "`r$sfn", qr/state saved to/i);
	# execute any pre-check statements
	$precheck ||= [];
	for my $stmt (@$precheck) {
	    statement(0, $stmt);
	}
	# check required state OK
	check_state($name, 0, $check)
	    or die "Error setting up state, test cannot continue\n";
	# load state
	statement(1, "`w$sfn", qr/loaded state from/i);
	# execute any pre-check statements
	for my $stmt (@$precheck) {
	    statement(1, $stmt);
	}
	# check loaded state OK
	check_state($name, 1, $check);
    };
    $@ and print STDERR "$name: $@";
    print "not ok ", ++$num, "\n" while $num < $end;
}

sub check_state {
    my ($name, $calc, $check) = @_;
    my $ok = 1;
    for my $ck (sort keys %$check) {
	my $res = $check->{$ck};
	my @skip;
	ref $res and ($res, @skip) = @$res;
	eval {
	    my $rc = expression($calc, $ck, @skip);
	    defined $rc or die "No result from $ck\n";
	    $res eq $rc or die "Invalid result from $ck: expected $res obtained $rc\n";
	    print "ok ", ++$num, "\n";
	};
	if ($@) {
	    print STDERR $name, $calc ? '(load)' : '(save)', " ", $@;
	    print "not ok ", ++$num, "\n";
	    $ok = 0;
	}
    }
    $ok;
}

sub statement {
    my ($calc, $run, $expect) = @_;
    my $line = expression($calc, $run);
    $expect ? ($line =~ $expect) : ($line eq 'OK')
	or die "Running $run: $line\n";
    print "ok ", ++$num, "\n";
}

sub expression {
    my ($calc, $run, @skip) = @_;
    my ($rfh, $wfh) = ($read[$calc], $write[$calc]);
    $debug and print STDERR "$calc>>> $run\n";
    print $rfh "$run\n";
    local $SIG{ALRM} = sub { die "Calculator: timed out\n"; };
    alarm $timeout;
    my $line = <$wfh>;
    defined $line or die "Calculator: end of input\n";
    chomp $line;
    $debug and print STDERR "$calc<<< $line\n";
    push @skip, 'loading compiler';
    my $skip = join('|', @skip);
    $skip = qr/$skip/i;
    while ($line =~ $skip) {
	alarm $timeout;
	$line = <$wfh>;
	defined $line or die "Calculator: end of input\n";
	chomp $line;
	$debug and print STDERR "$calc<<< $line\n";
    }
    alarm 0;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    $line =~ s/^(.*\S)\s*\Q$run\E$/$1/;
    $line;
}

