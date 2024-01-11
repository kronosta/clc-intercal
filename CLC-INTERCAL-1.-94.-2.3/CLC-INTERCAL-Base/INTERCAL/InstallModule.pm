package Language::INTERCAL::InstallModule;

# This package helps installing an optional component of CLC-INTERCAL.

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

require 5.005;
use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/InstallModule.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Config qw(%Config);
use File::Spec::Functions qw(catfile curdir);
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use File::Copy qw(copy);
use ExtUtils::MakeMaker;
use Carp;

my $XS_VERSION = do {
    my ($v, @v) = split(/\./, $VERSION);
    @v = map { sprintf "%03d", $_ + 500 } @v;
    "$v." .  join('', @v);
};

my %extras = (
    manifest  => [],
    constants => [],
    postamble => [],
    usemodule => [],
);

my $type = '';
my $pm_dir = 'INTERCAL';
my $iacc_dir = 'Include';
my $iacc_suffix = 'iacc';
my $sick_suffix = 'i';
my $iasm_suffix = 'iasm';
my $bin_dir = 'bin';

my @iacc = ();
my @sick = ();
my @iasm = ();
my @bin = ();
my %pmcopy = ();
my %xscopy = ();

# Check for --avoid-xs and remove it from @ARGV - in case it confuses some
# later version of ExtUtils::MakeMaker; note that we ask for it to be
# typed exactly, apart from the letter case
my $strip_argv = 1;
sub check_avoid_xs {
    if ($strip_argv) {
	my @av = grep { lc($_) ne '--avoid-xs' } @ARGV;
	if (@av != @ARGV) {
	    $ENV{CLC_INTERCAL_AVOID_XS} = 42;
	    @ARGV = @av;
	}
    }
    $ENV{CLC_INTERCAL_AVOID_XS} && $ENV{CLC_INTERCAL_AVOID_XS} == 42;
}

sub module_search {
    @_ > 1 or croak "Usage: module_search(LIST)";
    for my $im (@_) {
	my ($link, $check, $code, @args) = @$im;
	my $is_xs = $link =~ /.xs$/;
	$is_xs && check_avoid_xs() and next;
	$code->(@args) or next;
	defined $check && ! $check->() and next;
	my %ifmodule;
	if ($is_xs) {
	    $ifmodule{"INET/Interface.xs"} = "links/$link";
	} else {
	    $ifmodule{"INET/Interface.pm"} = "links/$link";
	}
	return ($link, %ifmodule);
    }
    ();
}

sub module_check {
    @_ == 1 || @_ == 2 or croak "Usage: module_check(NAME [, VERSION])";
    my ($name, $version) = @_;
    if (defined $version) {
	return eval "use $name '$version'; 1" || 0;
    } else {
	return eval "require $name; 1" || 0;
    }
}

sub compile_check {
    @_ == 1 or croak "Usage: compile_check(SOURCE)";
    my ($source) = @_;
    $Config{cc} or return 0;
    my ($cfh, $cfn) = tempfile('intercalXXXXXX', SUFFIX => '.c', UNLINK => 1);
    print $cfh $source or die "$cfn: $!\n";
    reset $cfh;
    open(my $svout, '>&STDOUT') or die "Cannot dup() STDOUT: $!\n";
    open(my $sverr, '>&STDERR') or die "Cannot dup() STDERR: $!\n";
    open(STDOUT, '>/dev/null');
    open(STDERR, '>/dev/null');
    (my $obj = $cfn) =~ s/\.c$/$Config{exe_ext}/;
    my $ok = system($Config{cc}, '-o', $obj, $cfn) == 0;
    open(STDOUT, '>&', $svout);
    open(STDERR, '>&', $sverr);
    close $cfh;
    $ok && ! -x $obj and $ok = 0;
    unlink $cfn;
    unlink $obj;
    $ok;
}

sub in_bundle {
    $ENV{CLC_INTERCAL_BUNDLE}
	&& $ENV{CLC_INTERCAL_BUNDLE} eq '42'
	&& $ENV{CLC_INTERCAL_ROOT};
}

sub add_extra {
    @_ && ! (@_ % 2) or croak "Usage: add_extra(WHAT => CODE [, WHAT => CODE]...)";
    while (@_) {
	my $what = shift;
	my $code = shift;
	exists $extras{lc $what} or croak "Invalid WHAT: $what";
	push @{$extras{lc $what}}, $code;
    }
}

sub install {
    @_ >= 2 && @_ % 2 == 0
	or croak "Usage: install Language::INTERCAL::InstallModule TYPE [, OPTION => VALUE]...";
    my $class = shift;
    $type = shift;
    my %options;
    while (@_) {
	my $opt = shift;
	my $val = shift;
	$options{lc $opt} = $val;
    }

    open(MANIFEST, "MANIFEST")
	or die "Sorry, I can't function without file \"MANIFEST\"\n";

    my %find_link;
    my %xs_files;
    if ($options{link}) {
	for my $l (sort keys %{$options{link}}) {
	    my $c = $l;
	    if ($c =~ s/\.xs$/.c/) {
		(my $pm = $l) =~ s/\.xs$/.pm/;
		(my $lpm = $options{link}{$l}) =~ s/\.xs$/.pm/;
		$xscopy{$l} = $options{link}{$l};
		$xscopy{$pm} = $lpm;
		$xs_files{"blib/xs/$l"} = "blib/xs/$c";
		# we need to copy the files now or WriteMakefile fails
		(my $pdir = "blib/xs/$l") =~ s|/[^/]*$||;
		make_path($pdir);
		copy($options{link}{$l}, "blib/xs/$l");
		copy($lpm, "blib/xs/$pm");
		# and we also need to copy the pm file to blib/lib ...
		$pmcopy{$pm} = $lpm;
	    } else {
		$pmcopy{$l} = $options{link}{$l};
	    }
	    $find_link{$options{link}{$l}} = 0;
	}
    }
    while (<MANIFEST>) {
	chomp;
	s/\s+\S+$//;
	delete $find_link{$_};
	my $on = $_;
	if (s#^$pm_dir/*##o) {
	    if (s#^$iacc_dir/*##o) {
		push @iacc, $1 if /^(.*)\.$iacc_suffix$/o;
		push @sick, $1 if /^(.*)\.$sick_suffix$/o;
		push @iasm, $1 if /^(.*)\.$iasm_suffix$/o;
	    }
	} elsif (m#^$bin_dir/#o) {
	    s/\s+\S+$//;
	    push @bin, $_;
	}
	for my $extra (@{$extras{manifest}}) {
	    &$extra;
	}
    }
    close MANIFEST;
    keys %find_link
	and die "Internal error: cannot find linked files in MANIFEST (" .
		join(' ', sort keys %find_link) . ")\n";

    my %req = (
	'Carp' => 0,
	'Exporter' => 0,
    );
    if ($options{prereq}) {
	$req{$_} = $options{prereq}{$_} for keys %{$options{prereq}};
    }

    my @filter = ();
    if ($options{generate}) {
	my $generate;
	if ($type eq 'Base') {
	    $generate = 'Generate';
	} elsif (in_bundle()) {
	    my $clcroot = $ENV{CLC_INTERCAL_ROOT};
	    $generate = catfile($clcroot, 'Generate');
	} else {
	    $generate = '-MLanguage::INTERCAL::Generate -e "Language::INTERCAL::Generate::Generate()"';
	}
	@filter = (PM_FILTER => "\$(PERL) $generate");
    }

    # NAME must be Language::INTERCAL because our modules are installed
    # there, even if this is not Base
    WriteMakefile(NAME => "Language::INTERCAL",
		  DISTNAME => "CLC-INTERCAL-$type",
		  EXE_FILES => \@bin,
		  VERSION => $VERSION,
		  XS_VERSION => $XS_VERSION,
		  PERL_MALLOC_OK => 1,
		  @filter,
		  PREREQ_PM => \%req,
		  XSMULTI => 1,
		  XS => \%xs_files,
		  clean => { FILES => 'iacc_to_io sick_to_io' },
		  ($type eq 'Base' ? ( realclean => { FILES => 'aux/iacc.src aux/asm.bc' } ) : ()),
		  NO_META => 1,
		  NO_MYMETA => 1,
    );
}

package MY;
use File::Spec::Functions qw(catfile catdir curdir);

BEGIN {
    *in_bundle = \&Language::INTERCAL::InstallModule::in_bundle;
}

sub makefile {
    # remaking the Makefile breaks when running as part of the bundle;
    # instead we'll have a check in the top-level Makefile
    in_bundle() or return shift->SUPER::makefile(@_);
    '';
}

sub constants {
    my $i = shift->SUPER::constants(@_);
    my $clcroot = curdir();
    my $dist = $type eq 'Base';
    my @rcdir = (catdir($clcroot, qw(INTERCAL Include)));
    my @incdir = ([catdir($clcroot, 'INTERCAL'),
		   catdir($clcroot, qw(blib arch)),
		   catdir($clcroot, qw(blib lib))]);
    my $sicklib = '';
    if (in_bundle()) {
	$clcroot = $ENV{CLC_INTERCAL_ROOT};
	push @rcdir, catdir($clcroot, qw(INTERCAL Include));
	my $libdir = "\"-I$clcroot\/\$(INST_ARCHLIB)\" \"-I$clcroot\/\$(INST_LIB)\"";
	for my $ld (@{$extras{usemodule}}) {
	    (my $rd = $clcroot) =~ s/-Base$/-$ld/;
	    $libdir .= " \"-I$rd\/\$(INST_ARCHLIB)\" \"-I$rd\/\$(INST_LIB)\"";
	    $sicklib .= " \"-I$rd\/\$(INST_ARCHLIB)\" \"-I$rd\/\$(INST_LIB)\"";
	    my $rcdir = catdir($rd, qw(INTERCAL Include));
	    -d $rcdir and push @rcdir, $rcdir;
	    push @incdir, [catdir($rd, 'INTERCAL'),
			   catdir($rd, qw(blib arch)),
			   catdir($rd, qw(blib lib))];
	}
	$i =~ s/^(PERL\s*=.*)$/$1 $libdir/gm;
	$i =~ s/^(FULLPERL\s*=.*)$/$1 $libdir/gm;
	my $rcdir = catdir($clcroot, qw(INTERCAL Include));
	-d $rcdir and push @rcdir, $rcdir;
	push @incdir, [catdir($clcroot, 'INTERCAL'),
		       catdir($clcroot, qw(blib arch)),
		       catdir($clcroot, qw(blib lib))];
	$dist = 1;
    } elsif ($type ne 'Base') {
	push @rcdir, grep { -d $_ } map { catdir($_, qw(Language INTERCAL Include)) } @INC;
	push @incdir, grep { -d $_->[0] } map { [catdir($_, qw(Language INTERCAL)), $_] } @INC;
    }
    my %rcfile;
    for my $rcdir (@rcdir) {
	opendir(RCDIR, $rcdir) or next;
	while (defined (my $ent = readdir RCDIR)) {
	    $ent =~ /^\./ and next;
	    $ent =~ /\.sickrc$/i or next;
	    my $fn = catfile($rcdir, $ent);
	    -f $fn or next;
	    exists $rcfile{$ent} and next;
	    $rcfile{$ent} = $fn;
	}
	closedir RCDIR;
    }
    exists $rcfile{'system.sickrc'} or die "Cannot find a system.sickrc, is CLC-INTERCAL installed?\n";
    my $rcfile = ' --rcfile=' . (delete $rcfile{'system.sickrc'});
    my $extensions = '';
    my $libraries = '';
    for my $ent (sort keys %rcfile) {
	$rcfile .= " --rcfile=$rcfile{$ent}";
	$ent =~ s/\.sickrc$//i;
	# see if this extension exists
	(my $ename = $ent) =~ s/[^_\w]+/_/g;
	for my $ip (@incdir) {
	    my ($testdir, @libdir) = @$ip;
	    -f catfile($testdir, $ename, 'Extend.pm') or next;
	    $extensions .= " --extension=$ename";
	    $libraries .= " -I$_" for @libdir;
	    last;
	}
    }
    $i .= "\n# Needed to run iacc\n";
    $i .= "INST_IACC = \$(INST_LIB)/Language/INTERCAL/Include\n";
    $i .= "INST_MODULE = \$(INST_LIB)/Language/INTERCAL\n";
    $i .= "INST_XS = blib/xs\n";
    $i .= "INST_IOFILES = blib/iofiles\n";
    $i .= "SICK_OPTIONS = --build$extensions$rcfile --batch --bug=0 --ubug=0 --stdtrace=/dev/null --notrace\n";
#    $i .= "SICK_OPTIONS += -v\n";
    $i .= "SICK = \$(FULLPERL) -I\$(INST_ARCHLIB) -I\$(INST_LIB)$sicklib $libraries \\\n";
    my $sick = $dist
	     ? "-I$clcroot/\$(INST_ARCHLIB) -I$clcroot/\$(INST_LIB) $clcroot/\$(INST_SCRIPT)/sick"
	     : "-S sick";
    $i .= "\t-I\$(INST_ARCHLIB) -I\$(INST_LIB) $sick \\\n";
    $i .= "\t\$(SICK_OPTIONS)\n";
    $i .= "CLC_INTERCAL_TYPE = $type\n";
    # we've managed to confuse MakeMaker thoroughly
    $i =~ s|/auto/blib/xs/|/auto/Language/INTERCAL/|g;
    for my $extra (@{$extras{constants}}) {
	$i .= &$extra;
    }
    $i;
}

sub dynamic_bs {
    my $i = shift->SUPER::dynamic_bs(@_);
    # we've managed to confuse MakeMaker thoroughly
    $i =~ s|/auto/blib/xs/|/auto/Language/INTERCAL/|g;
    $i;
}

sub dynamic_lib {
    my $i = shift->SUPER::dynamic_lib(@_);
    # we've managed to confuse MakeMaker thoroughly
    $i =~ s|/auto/blib/xs/|/auto/Language/INTERCAL/|g;
    $i;
}

sub test {
    my $i = shift->SUPER::test(@_);
    if (in_bundle()) {
	my $clcroot = $ENV{CLC_INTERCAL_ROOT};
	$i =~ s/('\$\(INST_ARCHLIB\)')/$1, '$clcroot\/\$(INST_ARCHLIB)', '$clcroot\/\$(INST_LIB)'/gm;
	$i =~ s/("-I\$\(INST_ARCHLIB\)")/$1 "-I$clcroot\/\$(INST_ARCHLIB)" "-I$clcroot\/\$(INST_LIB)"/gm;
    }
    $i;
}

sub xs_o {
    my $i = shift->SUPER::xs_o(@_);
    $i =~ s/(-D(?:XS_)?VERSION=\\")(?:undef|\Q$Language::INTERCAL::InstallModule::VERSION\E)/$1$XS_VERSION/g;
    $i;
}

sub postamble {
    my $postpre = '';
    my $iacc = '';

    my $i = shift->SUPER::postamble(@_);
    if ($type eq 'Base') {
	$postpre = '$(INST_IOFILES)/postpre.io';
	$iacc = '$(INST_IOFILES)/iacc.io';
	$i .= <<EOF;
$postpre : pm_to_blib \$(INST_IOFILES)/\$(DFSEP).exists aux/mkpostpre
	\$(MAKE) -C aux PERL=\$(ABSPERLRUN) postpre

$iacc : pm_to_blib \$(INST_IOFILES)/\$(DFSEP).exists aux/mkfiles aux/iacc.prefix aux/iacc.prefix
	\$(MAKE) -C aux PERL=\$(ABSPERLRUN) iacc

IACC_IO = \$(INST_IOFILES)/iacc.io
POSTPRE_IO = --postpre \$(INST_IOFILES)/postpre.io

EOF
    } else {
	$i .= <<EOF;
IACC_IO = iacc
POSTPRE_IO =

EOF
    }

    my $mod_pre = '';
    for my $mod (sort keys %pmcopy) {
	$i .= <<EOI;
pure_all :: pm_to_blib \$(INST_MODULE)/$mod
	\$(NOECHO) \$(NOOP)

\$(INST_MODULE)/$mod : $pmcopy{$mod}
	\$(CP) $pmcopy{$mod} \$(INST_MODULE)/$mod

### PM ### $pmcopy{$mod} ### $mod ###

EOI
	$mod_pre .= " \$(INST_MODULE)/$mod";
    }

    my %pdir;
    my %adir;
    for my $mod (sort keys %xscopy) {
	my $pdir = '';
	my $adir = '';
	if ($mod =~ m|/|) {
	    $adir = $mod;
	    $adir =~ s|\.[^\.]*$||;
	    $adir = "/$adir";
	    $pdir = $mod;
	    $pdir =~ s|/[^/]*$||;
	    $pdir = "/$pdir";
	}
	$pdir{$pdir} = 1;
	$adir{$adir} = 1;
	$i .= <<EOI;
pure_all :: pm_to_blib \$(INST_XS)/$mod
	\$(NOECHO) \$(NOOP)

\$(INST_XS)/$mod : $xscopy{$mod} \$(INST_XS)$pdir/\$(DFSEP).exists
	\$(CP) $xscopy{$mod} \$(INST_XS)/$mod

### XS ### $xscopy{$mod} ### $mod ###

EOI
    }

    for my $pdir (sort { length($a) <=> length($b) || $a cmp $b } keys %pdir) {
	$i .= "\$(INST_XS)$pdir/\$(DFSEP).exists :: Makefile.PL\n"
	    . "\t\$(NOECHO) \$(MKPATH) \$(INST_XS)$pdir\n"
	    . "\t\$(NOECHO) \$(CHMOD) 755 \$(INST_XS)$pdir\n"
	    . "\t\$(NOECHO) \$(TOUCH) \$(INST_XS)$pdir/\$(DFSEP).exists\n\n";
    }

    for my $adir (sort { length($a) <=> length($b) || $a cmp $b } keys %adir) {
	$i .= "\$(INST_ARCHLIB)/auto/Language/INTERCAL$adir\$(DFSEP).exists "
	    . "\$(INST_ARCHLIB)/auto/Language/INTERCAL$adir/\$(DFSEP).exists :: Makefile.PL\n"
	    . "\t\$(NOECHO) \$(MKPATH) \$(INST_ARCHLIB)/auto/Language/INTERCAL$adir\n"
	    . "\t\$(NOECHO) \$(CHMOD) 755 \$(INST_ARCHLIB)/auto/Language/INTERCAL$adir\n"
	    . "\t\$(NOECHO) \$(TOUCH) \$(INST_ARCHLIB)/auto/Language/INTERCAL$adir/\$(DFSEP).exists\n\n";
    }

    $i .= "\$(INST_IOFILES)/\$(DFSEP).exists :: Makefile.PL\n"
	. "\t\$(NOECHO) \$(MKPATH) \$(INST_IOFILES)\n"
	. "\t\$(NOECHO) \$(CHMOD) 755 \$(INST_IOFILES)\n"
	. "\t\$(NOECHO) \$(TOUCH) \$(INST_IOFILES)/\$(DFSEP).exists\n\n";

    $i .= <<EOI for @iacc;
pure_all :: pm_to_blib $postpre $iacc \$(INST_IACC)/$_.io
	\$(NOECHO) \$(NOOP)

\$(INST_IACC)/$_.io : $postpre $iacc \$(INST_IACC)/$_.$iacc_suffix $mod_pre
	\$(SICK) -lObject \$(POSTPRE_IO) -p\$(IACC_IO) --output \$(INST_IACC)/$_.io \$(INST_IACC)/$_.$iacc_suffix

EOI

    $i .= <<EOI for @sick;
pure_all :: \$(INST_IACC)/$_.io
	\$(NOECHO) \$(NOOP)

\$(INST_IACC)/$_.io : \$(INST_IACC)/sick.io $mod_pre \\
		\$(INST_IACC)/postpre.io \\
		\$(INST_IACC)/$_.$sick_suffix
	\$(SICK) -lObject -psick --output \$(INST_IACC)/$_.io \$(INST_IACC)/$_.$sick_suffix

EOI

    $i .= <<EOI for @iasm;
pure_all :: \$(INST_IACC)/$_.io
	\$(NOECHO) \$(NOOP)

\$(INST_IACC)/$_.io : \$(INST_IACC)/asm.io \\
		\$(INST_IACC)/postpre.io \\
		\$(INST_IACC)/$_.$iasm_suffix $mod_pre
	\$(SICK) -lObject -pasm --output \$(INST_IACC)/$_.io \$(INST_IACC)/$_.$iasm_suffix

EOI

    for my $extra (@{$extras{postamble}}) {
	$i .= &$extra;
    }

    $i;
};

1;
