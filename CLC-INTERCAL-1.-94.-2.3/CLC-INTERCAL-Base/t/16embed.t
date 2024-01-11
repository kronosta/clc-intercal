# Check the embeddable INTERCAL interpreter

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/16embed.t 1.-94.-2.2

use Language::INTERCAL::GenericIO;

print "1..5\n";
my ($out, $stdread, $in, $stdwrite, @options);
BEGIN {
    $in = '';
    $stdwrite = Language::INTERCAL::GenericIO->new('STRING', 'w', \$in);
    $out = '';
    $stdread = Language::INTERCAL::GenericIO->new('STRING', 'r', \$out);
    @options = (
	bug      => 0,
	ubug     => 0,
	stdread  => $stdread,
	stdwrite => $stdwrite,
	-rcfind  => 'system',
	escape   => qr/^\s*OUT OF HERE\s*$/m,
    );
}
my $tno = 0;

start_test("READ OUT");
use Language::INTERCAL @options;
    DO READ OUT #1
    DO READ OUT #2
    PLEASE READ OUT #3
    DO GIVE UP
OUT OF HERE
end_test("I\nII\nIII\n");

start_test("WRITE IN", "SIX\nTWO SEVEN\n");
use Language::INTERCAL @options;
    DO WRITE IN .1
    DO READ OUT .1
    DO WRITE IN .2
    DO READ OUT .2
    DO GIVE UP
OUT OF HERE
end_test("VI\nXXVII\n");

start_test("PRESERVING REGISTERS BETWEEN LOOP ITERATIONS");
for my $i (1..4) {
    $stdread->read_text("$i: ");
    use Language::INTERCAL @options;
	(2) DO .2 <- #2 ~ .VVVVVVVVVVVVVVVV1
	(1) DO .1 <- #1
	    PLEASE COME FROM .2
	    DO .1 <- .1 ¢ .1
	    PLEASE COME FROM (1)
	    DO READ OUT .1
	    DO GIVE UP
    OUT OF HERE
}
end_test("1: I\n2: III\n3: XV\n4: CCLV\n");

start_test("PRESERVING CLASSES BETWEEN LOOP ITERATIONS");
for my $i (1..2) {
    $stdread->read_text("$i: ");
    use Language::INTERCAL @options;
	(2) DO .2 <- #2 ~ .VVVVVVVVVVVVVVVV1
	    DO STUDY #42 AT (1000) IN CLASS @42
	(1) DO .1 <- #1
	    PLEASE COME FROM .2
	    PLEASE ENROL .1 TO LEARN #42
	    DO .1 LEARNS #42
	    PLEASE COME FROM (1)
	    DO READ OUT .1
	    DO GIVE UP
	(1000) DO $@42 <- #3
	    DO FINISH LECTURE
    OUT OF HERE
}
end_test("1: I\n2: III\n");

start_test("PRESERVING ENROLMENT BETWEEN LOOP ITERATIONS");
for my $i (1..2) {
    $stdread->read_text("$i: ");
    use Language::INTERCAL @options;
	(2) DO .2 <- #2 ~ .VVVVVVVVVVVVVVVV1
	    DO STUDY #42 AT (1000) IN CLASS @42
	    PLEASE ENROL .1 TO LEARN #42
	(1) DO .1 <- #1
	    PLEASE COME FROM .2
	    DO .1 LEARNS #42
	    PLEASE COME FROM (1)
	    DO READ OUT .1
	    DO GIVE UP
	(1000) DO $@42 <- #3
	    DO FINISH LECTURE
    OUT OF HERE
}
end_test("1: I\n2: III\n");

exit 0;

my $tname;

sub start_test {
    ($tname, $data) = @_;
    $tno++;
    $in = defined $data ? $data : '';
    $stdwrite->reset;
    $out = '';
    $stdread->reset;
}

sub end_test {
    my ($expect) = @_;
    if ($expect eq $out) {
	print "ok $tno\n";
    } else {
	print STDERR "Invalid test output ($tno $tname)\n";
	print STDERR "Expected: ", _convert($expect), "\n";
	print STDERR "Received: ", _convert($out), "\n";
	print "not ok $tno\n";
    }
}

sub _convert {
    my ($v) = @_;
    $v =~ s/\\/\\\\/g;
    $v =~ s/\n/\\n/g;
    $v;
}

