# Test Interpreter::State

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/22interpreter-state.t 1.-94.-2.3

use Language::INTERCAL::Interpreter::State '1.-94.-2.3';
use Language::INTERCAL::Time '1.-94.-2.3', qw(current_time);
use Language::INTERCAL::Rcfile '1.-94.-2.2';
use Language::INTERCAL::Sick '1.-94.-2.2';
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(BC :BC);
use Language::INTERCAL::Registers '1.-94.-2.2', qw(reg_translate);
use Language::INTERCAL::Interpreter '1.-94.-2.3', qw(
    thr_ab_gerund thr_ab_label thr_ab_once thr_assign
    thr_grammar_record thr_registers thr_rules thr_stash
    thr_statements
);
use Language::INTERCAL::TestBC '1.-94.-2.2', qw(test_str);
use Language::INTERCAL::RegTypes '1.-94.-2.2',
    qw(REG_spot REG_twospot REG_tail REG_hybrid REG_whp);
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(has_type);

my $begin = current_time;

my @tests = (
    # check that empty state is actually empty
    ['Empty state', []],

    # check that we can save / restore registers
    ['Registers', ['.1', ':1', ',1', ';1', '@1'], \&checkreg,
     ['DO .1 <- #1', [BC_STO, BC(1), BC_SPO, BC(1)]],
     ['DO :1 <- #2', [BC_STO, BC(2), BC_TSP, BC(1)]],
     ['DO ,1 <- #3', [BC_STO, BC(3), BC_TAI, BC(1)]],
     ['DO ,1 SUB #1 <- #10', [BC_STO, BC(10), BC_SUB, BC(1), BC_TAI, BC(1)]],
     ['DO ,1 SUB #2 <- #11', [BC_STO, BC(11), BC_SUB, BC(2), BC_TAI, BC(1)]],
     ['DO ,1 SUB #3 <- #12', [BC_STO, BC(12), BC_SUB, BC(3), BC_TAI, BC(1)]],
     ['DO ;1 <- #4', [BC_STO, BC(4), BC_HYB, BC(1)]],
     ['DO ;1 SUB #1 <- #20', [BC_STO, BC(20), BC_SUB, BC(1), BC_HYB, BC(1)]],
     ['DO ;1 SUB #2 <- #21', [BC_STO, BC(21), BC_SUB, BC(2), BC_HYB, BC(1)]],
     ['DO ;1 SUB #3 <- #22', [BC_STO, BC(22), BC_SUB, BC(3), BC_HYB, BC(1)]],
     ['DO ;1 SUB #4 <- #23', [BC_STO, BC(23), BC_SUB, BC(4), BC_HYB, BC(1)]],
    ],
    ['Classes', [qw(@1 @2 @3 @4 @9)], \&checkreg,
     ['DO STUDY #42 AT (1000) IN CLASS @1', [BC_STU, BC(42), BC(1000), BC_WHP, BC(1)]],
     ['DO STUDY #15 AT (1100) IN CLASS @2', [BC_STU, BC(15), BC(1100), BC_WHP, BC(2)]],
     ['DO STUDY #42 AT (2000) IN CLASS @3', [BC_STU, BC(42), BC(2000), BC_WHP, BC(3)]],
    ],
    ['Belonging', [qw(.1 .2 .3 .4 .5)], \&checkreg,
     ['DO MAKE .1 BELONG TO .2', [BC_MKB, BC_SPO, BC(1), BC_SPO, BC(2)]],
     ['DO MAKE .1 BELONG TO .3', [BC_MKB, BC_SPO, BC(1), BC_SPO, BC(3)]],
     ['DO MAKE .1 BELONG TO .4', [BC_MKB, BC_SPO, BC(1), BC_SPO, BC(4)]],
     ['DO MAKE .2 BELONG TO .4', [BC_MKB, BC_SPO, BC(2), BC_SPO, BC(4)]],
     ['DO MAKE .3 BELONG TO .3', [BC_MKB, BC_SPO, BC(3), BC_SPO, BC(3)]],
     ['DO MAKE .4 BELONG TO .2', [BC_MKB, BC_SPO, BC(4), BC_SPO, BC(2)]],
    ],
    ['Overloading', [qw(.1 .2 .3 ;1 ;2 ;3 @1 @2)], \&checkreg,
     ['DO .2 <- #2', [BC_STO, BC(2), BC_SPO, BC(2)]],
     ['DO .1 <- .2 / @1', [BC_STO, BC_OVR, BC_WHP, BC(1), BC_SPO, BC(2), BC_SPO, BC(1)]],
     # verify that overload is set up by using .2 as a class
     ['DO STUDY #42 AT (1000) IN CLASS .2', [BC_STU, BC(42), BC(1000), BC_SPO, BC(2)]],
     ['DO :2 <- #65535 ~ #0#2', [BC_STO, BC_INT, BC(65535), BC(0), BC_TSP, BC(2)]],
     ['DO :1 <- :2 / .2', [BC_STO, BC_OVR, BC_SPO, BC(2), BC_TSP, BC(2), BC_TSP, BC(1)]],
     # verify that overload is set up by using :2 as a class
     ['DO STUDY #42 AT (1000) IN CLASS :2', [BC_STU, BC(42), BC(1000), BC_TSP, BC(2)]],
    ],
    ['Stash', [qw(.1 .2 .3 .4)], \&checkreg,
     ['DO STASH .1', [BC_STA, BC(1), BC_SPO, BC(1)]],
     ['DO STASH .2 + .3', [BC_STA, BC(2), BC_SPO, BC(2), BC_SPO, BC(3)]],
     ['DO STASH .1 + .3', [BC_STA, BC(2), BC_SPO, BC(1), BC_SPO, BC(3)]],
     ['DO STAST .1', [BC_IGN, BC(1), BC_SPO, BC(1)]],
     ['DO RETRIEVE .2', [BC_RET, BC(1), BC_SPO, BC(2)]],
     ['DO RETRIEVE .1 + .3', [BC_RET, BC(2), BC_SPO, BC(1), BC_SPO, BC(3)]],
    ],
    ['Ignore', [qw(.1 .2 .3 .4)], \&checkreg,
     ['DO IGNORE .1', [BC_IGN, BC(1), BC_SPO, BC(1)]],
     ['DO IGNORE .2 + .3', [BC_IGN, BC(2), BC_SPO, BC(2), BC_SPO, BC(3)]],
     ['DO IGNORE .3', [BC_IGN, BC(1), BC_SPO, BC(3)]],
     ['DO REMEMBER .2', [BC_REM, BC(1), BC_SPO, BC(2)]],
    ],
    ['Trickle', [qw(.1 .2 .3 .4)], \&checkreg,
     ['DO .1 TRICKLE DOWN TO .2 + .3 AFTER #1000', [BC_TRD, BC_SPO, BC(1), BC(1000), BC(2), BC_SPO, BC(2), BC_SPO, BC(3)]],
     ['DO .2 TRICKLE DOWN TO .3 + .1 AFTER #100', [BC_TRD, BC_SPO, BC(2), BC(100), BC(2), BC_SPO, BC(3), BC_SPO, BC(1)]],
     ['DO .3 TRICKLE DOWN TO .1 AFTER #10', [BC_TRD, BC_SPO, BC(3), BC(10), BC(1), BC_SPO, BC(1)]],
    ],
    ['Pending trickles', [qw(.1 .2 .3 .4)], \&checkreg,
     ['DO .1 TRICKLE DOWN TO .2 + .3 AFTER #1000', [BC_TRD, BC_SPO, BC(1), BC(1000), BC(2), BC_SPO, BC(2), BC_SPO, BC(3)]],
     ['DO .2 TRICKLE DOWN TO .3 + .1 AFTER #10000', [BC_TRD, BC_SPO, BC(2), BC(10000), BC(2), BC_SPO, BC(3), BC_SPO, BC(1)]],
     ['DO .3 TRICKLE DOWN TO .1 AFTER #1', [BC_TRD, BC_SPO, BC(3), BC(1), BC(1), BC_SPO, BC(1)]],
     ['DO .1 <- #1', [BC_STO, BC(1), BC_SPO, BC(1)]],
     ['DO .2 <- #2', [BC_STO, BC(2), BC_SPO, BC(2)]],
     ['DO .3 <- #3', [BC_STO, BC(3), BC_SPO, BC(3)]],
     ['DO .4 <- #4', [BC_STO, BC(4), BC_SPO, BC(4)]],
     ['(1) DO COME FROM .1', [BC_LAB, BC(1), BC_CFL, BC_SPO, BC(1)]],
    ],

    # Check that we can save / restore constants if ahem they happen to have changed
    ['Constants', [qw(1 2 3 4)], \&checkconst,
     ['DO #1 <- #42', [BC_STO, BC(42), BC(1)]],
     ['DO #2 <- #12', [BC_STO, BC(12), BC(2)]],
     ['DO #3 <- #15', [BC_STO, BC(15), BC(3)]],
    ],

    # Check that we can save / restore the ABSTAIN / REINSTATE / ONCE / AGAIN information
    ['Abstain from label', [qw(42 84 1000 65000 1)], \&checkablabel,
     ['Do ABSTAIN FROM (42)', [BC_ABL, BC(42)]],
     ['Do REINSTATE (84)', [BC_REL, BC(84)]],
     ['Do ABSTAIN FROM (1000)', [BC_ABL, BC(1000)]],
     ['Do REINSTATE (65000)', [BC_REL, BC(65000)]],
    ],
    ['Abstain from gerund', [BC_ABG, BC_ABL, BC_CRE, BC_MKB, BC_REG, BC_REL, BC_STO, BC_SWA], \&checkabgerund,
     ['DO ABSTAIN FROM CALCULATING + EVOLUTION + ABSTAINING FROM', [BC_ABG, BC(4), BC_STO, 0, BC_ABL, BC_ABG]],
     ['DO REINSTATE SWAPPING + REINSTATING', [BC_REG, BC(3), BC_SWA, BC_REL, BC_REG]],
    ],
    ['ONCE', [qw(0.0 0.1 0.17)], \&checkonce,
     ['DO .1 <- #1 ONCE', [BC_BIT, 3, BC_STO, BC(1), BC_SPO, BC(1)]],
     ['DO .2 <- #2 ONCE', [BC_BIT, 3, BC_STO, BC(2), BC_SPO, BC(2)]],
    ],
    ['AGAIN', [qw(0.0 0.1 0.18)], \&checkonce,
     ['DO .1 <- #1 AGAIN', [BC_BIT, 4, BC_STO, BC(1), BC_SPO, BC(1)]],
     ['DO .2 <- #2 AGAIN', [BC_BIT, 4, BC_STO, BC(2), BC_SPO, BC(2)]],
    ],
    # Check that we can save / restore compiler changes
    ['GRAMMAR 1', ['record', 'rules'], \&checkgrammar,
     ['DO CREATE #2 ?A ,B, AS UDV',
      [BC_CRE, BC(2), test_str('A'), BC(1), BC(0), BC(1), test_str('B'), BC(1), BC(4), BC(1), BC_UDV]],
    ],
    ['GRAMMAR 2', ['record', 'rules'], \&checkgrammar,
     ['DO CREATE #2 ?A ,B, AS UDV',
      [BC_CRE, BC(2), test_str('A'), BC(1), BC(0), BC(1), test_str('B'), BC(1), BC(4), BC(1), BC_UDV]],
     ['DO CREATE #2 ?B ,A, AS NOT',
      [BC_CRE, BC(2), test_str('B'), BC(1), BC(0), BC(1), test_str('A'), BC(1), BC(4), BC(1), BC_NOT]],
     ['DO DESTROY #2 ?A ,B,',
      [BC_DES, BC(2), test_str('A'), BC(1), BC(0), BC(1), test_str('B')]],
    ],
    ['GRAMMAR 3', [BC_ABL, BC_REL, BC_ABG, BC_REG, BC_STO], \&checkopcode,
     ['DO CONVERT ABSTAINING FROM LABEL TO REINSTATING LABEL', [BC_CON, BC_ABL, BC_REL]],
     ['DO SWAP ABSTAINING FROM GERUND AND REINSTATING GERUND', [BC_SWA, BC_ABG, BC_REG]],
    ],

    # Check that we can save/restore events
    ['EVENTS', [0, 1, 2], \&checkevent,
     ['DO * WHILE READ OUT .1', [BC_ECB, BC_SPL, BC_ROU, BC(1), BC_SPO, BC(1)]],
     ['DO .1 WHILE IGNORE .1', [BC_ECB, BC_SPO, BC(1), BC_IGN, BC(1), BC_SPO, BC(1)]],
    ],
);

my @compares = (
    [thr_ab_label,       'thr_ab_label'],
    [thr_ab_gerund,      'thr_ab_gerund'],
    [thr_ab_once,        'thr_ab_once'],
    [undef,              'ab_count'],
    [thr_grammar_record, 'thr_grammar_record'],
    [thr_rules,          'thr_rules'],
    [undef,              'events'],
    [thr_registers,      'thr_registers', [REG_spot, REG_twospot, REG_tail, REG_hybrid, REG_whp]],
    [thr_stash,          'thr_stash',     [REG_spot, REG_twospot, REG_tail, REG_hybrid, REG_whp]],
    [thr_assign,         'thr_assign'],
);

my $ntests = 0;
for my $test (@tests) {
    $ntests += 3 + scalar(@compares) + scalar(@{$test->[1]});
}

$! = 1;
print "1..$ntests\n";

my $rc = new Language::INTERCAL::Rcfile;
my $compiler = new Language::INTERCAL::Sick($rc);

my $gup = "DO GIVE UP";
my $gupcode = pack('C*', BC_STS, BC(0), BC(length $gup), BC(0), BC(0), BC_GUP);

my ($brounding, $rounding);

my $count = 0;
for my $test (@tests) {
    my ($name, $cklist, $ckcode, @sources) = @$test;
    my $source = '';
    my @code = ();
    for my $stmt (@sources, [$gup, [BC_GUP]]) {
	my ($s, $c) = @$stmt;
	my $code = pack('C*', @$c);
	push @code,
	    pack('C*', BC_STS, BC(length $source), BC(1 + length $s), BC(0), BC(0)) . $code;
	$source .= $s . "\n";
    }
    my ($obj1, $state1);
    my $now1 = current_time();
    eval {
	$obj1 = new Language::INTERCAL::Interpreter::State();
	$obj1->{record_grammar} = 1;
	$obj1->object->setbug(0, 0);
	$obj1->object->unit_code(0, $source, length($source), \@code);
	my $now = current_time();
	$obj1->start()->run()->stop();
	if (! defined $rounding) {
	    $brounding = current_time;
	    $brounding->bsub($begin);
	    $brounding->bmul(500);
	    $rounding = $brounding->numify;
	}
	$state1 = $obj1->get_state($now, $rounding);
    };
    if ($@) {
	# can't do anything without a first object
	print STDERR "$name: $@";
	print "not ok ", ++$count, "\n" for (1, 2, 3, @compares, @$cklist);
	next;
    }
    print "ok ", ++$count, "\n";
    my $obj2;
    my $now2 = current_time();
    eval {
	$obj2 = new Language::INTERCAL::Interpreter::State();
	$obj2->{record_grammar} = 1;
	$obj2->object->setbug(0, 0);
	$obj2->object->unit_code(0, $gup, length $gup, $gupcode);
	$obj2->start()->run()->stop();
	$obj2->set_state($state1, 0, $now1);
    };
    if ($@) {
	# can't compare elements without a second object
	print STDERR "$name: $@";
	print "not ok ", ++$count, "\n" for (2, @compares, @$cklist);
    } else {
	print "ok ", ++$count, "\n";
	for my $cp (@compares) {
	    my ($thr, $key, $only) = @$cp;
	    eval {
		if (defined $thr) {
		    if ($only) {
			compare("$key $_", $obj1->{default}[$thr][$_], $obj2->{default}[$thr][$_], $now1, $now2)
			    for @$only;
		    } else {
			compare($key, $obj1->{default}[$thr], $obj2->{default}[$thr], $now1, $now2);
		    }
		} else {
		    compare($key, $obj1->{$key}, $obj2->{$key}, $now1, $now2);
		}
	    };
	    if ($@) {
		print STDERR "$name: $@";
		print "not ok ", ++$count, "\n";
	    } else {
		print "ok ", ++$count, "\n";
	    }
	}
	for my $r (@$cklist) {
	    eval {
		my $val1 = $ckcode->($obj1, $r);
		my $val2 = $ckcode->($obj2, $r);
		compare($r, $val1, $val2, $now1, $now2);
	    };
	    if ($@) {
		print STDERR "$name: $@";
		print "not ok ", ++$count, "\n";
	    } else {
		print "ok ", ++$count, "\n";
	    }
	}
    }
    eval {
	my $obj3 = new Language::INTERCAL::Interpreter::State();
	$obj3->{record_grammar} = 1;
	$obj3->object->setbug(0, 0);
	$obj3->object->unit_code(0, $source, length($source), \@code);
	my $now = current_time();
	$obj3->start()->run()->stop();
	my $state3 = $obj3->get_state($now, $rounding);
	if ($state1 ne $state3) {
	    print STDERR "$name: State differs between runs:\n";
	    hexdump('1:', $state1);
	    hexdump('3:', $state3);
	    my $s = 0;
	    $s++ while $s < length $state1 &&
		       $s < length $state3 &&
		       vec($state1, $s, 8) == vec($state3, $s, 8);
	    while ($s < length $state1 && $s < length $state3) {
		my $b = $s;
		$s++ while $s < length $state1 &&
			   $s < length $state3 &&
			   vec($state1, $s, 8) != vec($state3, $s, 8);
		print STDERR "\@$b..$s:\n";
		print STDERR join(' ', '1:', map { sprintf("%02x", $_) } unpack('C*', substr($state1, $b, $s - $b))), "\n";
		print STDERR join(' ', '3:', map { sprintf("%02x", $_) } unpack('C*', substr($state3, $b, $s - $b))), "\n";
		$s++ while $s < length $state1 &&
			   $s < length $state3 &&
			   vec($state1, $s, 8) == vec($state3, $s, 8);
	    }
	    if ($s < length $state1) {
		print STDERR "\@$s:\n";
		print STDERR join(' ', '1:', map { sprintf("%02x", $_) } unpack('C*', substr($state1, $s))), "\n";
	    }
	    if ($s < length $state3) {
		print STDERR "\@$s:\n";
		print STDERR join(' ', '3:', map { sprintf("%02x", $_) } unpack('C*', substr($state3, $s))), "\n";
	    }
	    die "\n";
	}
	print "ok ", ++$count, "\n";
    };
    if ($@) {
	$@ =~ /\S/ and print STDERR "$name: $@";
	print "not ok ", ++$count, "\n";
    }
}

sub hexdump {
    my ($title, $data) = @_;
    for (my $i = 0; $i < length $data; $i += 16) {
	printf STDERR "%s %4d", $title, $i;
	$title = ' ' x length $title;
	for (my $j = $i; $j < $i + 16 && $j < length $data; $j++) {
	    printf STDERR " %02x", vec($data, $j, 8);
	}
	if ($i + 16 >= length $data) {
	    print STDERR '   ' x ($i + 16 - length $data);
	}
	print STDERR '  ';
	for (my $j = $i; $j < $i + 16 && $j < length $data; $j++) {
	    my $c = substr($data, $j, 1);
	    print STDERR $c =~ /^[[:print:]]/ ? $c : ' ';
	}
	print STDERR "\n";
    }
}

sub compare {
    my ($key, $v1, $v2, $now1, $now2) = @_;
    if (! defined $v1) {
	defined $v2 and die "obj2 has $key but obj1 does not\n";
	return;
    }
    if (! defined $v2) {
	die "obj1 has $key but obj2 does not\n";
    }
    if (! ref $v1) {
	ref $v2 and die "obj2's $key is a reference but obj1 is not\n";
	$v1 eq $v2 or die "$key differs [$v1] [$v2]\n";
	return;
    }
    if (! ref $v2) {
	die "obj1's $key is a reference but obj2 is not\n";
    }
    if (eval { $v1->isa('Math::BigInt') }) {
	eval { $v2->isa('Math::BigInt') } or die "obj1 is a BigInt but obj2 is not\n";
	my $t1 = $v1->copy->bsub($now1);
	my $t2 = $v2->copy->bsub($now2);
	my $c = $t1->bcmp($t2);
	$c == 0 and return;
	my ($diff, $sign);
	if ($c < 0) {
	    $diff = $t2->bsub($t1);
	    $sign = '<';
	} else {
	    $diff = $t1->bsub($t2);
	    $sign = '>';
	}
	$diff->ble($brounding) and return;
	die "obj1's timestamp is $sign obj2's by $diff (adjust=$brounding)\n";
    }
    eval { $v2->isa('Math::BigInt') } and die "obj2 is a BigInt but obj1 is not\n";
    if (has_type($v1, 'SCALAR')) {
	has_type($v2, 'SCALAR') or die "obj1's $key is SCALAR but obj2's is $v2\n";
	compare($key, $$v1, $$v2, $now1, $now2);
	return;
    }
    if (has_type($v1, 'REF')) {
	has_type($v2, 'REF') or die "obj1's $key is REF but obj2's is $v2\n";
	compare($key, $$v1, $$v2, $now1, $now2);
	return;
    }
    if (has_type($v1, 'ARRAY')) {
	has_type($v2, 'ARRAY') or die "obj1's $key is ARRAY but obj2's is $v2\n";
	my @v1 = @$v1; pop @v1 while @v1 and ! defined $v1[-1];
	my @v2 = @$v2; pop @v2 while @v2 and ! defined $v2[-1];
	@v1 == @v2 or die "$key differs [@v1] [@v2]\n";
	for (my $i = 0; $i < @$v1; $i++) {
	    compare("$key $i", $v1->[$i], $v2->[$i], $now1, $now2);
	}
	return;
    }
    if (has_type($v1, 'HASH')) {
	has_type($v2, 'HASH') or die "obj1's $key is HASH but obj2's is $v2\n";
	my @k1 = sort keys %$v1;
	my @k2 = sort keys %$v2;
	@k1 == @k2 or die "$key differs [number of keys] [@k1] [@k2]\n";
	for (my $i = 0; $i < @k1; $i++) {
	    my $k = $k1[$i];
	    $k eq $k2[$i] or die "$key differs [$k]\n";
	    compare("$key $k", $v1->{$k}, $v2->{$k}, $now1, $now2);
	}
	return;
    }
    if (has_type($v1, 'CODE')) {
	has_type($v2, 'CODE') or die "obj1's $key is CODE but obj2's is $v2\n";
	# need to point to the same bit of code
	$v1 == $v2 or die "$key differs [$v1] [$v2]\n";
	return;
    }
    if (has_type($v1, 'GLOB')) {
	has_type($v2, 'GLOB') or die "obj1's $key is GLOB but obj2's is $v2\n";
	# can't really compare globs
	return;
    }
print STDERR "??? $key: $v1 $v2\n";
}

sub checkreg {
    my ($obj, $name) = @_;
    # we don't use getreg() because it only gets type and value but we want
    # the whole register (also we want to ignore overload)
    my ($type, $number) = reg_translate($name);
    $obj->{default}[thr_registers][$type][$number];
}

sub checkconst {
    my ($obj, $num) = @_;
    $obj->{default}[thr_assign]{$num};
}

sub checkablabel {
    my ($obj, $num) = @_;
    $obj->{default}[thr_ab_label]{$num};
}

sub checkabgerund {
    my ($obj, $num) = @_;
    $obj->{default}[thr_ab_gerund]{$num};
}

sub checkonce {
    my ($obj, $num) = @_;
    $obj->{default}[thr_ab_once]{$num};
}

sub checkgrammar {
    my ($obj, $num) = @_;
    $num eq 'record' and return $obj->{default}[thr_grammar_record];
    $num eq 'rules' and return $obj->{default}[thr_rules][1];
    die "Internal error <$num>\n";
}

sub checkopcode {
    my ($obj, $num) = @_;
    $obj->{default}[thr_statements][$num];
}

sub checkevent {
    my ($obj, $num) = @_;
    $obj->{events}[$num];
}

