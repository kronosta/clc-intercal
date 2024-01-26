package Language::INTERCAL::Backend;

# Backends

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Backend.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use File::Spec::Functions qw(splitpath catpath splitdir catdir);
use Language::INTERCAL::Exporter '1.-94.-2';
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(backend all_backends generate_code);

my @backends = ();
my %backends = ();

sub backend {
    @_ == 1 or croak "Usage: backend(BACKEND)";
    my ($backend) = @_;
    $backend =~ s/\s+//g;
    if ($backend =~ /^\d+$/) {
	return undef if $backend < 0 || $backend >= @backends;
	return $backend;
    } else {
	if (! exists $backends{lc $backend}) {
	    eval "require Language::INTERCAL::Backend::$backend";
	    if ($@) {
		# see if there's something with case change
		($backend) = grep { lc($_) eq lc($backend) } all_backends();
		defined $backend or return undef;
		eval "require Language::INTERCAL::Backend::$backend";
		return undef if $@;
	    }
	    $backends{lc $backend} = @backends;
	    push @backends, $backend;
	}
	$backend = $backends{lc $backend};
	return $backend;
    }
}

sub all_backends {
    my %r = ();
    for my $inc (@INC) {
	my ($v, $d, $f) = splitpath($inc, 1);
	$d = catdir(splitdir($inc), qw(Language INTERCAL Backend));
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

sub generate_code {
    @_ == 8 or croak
	"Usage: generate_code(INTERPRETER, BACKEND, NAME, DIRNAME, BASENAME, FILESPEC, ORIG, OPTIONS)";
    my ($int, $backend, $name, $dirname, $basename, $filespec, $orig, $options) = @_;
    $options ||= {};
    my $verb = $options->{verbose};
    $backend = 'Language::INTERCAL::Backend::' . $backend;
    eval "require $backend"; die $@ if $@;
    my $suffix = $backend->default_suffix;
    my $mode = $backend->default_mode;
    my $handle = '';
    my $filename = undef;
    my %p = ('%' => '%', 'p' => $basename, 's' => $suffix, 'o' => $orig);
    if (defined $suffix) {
	$filename = $filespec;
	$filename =~ s/%([%ops])/$p{$1}/ge;
	if ($dirname ne '') {
	    my ($v, $d, $f) = splitpath($filename);
	    $filename = catpath($v, $dirname, $f);
	}
	&$verb($filename) if $verb;
	$handle = new Language::INTERCAL::GenericIO 'FILE', 'r', $filename;
	$name =~ s/%([%ops])/$p{$1}/ge;
    } else {
	&$verb('') if $verb;
    }
    $backend->generate($int, $name, $handle, $options);
    undef $handle;
    if (defined $filename && defined $mode) {
	chmod $mode & ~umask, $filename;
    }
}

1;
