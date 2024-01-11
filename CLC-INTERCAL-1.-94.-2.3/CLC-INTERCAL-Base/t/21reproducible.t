# Spot if the compiler exhibits non-reproducible behaviour

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base t/21reproducible.t 1.-94.-2.2

use Language::INTERCAL::Rcfile '1.-94.-2.2';
use Language::INTERCAL::Sick '1.-94.-2.2';
use Language::INTERCAL::GenericIO '1.-94.-2.2';

my %suffix = (
    i       => 'sick',
    iacc    => 'iacc',
    iasm    => 'asm',
);

my @tests = ();

# we do need the MANIFEST to get the list of sources
open (MF, '<MANIFEST') or die "MANIFEST: $!\n";
while (<MF>) {
    s|^INTERCAL/Include/|| or next;
    s|\b\s.*$||s;
    # double check we can actually compile this...
    m|\.([^.]+)$| or next;
    my $suffix = $1;
    exists $suffix{$suffix} or next;
    push @tests, [$suffix{$suffix}, $_];
}
close MF;

@tests or die "Cannot find anything to test on? Is this the CLC-INTERCAL distribution?\n";
my $tries = 8;
$| = 1;
print "1..", $tries * scalar(@tests), "\n";

undef $/;
my $count = 0;
for my $test (@tests) {
    my ($preload, $source) = @$test;
    my $text;
    if (! (open(TEXT, '<', "INTERCAL/Include/$source")
	   and (defined ($text = <TEXT>))
	   and close(TEXT)))
    {
	print STDERR "$source: $!\n";
	print "not ok ", ++$count, "\n" for (1..8);
	next;
    }
    my $prev;
    (my $io = $source) =~ s/\.[^.]+$/.io/;
    if (! (open(IO, '<', "blib/lib/Language/INTERCAL/Include/$io")
	   and (defined ($prev = <IO>))
	   and close(IO)))
    {
	print STDERR "$io $!\n";
	print "not ok ", ++$count, "\n" for (1..8);
	next;
    }
    for my $retry (1..$tries) {
	my $rc = Language::INTERCAL::Rcfile->new;
	# make sure there's no interference from the environment
	$rc->setoption(build => 1);
	$rc->setoption(nouserrc => 1);
	$rc->setoption(nosystemrc => 1);
	$rc->setoption(rcfile => 'INTERCAL/Include/system.sickrc');
	$rc->load(1);
	my $sick = Language::INTERCAL::Sick->new($rc);
	$sick->setoption(preload => $preload);
	$sick->setoption(add_preloads => 0);
	$sick->setoption(trace => 0);
	$sick->setoption(charset => 'ASCII');
	$sick->setoption(optimise => 0);
	$sick->setoption(backend => 'Object');
	$sick->setoption(bug => 0);
	$sick->setoption(ubug => 0);
	$sick->source_string($text);
	$sick->load_objects();
	my $object = $sick->get_text_object;
	if (! $object) {
	    print STDERR "Failed compiling $source\n";
	    print "not ok ", ++$count, "\n";
	    next;
	}
	my $save = '';
	my $handle = Language::INTERCAL::GenericIO->new('STRING', 'r', \$save);
	$object->read($handle, 0);
	if ($prev ne $save) {
	    print STDERR "$source: objects differ\n";
	    print "not ok ", ++$count, "\n";
	    next;
	}
	print "ok ", ++$count, "\n";
    }
}

