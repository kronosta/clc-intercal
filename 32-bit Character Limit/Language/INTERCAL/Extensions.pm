package Language::INTERCAL::Extensions;

# Load compiler extensions

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Extensions.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2';
use vars qw(@EXPORT_OK);

@EXPORT_OK = qw(load_extension load_rc_extension);

my %callbacks = (
    callback     => 'Interpreter',
    opcode       => 'Interpreter',
    register     => 'Registers',
    splat        => 'Splats',
    undocumented => 'Interpreter',
);

my %rc_callbacks = (
    rcdef        => 'Rcfile',
);

my (%rc_loaded, %rest_loaded, %module_loaded);

sub _load {
    my ($ext, $cb) = @_;
    for my $callback (keys %$cb) {
	defined &{"Language::INTERCAL::${ext}::Extend::add_$callback"} or next;
	my $module = $cb->{$callback};
	if (! exists $module_loaded{$module}) {
	    eval "require Language::INTERCAL::$module";
	    $@ and die $@;
	    $module_loaded{$module} = 1;
	}
	my $code = \&{"Language::INTERCAL::${module}::add_$callback"};
	no strict 'refs';
	&{"Language::INTERCAL::${ext}::Extend::add_$callback"}($code, $ext, $module);
    }
}

# arrange for extension data to be loaded; note that this will also "require"
# other modules, which we can't "use" because that would introduce a circular
# dependency: these modules can "use" this one.
sub load_extension {
    @_ == 1 or croak "Usage: load_extensions(EXTENSION)";
    my ($ext) = @_;
    exists $rest_loaded{$ext} and return;
    eval "require Language::INTERCAL::${ext}::Extend";
    $@ and die $@;
    $rest_loaded{$ext} = 1;
    load_rc_extension($ext);
    _load($ext, \%callbacks);
}

# like load_extensions but only loads RC file extensions
sub load_rc_extension {
    @_ == 1 or croak "Usage: load_rc_extensions(EXTENSION)";
    my ($ext) = @_;
    exists $rc_loaded{extension}{$ext} and return;
    (my $mext = $ext) =~ s/\W+/_/g;
    eval "require Language::INTERCAL::${mext}::Extend";
    $rc_loaded{extension}{$ext} = 1;
    if ($@) {
	$@ =~ /^\s*can't\s+locate/i and return;
	die $@;
    }
    _load($ext, \%rc_callbacks);
}

1;

__END__

=pod

=head1 NAME

Language::INTERCAL::Extensions - load compiler extensions

=head1 DESCRIPTION

This module forms the core of the I<CLC-INTERCAL> extension mechanism;
it is called by various parts of the compiler to load any additional
state and code as required by an extension.

It exports a single function, I<load_extension>, which takes just the
name of an extension, tries to load it, then arranges for its bytecode,
register, splat and interpreter extensions to be registered.

=head1 SEE ALSO

The documentation in I<CLC-INTERCAL-Docs>

A qualified psychiatrist

=head1 AUTHOR

Claudio Calvelli - compiler (whirlpool) intercal.org.uk
(Please include the word INTERLEAVING in the subject when emailing that
address, or the email may be ignored)

