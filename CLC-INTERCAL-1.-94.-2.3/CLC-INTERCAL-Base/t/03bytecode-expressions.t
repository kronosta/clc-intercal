# test bytecode interpreter - expressions

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/03bytecode-expressions.t 1.-94.-2.3

use Language::INTERCAL::GenericIO '1.-94.-2', qw($devnull);
use Language::INTERCAL::Interpreter '1.-94.-2.2';
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(:BC BC);
use Language::INTERCAL::Registers '1.-94.-2.2', qw(REG_spot REG_whp reg_code);

use vars qw(@all_tests);

require './t/expressions';

$| = 1;

my $maxtest = 2 * scalar @all_tests;
print "1..$maxtest\n";

my $testnum = 1;
for my $tester (@all_tests) {
    my ($name, $opcode, $base, $in, $out, $splat, $israndom) = @$tester;
    my $obj = new Language::INTERCAL::Interpreter();
    $obj->object->setbug(0, 0);
    my @x = (BC_STO, ref $opcode ? @$opcode : $opcode);
    for my $r (@$in) {
	if (ref $r) {
	    next if $r->[0] =~ /^%/;
	    push @x, reg_code($r->[0]);
	} else {
	    push @x, BC($r);
	}
    }
    push @x, reg_code($out->[0]);
    my $cp = 0;
    my @c = ();
    push @c, pack('C*', BC_STS, BC($cp++), BC(1), BC(0), BC(0), @x);
    push @c, pack('C*', BC_STS, BC($cp++), BC(1), BC(0), BC(0), BC_GUP);
    eval {
	$obj->object->clear_code;
	$obj->object->unit_code(0, 'source', 6, \@c);
	for my $r (@$in) {
	    next unless ref $r;
	    $obj->setreg($r->[0], $r->[1], REG_spot);
	}
	$obj->setreg('%BA', $base, REG_spot);
	$obj->setreg('@OSFH', $devnull, REG_whp);
	$obj->setreg('@TRFH', $devnull, REG_whp);
	$obj->start()->run()->stop();
    };
    if ($@) {
	print STDERR "Failed $name\n$@";
	print "not ok ", $testnum++, "\n";
	print "not ok ", $testnum++, "\n";
	next;
    }
    my $os = $obj->splat;
    if (defined $os) {
	print defined $splat && $os == $splat ? "" : "not ", "ok ", $testnum++, "\n";
	print defined $splat && $os == $splat ? "" : "not ", "ok ", $testnum++, "\n";
	print STDERR "Failed $name\n" unless defined $splat && $os == $splat;
	next;
    } else {
	print defined $splat ? "not " : "", "ok ", $testnum++, "\n";
	print STDERR "Failed $name\n" if defined $splat;
    }
    my ($v) = eval { $obj->getreg($out->[0]) };
    if ($@) {
	print STDERR "Failed $name\n$@";
	print "not ok ", $testnum++, "\n";
	next;
    }
    print STDERR "Failed $name ($v != $out->[1])\n" if $v != $out->[1];
    print $v == $out->[1] ? '' : 'not ', "ok ", $testnum++, "\n";
}

