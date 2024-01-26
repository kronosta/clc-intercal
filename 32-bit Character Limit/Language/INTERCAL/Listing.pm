package Language::INTERCAL::Listing;

# Source listings

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Listing.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use File::Spec::Functions qw(splitpath catpath splitdir catdir);
use Language::INTERCAL::Exporter '1.-94.-2';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(listing all_listings);

sub listing {
    @_ == 1 or croak "Usage: listing(LISTING)";
    my ($listing) = @_;
    $listing =~ s/\s+//g;
    my $arg;
    $listing =~ s/=(.*)$// and $arg = $1;
    eval "require Language::INTERCAL::Listing::$listing";
    if ($@) {
	# search for this
	($listing) = grep { lc($_) eq lc($listing) } all_listings();
	defined $listing or return undef;
	eval "require Language::INTERCAL::Listing::$listing";
	return undef if $@;
    }
    # listing objects don't really have much in the way of state...
    bless [$arg], "Language::INTERCAL::Listing::$listing";
}

sub all_listings {
    my %r = ();
    for my $inc (@INC) {
	my ($v, $d, $f) = splitpath($inc, 1);
	$d = catdir(splitdir($inc), qw(Language INTERCAL Listing));
	my $dir = catpath($v, $d, $f);
	opendir(my $dh, $dir) or next;
	while (defined (my $ent = readdir $dh)) {
	    $ent =~ /^\./ and next;
	    my $name = $ent;
	    $name =~ s/\.pm$//i or next;
	    my $file = catpath($v, $d, $ent);
	    -f $file and $r{$name} = 0;
	}
	closedir $dh;
    }
    sort keys %r;
}

sub filename {
    @_ == 6 or croak "Usage: LISTING->filename(NAME, DIRNAME, BASENAME, FILESPEC, ORIG)";
    my ($ls, $name, $dirname, $basename, $filespec, $orig) = @_;
    my $suffix = $ls->default_suffix;
    my %p = ('%' => '%', 'p' => $basename, 's' => $suffix, 'o' => $orig);
    my $filename = $filespec;
    $filename =~ s/%([%ops])/$p{$1}/ge;
    if ($dirname ne '') {
	my ($v, $d, $f) = splitpath($filename);
	$filename = catpath($v, $dirname, $f);
    }
    return $filename;
}

1;
