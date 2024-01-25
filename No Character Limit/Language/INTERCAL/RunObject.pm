package Language::INTERCAL::RunObject;

# Runtime for programs compiled to a Perl executable

# This file is part of CLC-INTERCAL

# Copyright (c) 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/RunObject.pm 1.-94.-2.2") =~ /\s(\S+)$/;

use Carp;
use Getopt::Long;
use Language::INTERCAL::Exporter '1.-94.-2.1';
use Language::INTERCAL::GenericIO '1.-94.-2.2', qw($stdsplat);
use Language::INTERCAL::Server '1.-94.-2.1';
use Language::INTERCAL::Rcfile '1.-94.-2.1';
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension);
use Language::INTERCAL::RegTypes '1.-94.-2.2', qw(REG_spot REG_shf REG_whp);
use vars qw(@EXPORT_OK);
@EXPORT_OK = qw(run_object);

sub run_object {
    my @extensions = @_;
    for my $extension (@extensions) {
	load_extension($extension);
    }
    my $rc = Language::INTERCAL::Rcfile->new();
    if (defined &Getopt::Long::Configure) {
        Getopt::Long::Configure qw(no_ignore_case auto_abbrev permute bundling pass_through);
    } else {
        $Getopt::Long::ignorecase = 0;
        $Getopt::Long::autoabbrev = 1;
        $Getopt::Long::order = $Getopt::Long::PERMUTE;
        $Getopt::Long::bundling = 1;
    }
    my $wimp = 0;
    my $trace = 0;
    my $stdtrace = undef;
    my $interpreter = '';
    GetOptions(
        'wimp!'         => \$wimp,
        'trace!'        => \$trace,
        'stdtrace=s'    => \$stdtrace,
        'nouserrc'      => sub { $rc->setoption('nouserrc', 1) },
        'nosystemrc'    => sub { $rc->setoption('nosystemrc', 1) },
        'rcfile=s'      => sub { $rc->setoption(@_) },
        'rcskip=s'      => sub { $rc->setoption(@_) },
	'interpreter=s' => \$interpreter,
    );
    $rc->load(1);
    my $fh;
    {
	my $caller = caller;
	no strict 'refs';
	$fh = Language::INTERCAL::GenericIO->new('FILE', 'w', \*{"$caller\::DATA"});
    }
    my $class = 'Language::INTERCAL::Interpreter';
    $interpreter ne '' and $class .= '::' . $interpreter;
    eval "use $class 1.-94.-2.2"; $@ and die $@;
    my $int = $class->write($fh, 1);
    $int->rcfile($rc);
    if ($trace || defined $stdtrace) {
        $trace = 1;
	my $th = $stdsplat;
	if (defined $stdtrace) {
	    my $mode = $stdtrace =~ s/^([ra]),//i ? lc($1) : 'r';
	    $th = Language::INTERCAL::GenericIO->new('FILE', $mode, $stdtrace);
	}
        $int->setreg('@TRFH', $th, REG_whp);
    }
    $int->setreg('%WT', $wimp, REG_spot);
    $int->setreg('%TM', $trace, REG_spot);
    $int->setreg('^AV', \@ARGV, REG_shf);
    $int->setreg('^EV', [map { "$_=$ENV{$_}" } keys %ENV], REG_shf);
    $int->server(Language::INTERCAL::Server->new());
    $int->start()->run()->stop();
}

1;
