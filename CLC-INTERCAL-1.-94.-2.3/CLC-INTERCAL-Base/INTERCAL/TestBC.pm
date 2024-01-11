# test bytecode interpreter

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base INTERCAL/TestBC.pm 1.-94.-2.2

package Language::INTERCAL::TestBC;

use Language::INTERCAL::GenericIO '1.-94.-2', qw($devnull);
use Language::INTERCAL::Interpreter '1.-94.-2.2';
use Language::INTERCAL::Rcfile '1.-94.-2';
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(BC_GUP BC_STR BC_STS BC);
use Language::INTERCAL::Registers '1.-94.-2.2', qw(REG_whp);
use Language::INTERCAL::Sick '1.-94.-2';
use Language::INTERCAL::Server '1.-94.-2';
use Language::INTERCAL::Exporter '1.-94.-2';

our @EXPORT_OK = qw(test_bc test_newint test_rc test_str);
our @ISA = qw(Language::INTERCAL::Exporter);

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/TestBC.pm 1.-94.-2.2") =~ /\s(\S+)$/;

my @newint;
sub test_newint {
    push @newint, [@_];
}

my $def_rc;
sub test_rc {
    $def_rc = shift;
}

sub test_bc {
    my (@all_tests) = @_;
    local $| = 1;

    my $maxtest = 0;
    for my $tester (@all_tests) {
	my ($name, $load, $in, $out, $auxfile, $splat, @data) = @$tester;
	$maxtest += 2;
	$maxtest += abs($out->[0]) - 1 if ref $out;
	$maxtest++ if defined $auxfile;
    }
    print "1..$maxtest\n";

    my $testnum = 1;
    my $rc = $def_rc || new Language::INTERCAL::Rcfile;
    my $compiler = new Language::INTERCAL::Sick($rc);
    TESTER:
    for my $tester (@all_tests) {
	my ($name, $load, $in, $out, $auxfile, $splat, @data) = @$tester;
	my ($iter, @out) = ref $out ? @$out : (1, $out);
	my $reorder = 0;
	if ($iter < 0) {
	    $reorder = 1;
	    $iter = -$iter;
	}
	my $obj;
	if ($load) {
	    eval {
		$compiler->reset();
		$compiler->setoption('default_charset', 'ASCII');
		$compiler->setoption('default_backend', 'Run');
		$compiler->clearoption('preload');
		$compiler->setoption('preload', $load);
		$compiler->setoption('trace', 0);
		$compiler->source('null.iacc');
		$compiler->load_objects();
		$obj = $compiler->get_object('null.iacc')
		    or die "Internal error: no compiler object\n";
	    };
	    if ($@) {
		print STDERR "FAILED $name: $@";
		print "not ok ", $testnum++, "\n" for (-1..$iter);
		next;
	    }
	} else {
	    $obj = new Language::INTERCAL::Interpreter();
	    for my $ni (@newint) {
		my ($code, @data) = @$ni;
		$code->($obj, @data);
	    }
	}
	$obj->object->setbug(0, 0);
	my @units = (['']);
	while (@data) {
	    my $ss = shift @data;
	    if (defined $ss) {
		$ss .= "\n";
		my $sp = shift @data;
		my $sc = shift @data;
		push @{$units[-1]},
		    pack('C*', BC_STS, BC(length $units[-1][0]), BC(length $ss), BC(0), BC(0), @$sp, @$sc);
		$units[-1][0] .= $ss;
	    } else {
		push @units, [''];
	    }
	}
	push @{$units[-1]},
	    pack('C*', BC_STS, BC(length $units[-1][0]), BC(11), BC(0), BC(0), BC_GUP);
	$units[-1][0] .= "DO GIVE UP\n";
	my $i_data = $in;
	my $i_fh = Language::INTERCAL::GenericIO->new('STRING', 'w', \$i_data);
	my $o_data = '';
	my $o_fh = Language::INTERCAL::GenericIO->new('STRING', 'r', \$o_data);
	my $b_fh = undef;
	my $a_fh = undef;
	my $a_data = '';
	if (defined $auxfile) {
	    $a_fh = Language::INTERCAL::GenericIO->new('STRING', 'r', \$a_data);
	    my $b_data = $auxfile->[0];
	    $b_fh = Language::INTERCAL::GenericIO->new('STRING', 'w', \$b_data);
	}
	eval {
	    $obj->object->clear_code;
	    for (my $unit = 0; $unit < @units; $unit++) {
		my ($source, @code) = @{$units[$unit]};
		$obj->object->unit_code($unit, $source, length($source), \@code);
	    }
	    $obj->setreg('@TRFH', $devnull, REG_whp);
	    $obj->setreg('@OWFH', $i_fh, REG_whp);
	    $obj->setreg('@OSFH', $o_fh, REG_whp);
	    $obj->setreg('@ORFH', $o_fh, REG_whp);
	    $obj->setreg('@69', $a_fh, REG_whp) if defined $a_fh;
	    $obj->setreg('@68', $b_fh, REG_whp) if defined $b_fh;
	    local $SIG{ALRM} = sub { die "Timeout\n" };
	    alarm 5;
	    $obj->start()->run()->stop();
	};
	alarm 0;
	if ($@) {
	    print "not ok ", $testnum++, "\n" for (0..$iter);
	    print "not ok ", $testnum++, "\n" if defined $auxfile;
	    print STDERR "Failed $name: $@";
	    next;
	}
	my $os = $obj->splat;
	if (defined $os) {
	    print defined $splat && $os == $splat ? "" : "not ", "ok ", $testnum++, "\n";
	    print STDERR "Failed $name (*$os)\n" unless defined $splat && $os == $splat;
	} else {
	    print defined $splat ? "not " : "", "ok ", $testnum++, "\n";
	    print STDERR "Failed $name (no splat)\n" if defined $splat;
	}
	if (defined $auxfile) {
	    if ($auxfile->[1] eq $a_data) {
		print "ok ", $testnum++, "\n";
	    } else {
		print "not ok ", $testnum++, "\n";
		$a_data =~ s/\n/\\n/g;
		my $x = $auxfile->[1];
		$x =~ s/\n/\\n/g;
		print STDERR "Failed $name (aux output='$a_data' instead of '$x')\n";
	    }
	}
	my %out = map { ($_ => 0) } @out;
	if ($reorder) {
	    # threaded or quantum programs can reorder output depending on exactly when/how things run
	    $o_data = join("\n", (sort split(/\n/, $o_data)), '');
	}
	if (ref $out && $iter == 1) {
	    my $ok = 1;
	    for my $o (@out) {
		my $i = index($o_data, $o);
		if ($i < 0) {
		    print STDERR "Failed $name: should have printed $o", $o =~ /\n$/ ? '' : "\n";
		    $ok = 0;
		} else {
		    substr($o_data, $i, length($o)) = '';
		}
	    }
	    if ($o_data ne '') {
		$ok and print STDERR "Failed $name: should not have printed $o_data", $o_data =~ /\n$/ ? '' : "\n";
		$ok = 0;
	    }
	    print $ok ? '' : 'not ', "ok ", $testnum++, "\n";
	} else {
	    print STDERR "Failed $name: should not have printed $o_data", $o_data =~ /\n$/ ? '' : "\n" if ! exists $out{$o_data};
	    print exists $out{$o_data} ? '' : 'not ', "ok ", $testnum++, "\n";
	    $out{$o_data}++ if exists $out{$o_data};
	}
	next unless ref $out;
	next if $out->[0] == 1;
	for (my $inum = 1; $inum < $iter; $inum++) {
	    $i_data = $in;
	    $o_data = '';
	    $o_fh->reset;
	    eval { $obj->start()->run()->stop() };
	    print STDERR "Failed $name: should not have printed $o_data", $o_data =~ /\n$/ ? '' : "\n" if ! exists $out{$o_data};
	    print exists $out{$o_data} ? '' : 'not ', "ok ", $testnum++, "\n";
	    $out{$o_data}++ if exists $out{$o_data};
	}
    }
}

sub test_str {
    my ($str) = @_;
    return (BC_STR, BC(length $str), unpack('C*', $str));
}

1
