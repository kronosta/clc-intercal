package Language::INTERCAL::Rcfile;

# Configuration files for sick and intercalc

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Rcfile.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use File::Spec::Functions;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import has_type);
use Language::INTERCAL::GenericIO '1.-94.-2';
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension load_rc_extension);

@EXPORT_OK = qw(add_rcdef);

my %rcdefs = (
    # NAME      => [ CHECK,           PRINT            A? P? DESCRIPTION ]
    GLUE        => [ \&_c_glue,       \&_p_glue,       1, 0, 'How to glue C-INTERCAL libraries to a program' ],
    PRODUCE     => [ \&_c_backend,    undef,           0, 0, 'Default compiler back end' ],
    SCAN        => [ \&_c_scan,       \&_quote,        1, 0, 'Directories to search for C-INTERCAL libraries' ],
    SPEAK       => [ \&_c_interface,  undef,           1, 1, 'Default user interfaces' ],
    UNDERSTAND  => [ \&_c_understand, \&_p_understand, 1, 0, 'Suffix to parser mapping' ],
    WRITE       => [ \&_c_charset,    undef,           1, 1, 'Character sets used for guessing' ],
);

sub add_rcdef {
    @_ == 6 or croak "Usage: add_rcdef(NAME, CHECK, PRINT, ARRAY?, PRIORITY?, DESCRIPTION)";
    my ($name, $check, $print, $array, $prio, $description) = @_;
    exists $rcdefs{uc $name} and croak "\U$name\Q already exists";
    $prio and ! $array and croak "Cannot have PRIORITY for a scalar\n";
    $rcdefs{uc $name} = [$check, $print, $array, $prio, $description];
}

sub new {
    @_ == 1 or croak "Usage: new Language::INTERCAL::Rcfile";
    my ($class) = @_;
    my %data = ();
    for my $k (keys %rcdefs) {
	$data{$k} = $rcdefs{$k}[2] ? [] : '';
    }
    my @include =
	grep { -d $_ }
	     map { catdir($_, qw(Language INTERCAL Include)) }
		 @INC;
    my @system = grep { -d $_ } qw(/etc/sick);
    # TODO - make the following portable (is there such a thing?)
    my @home = ();
    if ($ENV{HOME}) {
	@home = (homedir => $ENV{HOME});
    } else {
	my $name = getlogin;
	if (! $name || ! getpwnam($name)) {
	    $name = getpwuid($<);
	}
	if ($name && getpwnam($name)) {
	    @home = (homedir => (getpwnam($name))[7]);
	}
    }
    bless {
	options => {
	    rcfile => [],
	    rclist => [],
	    rcskip => [],
	    include => \@include,
	    postinclude => \@include,
	    system => \@system,
	    nouserrc => 0,
	    nosystemrc => 0,
	    build => 0,
	    postpre => '',
	},
	imitate => 'sick',
	userinc => 0,
	data => \%data,
	@home,
    }, $class;
}

sub imitate {
    @_ == 2 or croak "Usage: RCFILE->imitate(IMITATE)";
    my ($rc, $who) = @_;
    $who =~ /^s?ick$|^1972$/i or croak "Invalid IMITATE $who";
    $rc->{imitate} = lc($who);
    if (exists $rc->{loaded}) {
	my %data = ();
	for my $k (keys %rcdefs) {
	    $data{$k} = ref $rcdefs{$k}[2] ? [] : '';
	}
	$rc->{data} = \%data;
	$rc->load($rc->{loaded});
    }
}

sub setoption {
    @_ == 3 or croak "Usage: RCFILE->setoption(NAME, VALUE)";
    my ($rc, $name, $value) = @_;
    $name eq 'rcfind' and return $rc->rcfind($value);
    exists $rc->{options}{$name}
	or die "Unknown option $name\n";
    if (ref $rc->{options}{$name}) {
	if ($name eq 'include') {
	    my $userinc = $rc->{userinc}++;
	    splice(@{$rc->{options}{$name}}, $userinc, 0, $value);
	} else {
	    push @{$rc->{options}{$name}}, $value;
	}
    } else {
	$rc->{options}{$name} = $value;
    }
    $rc;
}

sub rcfind {
    @_ == 2 or croak "Usage: RCFILE->rcfind(EXTENSION)";
    my ($rc, $ext) = @_;
    $ext eq 'system' or load_extension($ext);
    $ext .= '.sickrc';
    for my $inc (@INC) {
	my $file = catfile($inc, qw(Language INTERCAL Include), $ext);
	-f $file or next;
	push @{$rc->{options}{rcfile}}, $file;
	return $rc;
    }
    croak "RC not found for $ext";
}

sub getoption {
    @_ == 2 or croak "Usage: RCFILE->getoption(NAME)";
    my ($rc, $name) = @_;
    exists $rc->{options}{$name}
	or die "Unknown option $name\n";
    $rc->{options}{$name};
}

sub getitem {
    @_ == 2 || @_ == 3 or croak "Usage: RCFILE->getitem(NAME [, EMPTY_OK])";
    my ($rc, $name, $empty_ok) = @_;
    exists $rcdefs{$name}
	or die "Unknown item $name\n";
    if (! exists $rc->{data}{$name}) {
	$empty_ok and return ();
	die "Undefined item $name\n";
    }
    $rcdefs{$name}[2] or return $rc->{data}{$name};
    $rcdefs{$name}[3] or return @{$rc->{data}{$name}};
    return map { $_->[0] } sort { $a->[1] <=> $b->[1] } @{$rc->{data}{$name}};
}

sub putitem {
    @_ == 3 or croak "Usage: RCFILE->putitem(NAME, VALUE)";
    my ($rc, $name, $value) = @_;
    exists $rcdefs{$name}
	or die "Unknown item $name\n";
    my $is_home;
    if ($rcdefs{$name}[2]) {
	ref $value && has_type($value, 'ARRAY')
	    or die "Value for $name should be an array\n";
	if ($rcdefs{$name}[3]) {
	    my ($nv, $np) = (0, 0);
	    for my $v (@$value) {
		if (ref $v) {
		    has_type($v, 'ARRAY') && @$v == 2
			or die "Invalid value for $name\n";
		    my ($prn, $prio) = @$v;
		    ref $prn || ref $prio and die "Invalid value for $name\n";
		    $prio =~ /^(\d+)$/ or die "Invalid priority for $name\n";
		    $np++;
		} else {
		    $nv++;
		}
	    }
	    $np > 0 && $nv > 0 and die "Cannot mix simple values and priority\n";
	    # if necessary, make up some fake prioriries
	    $nv > 0 and $value = [map { [$value->[$_], $_] } (0..$#$value)];
	    $is_home = [undef, map { [undef, undef, @$_] } @$value];
	} else {
	    $is_home = [undef, map { [undef, undef, $_] } @$value];
	}
    } else {
	$is_home = [undef, $value];
    }
    $rc->{data}{$name} = $value;
    $rc->{is_home}{$name} = $is_home;
    $rc;
}

sub _locate_module {
    my ($rc, $full_include, @module) = @_;
    $rc->{options}{build} and return;
    $rc->{loaded} and return;
    $full_include or unshift @module, qw(Language INTERCAL);
    for my $inc ($full_include ? @{$rc->{options}{include}} : @INC) {
	my $mod = catfile($inc, @module);
	-f $mod and return;
    }
    $full_include and die "Cannot find object $module[-1]\n";
    $module[-1] =~ s/\.pm$//;
    die "Cannot find module " . join('::', @module) . "\n";
}

sub _quote {
    my ($value) = @_;
    $value =~ /\s/ or return $value;
    $value =~ /'/ or return "'$value'";
    $value =~ s/([\\"])/\\$1/g;
    return "\"$value\"";
}

sub _quote_list {
    my ($values) = @_;
    return join(' + ', map { _quote($_) } @$values);
}

sub _unquote {
    my ($orig, $ln, $what) = @_;
    if ($$ln =~ s/^(['"])(.*?)\1\s*//) {
	return $2;
    } elsif ($$ln =~ s/^(\S+)\s*//) {
	return $1;
    } else {
	die "Invalid $orig\: missing $what\n";
    }
}

sub _unquote_list {
    my ($orig, $ln, $what) = @_;
    my @value = (_unquote($orig, $ln, $what));
    while ($$ln =~ s/^\+\s*//) {
	push @value, _unquote($orig, $ln, $what);
    }
    \@value;
}

sub _c_glue {
    my ($rc, $mode, $ln) = @_;
    # not sure why I went and defined such an awkward syntax...
    my $orig = $ln;
    my $file = _unquote($orig, \$ln, 'file name');
    my $optfile;
    $ln =~ s/^\s*AND\s*IF\s*OPTIMISED\s*//i
	and $optfile = _unquote($orig, \$ln, 'file name');
    $ln =~ s/^\s*TO\s*THE\s*END\s*OF\s*THE\s*PROGRAM\s*//i
	or die "Missing 'TO THE END OF THE PROGRAM'";
    my ($compiler, $base_yes, $base_no, @ranges);
    if ($ln =~ s/^\s*WHEN\s*//i) {
	while (1) {
	    if ($ln =~ s/^\s*COMPILER\s*IS\s*//i) {
		defined $compiler and die "Cannot test on two compilers: make two separate rules\n";
		$compiler = _unquote($orig, \$ln, 'compiler');
		$compiler =~ /^[@\w]+$/ or die "Invalid compiler '$compiler'\n";
	    } elsif ($ln =~ s/^\s*BASE\s*IS\s*NOT\s*//i) {
		defined $base_no and die "Cannot test on two bases: make two separate rules\n";
		$base_no = _unquote($orig, \$ln, 'base');
		$base_no =~ /^[2-7]+$/ or die "Invalid base '$base_no'\n";
	    } elsif ($ln =~ s/^\s*BASE\s*IS\s*//i) {
		defined $base_yes and die "Cannot test on two bases: make two separate rules\n";
		$base_yes = _unquote($orig, \$ln, 'base');
		$base_yes =~ /^[\@2-7]$/ or die "Invalid base '$base_yes'\n";
	    } elsif ($ln =~ s/^\s*PROGRAM\s*USES\s*UNDEFINED\s*LABELS\s*BETWEEN\s*(\d+)\s*AND\s*(\d+)\s*//i) {
		$1 <= $2 && $1 > 0 && $2 < 65536 or die "Invalid range: $1 to $2\n";
		push @ranges, [$1, $2];
	    } elsif ($ln =~ s/^\s*PROGRAM\s*USES\s*UNDEFINED\s*LABEL\s*(\d+)\s*//i) {
		push @ranges, [$1, $1];
	    } else {
		die "Invalid rule: $ln\n";
	    }
	    $ln =~ s/^\s*AND\s*//i or last;
	}
    }
    $ln eq '' or die "Extra stuff at the end: $ln\n";
    $file =~ /\@/ && ! (defined $base_yes && $base_yes =~ /\@/)
	and die "Cannot use '\@' in file name in this rule\n";
    defined $base_yes && $base_yes =~ /\@.*\@/
	and die "Onli one '\@' allowed in base\n";
    my $cregex;
    if (defined $compiler) {
	($cregex = $compiler) =~ s/\@/.*/g;
	$cregex = qr/^$cregex$/i;
    }
    [$file, $optfile, $compiler, $cregex, $base_yes, $base_no, @ranges];
}

sub _p_glue {
    my ($src) = @_;
    my ($file, $optfile, $compiler, $cregex, $base_yes, $base_no, @ranges) = @$src;
    my $value = _quote($file);
    defined $optfile and $value .= ' AND IF OPTIMISED ' . _quote($optfile);
    $value .= ' TO THE END OF THE PROGRAM';
    my $where = 'WHEN';
    if (defined $compiler) {
	$value .= "\n      $where COMPILER IS " . _quote($compiler);
	$where = ' AND';
    }
    if (defined $base_yes) {
	$value .= "\n      $where BASE IS " . _quote($base_yes);
	$where = ' AND';
    }
    if (defined $base_no) {
	$value .= "\n      $where BASE IS NOT " . _quote($base_no);
	$where = ' AND';
    }
    for my $range (@ranges) {
	my ($low, $high) = @$range;
	$value .= "\n      $where PROGRAM USES UNDEFINED LABEL";
	$where = ' AND';
	if ($low == $high) {
	    $value .= " $low";
	} else {
	    $value .= "S BETWEEN $low AND $high";
	}
    }
    $value;
}

sub _c_backend {
    my ($rc, $mode, $ln) = @_;
    _locate_module($rc, 0, 'Backend', "$ln.pm");
    $ln;
}

sub _c_scan {
    my ($rc, $mode, $ln) = @_;
    my $path = _unquote($ln, \$ln, 'path');
    # in theory here we'd be checking if $path is correct...
    $path;
}

sub _c_interface {
    my ($rc, $mode, $ln) = @_;
    _locate_module($rc, 0, 'Interface', "$ln.pm");
    $ln;
}

sub _c_charset {
    my ($rc, $mode, $ln) = @_;
    $ln eq 'ASCII' or _locate_module($rc, 0, 'Charset', "$ln.pm");
    $ln;
}

sub _c_understand {
    my ($rc, $mode, $ln) = @_;
    my @suffix;
    for my $suffix (@{_unquote_list($mode, \$ln, 'SUFFIX')}) {
	$suffix eq '' and die "Invalid SUFFIX, empty string not allowed\n";
	my $first = quotemeta(substr($suffix, 0, 1));
	my @re = map { quotemeta } split(/\@+/, $suffix);
	my $re = join("([^$first]*)", @re);
	$re = qr/^$re$/;
	push @suffix, [$suffix, $re];
    }
    my %data = (SUFFIX => \@suffix);
    while ($ln =~ s/^(AS|WITH|RETRYING|IGNORING)\s*//i) {
	my $kw = $1;
	my $ukw = uc $kw;
	exists $data{$ukw} and die "Duplicate $kw\n";
	$data{$ukw} = $ukw eq 'AS' || $ukw eq 'RETRYING'
		    ? _unquote($mode, \$ln, "value for $kw")
		    : _unquote_list($mode, \$ln, "value for $kw");
    }
    $ln eq '' or die "Invalid $mode\: extra stuff at end: $ln\n";
    exists $data{AS} or die "Missing AS\n";
    if (exists $data{WITH}) {
	for my $with (@{$data{WITH}}) {
	    _locate_module($rc, 1, "$with.io");
	}
    }
    \%data;
}

sub _p_understand {
    my ($value) = @_;
    my @result;
    push @result, _quote_list([sort map { $_->[0] } @{$value->{SUFFIX}}]);
    push @result, "AS " . _quote($value->{AS});
    $value->{WITH} and push @result, "WITH " . _quote_list($value->{WITH});
    defined $value->{RETRYING} and push @result, "RETRYING" . _quote($value->{RETRYING});
    $value->{IGNORING} and push @result, "IGNORING " . _quote_list([sort @{$value->{IGNORING}}]);
    join("\n\t", @result);
}

sub _equal {
    my ($mode, $a, $b) = @_;
    if ($rcdefs{$mode}[1]) {
	$a = $rcdefs{$mode}[1]->($a);
	$b = $rcdefs{$mode}[1]->($b);
    }
    return $a eq $b;
}

sub load {
    @_ == 1 || @_ == 2 or croak "Usage: RCFILE->load [(QUICK)]";
    my ($rc, $quick) = @_;
    my @rcfiles = @{$rc->{options}{rcfile}};
    if (! exists $rc->{home_rcfile} && exists $rc->{homedir}) {
	my $fn = catfile($rc->{homedir}, '.sickrc');
	$rc->{home_rcfile} = $fn;
    }
    if (! @rcfiles) {
	local $ENV{LC_COLLATE} = 'C'; # for repeatable sort
	my %rcfiles;
	# find all package-installed rcfiles
	for my $inc (@{$rc->{options}{include}}) {
	    opendir(my $dh, $inc) or next; # not supposed to happen but never mind
	    while (defined (my $ent = readdir $dh)) {
		$ent =~ /^(.+)\.sickrc$/ or next;
		my $fn = catfile($inc, $ent);
		if (exists $rcfiles{$ent}) {
		    push @{$rc->{options}{rclist}}, [0, $fn];
		    next;
		}
		my $extension = $1;
		$extension ne 'system' and load_rc_extension($extension);
		$rcfiles{$ent} = $fn;
	    }
	    closedir $dh;
	}
	if (exists $rcfiles{'system.sickrc'}) {
	    my $fn = delete $rcfiles{'system.sickrc'};
	    push @{$rc->{options}{rclist}}, [1, $fn];
	    push @rcfiles, $fn;
	}
	for my $fk (sort keys %rcfiles) {
	    my $fn = $rcfiles{$fk};
	    push @{$rc->{options}{rclist}}, [1, $fn];
	    push @rcfiles, $fn;
	}
	# add system RC files in uspecified order
	%rcfiles = ();
	for my $dir (@{$rc->{options}{system}}) {
	    opendir(my $dh, $dir) or next;
	    while (defined (my $ent = readdir $dh)) {
		$ent =~ /^\./ and next;
		my $fn = catfile($dir, $ent);
		if ($rc->{options}{nosystemrc} || exists $rcfiles{$ent}) {
		    push @{$rc->{options}{rclist}}, [0, $fn];
		    next;
		}
		push @{$rc->{options}{rclist}}, [1, $fn];
		push @rcfiles, $fn;
		$rcfiles{$ent} = 1;
	    }
	    closedir $dh;
	}
	# if there is a user RC file process that too
	if (exists $rc->{home_rcfile}) {
	    my $fn = $rc->{home_rcfile};
	    if (-f $fn) {
		if ($rc->{options}{nouserrc}) {
		    push @{$rc->{options}{rclist}}, [0, $fn];
		} else {
		    push @{$rc->{options}{rclist}}, [1, $fn];
		    push @rcfiles, $fn;
		}
	    }
	}
	$rc->{options}{rcfile} = \@rcfiles;
    }
    $rc->{loaded} = $quick;
    my %is_home;
    my %rcskip = map { (uc($_) => undef) } @{$rc->{options}{rcskip}};
    for my $rcfile (@rcfiles) {
	my $fh = Language::INTERCAL::GenericIO->new('FILE', 'w', $rcfile)
	    or die "$rcfile: $!\n";
	my $is_home = (exists $rc->{home_rcfile} && $rcfile eq $rc->{home_rcfile}) ? \%is_home : 0;
	my $text = $fh->write_text('');
	$text =~ s/^(\s*)//;
	my $tmp = $1;
	my $lno = ($tmp =~ tr/\n/\n/) + 1;
	my $line = 1;
	eval {
	    while ($text ne '') {
		my $do_this = 1;
		$line = $lno;
		my $imitate;
		if ($text =~ s/^(WHEN\s*I\s*IMITATE\s*(s?ick|1972)\s*)//si) {
		    ($tmp, $imitate) = ($1, lc $2);
		    $lno += ($tmp =~ tr/\n/\n/);
		    $do_this = $imitate eq $rc->{imitate};
		}
		if ($text =~ s/^((?:DO|PLEASE)\s*NOTE\s*)//si) {
		    $tmp = $1;
		    $lno += ($tmp =~ tr/\n/\n/);
		    $text =~ s/^(.*?)(WHEN\s*I\s*IMITATE|I[^\S\n]*CAN|I[^\S\n]*DO[^\S\n]*N['O]\s*T)/$2/si or last;
		    $tmp = $1;
		    $lno += ($tmp =~ tr/\n/\n/);
		    next;
		}
		if ($text =~ s/^(I[^\S\n]*DO[^\S\n]*N['O][^\S\n]*T\s*(\S+)\b\s*)//si) {
		    my ($tmp, $verb) = ($1, $2);
		    $lno += ($tmp =~ tr/\n/\n/);
		    my $uv = uc($verb);
		    if (! exists $rcdefs{$uv}) {
			$quick or die "No such verb \"$verb\"\n";
			next;
		    }
		    $rcdefs{$uv}[2] or die "Verb \"$verb\" cannot be negated\n";
		    $do_this && ! exists $rcskip{$uv} and $rc->{data}{$uv} = [];
		    $is_home and $is_home{$uv} = [$imitate];
		    next;
		}
		if ($text =~ s/(^I\s*CAN\s*)//si) {
		    my $tmp = $1;
		    my ($prio, $delete);
		    if ($text =~ s/^#(\d+)(\s*)//si) {
			$prio = $1;
			$tmp .= $2;
		    } elsif ($text =~ s/^('\s*T\s*|OT\s*)//si) {
			$delete = 1;
			$tmp .= $1;
		    }
		    $text =~ s/^(\S+)(\s*)//si or die "Missing Verb\n";
		    my $verb = $1;
		    $tmp .= $2;
		    $lno += ($tmp =~ tr/\n/\n/);
		    my $ov;
		    if ($text =~ s/
			^(.*?)
			(WHEN\s*I\s*IMITATE|
			 I[^\S\n]*CAN|
			 I[^\S\n]*DO[^\S\n]*N['O][^\S\n]*T|
			 (?:DO|PLEASE)\s*NOTE)
		    /$2/six) {
			$ov = $tmp = $1;
			$lno += ($tmp =~ tr/\n/\n/);
		    } else {
			$ov = $text;
			$text = '';
		    }
		    my $uv = uc($verb);
		    if (! exists $rcdefs{$uv}) {
			$quick or die "No such verb \"$verb\"\n";
			next;
		    }
		    if ($delete) {
			$rcdefs{$uv}[2] or die "Verb \"$verb\" cannot be remved\n";
		    } elsif ($prio) {
			$rcdefs{$uv}[3] or die "Verb \"$verb\" does not take a priority\n";
		    } else {
			$rcdefs{$uv}[3] and die "Verb \"$verb\" takes a priority\n";
		    }
		    $ov =~ s/\s+$//s;
		    my $cv = $rcdefs{$uv}[0]->($rc, $uv, $ov);
		    if ($rcdefs{$uv}[3]) {
			if ($do_this && ! exists $rcskip{$uv}) {
			    if ($delete) {
				@{$rc->{data}{$uv}} =
				    grep { ! _equal($uv, $cv, $_->[0]) } @{$rc->{data}{$uv}};
			    } else {
				push @{$rc->{data}{$uv}}, [$cv, $prio];
			    }
			}
			$is_home and push @{$is_home->{$uv}}, [$imitate, $delete, $cv, $prio];
		    } elsif ($rcdefs{$uv}[2]) {
			if ($do_this && ! exists $rcskip{$uv}) {
			    if ($delete) {
				@{$rc->{data}{$uv}} =
				    grep { ! _equal($uv, $cv, $_) } @{$rc->{data}{$uv}};
			    } else {
				push @{$rc->{data}{$uv}}, $cv;
			    }
			}
			$is_home and push @{$is_home->{$uv}}, [$imitate, $delete, $cv];
		    } else {
			exists $rcskip{$uv} or $rc->{data}{$uv} = $cv;
			$is_home and $is_home->{$uv} = [$imitate, $cv];
		    }
		    next;
		}
		$text = substr($text, 0, 20);
		$text =~ s/\n/\\n/g;
		die "Syntax error ($text)\n";
	    }
	};
	$@ and die "$rcfile.$line: $@";
    }
    $rc->{is_home} = \%is_home;
    $rc;
}

sub save {
    @_ >= 1 && @_ <= 3 or croak "Usage: RCFILE->save [(TO [, ALL?])]";
    my ($rc, $to, $all) = @_;
    if (! defined $to) {
	if (! exists $rc->{home_rcfile}) {
	    exists $rc->{homedir} or die "No idea what your home directory is!\n";
	    $rc->{home_rcfile} = catfile($rc->{homedir}, ".sickrc"),
	}
	$to = $rc->{home_rcfile};
	defined $all or $all = 0;
    }
    defined $all or $all = 1;
    my ($fh, $tmp);
    if (ref $to) {
	has_type($to, 'GLOB') or croak "Not a filehandle: $to\n";
	$fh = $to;
	$to = '-';
	$tmp = '(open filehandle)';
    } elsif ($to eq '-') {
	$tmp = '(standard output)';
	$fh = \*STDOUT;
    } else {
	$tmp = $to . '.tmp';
	open($fh, '>', $tmp) or die "$tmp: $!\n";
    }
    print $fh "PLEASE NOTE: This file was automatically generated while saving settings\n\n"
	or die "$tmp: $!\n";
    for my $data (sort keys %{$rc->{data}}) {
	$all || exists $rc->{is_home}{$data} or next;
	print $fh "PLEASE NOTE: $rcdefs{$data}[4]\n" or die "$tmp: $!\n"
	    if defined $rcdefs{$data}[4];
	if ($rcdefs{$data}[2]) {
	    if (exists $rc->{is_home}{$data} && ! $all) {
		my @d = @{$rc->{is_home}{$data}};
		if (@d && ! ref $d[0]) {
		    my $imitate = shift @d;
		    defined $imitate and print $fh "WHEN I AM IMITATING $imitate ";
		    print $fh "I DON'T $data\n" or die "$tmp: $!\n";
		}
		for my $vp (@d) {
		    my ($imitate, $delete, $prn, $prio) = @$vp;
		    if ($delete) {
			$prio = "'T";
		    } elsif ($rcdefs{$data}[3]) {
			$prio = ' #' . ($prio || 0);
		    } else {
			$prio = '';
		    }
		    $rcdefs{$data}[1] and $prn = $rcdefs{$data}[1]->($prn);
		    defined $imitate and print $fh "WHEN I AM IMITATING $imitate ";
		    print $fh "I CAN$prio $data $prn\n" or die "$tmp: $!\n";
		}
	    } else {
		print $fh "I DON'T $data\n" or die "$tmp: $!\n";
		for my $value (@{$rc->{data}{$data}}) {
		    my ($prn, $prio);
		    if ($rcdefs{$data}[3]) {
			($prn, $prio) = @$value;
			$prio = " #$prio";
		    } else {
			$prn = $value;
			$prio = '';
		    }
		    $rcdefs{$data}[1] and $prn = $rcdefs{$data}[1]->($prn);
		    print $fh "I CAN$prio $data $prn\n" or die "$tmp: $!\n";
		}
	    }
	} elsif (exists $rc->{is_home}{$data} && ! $all) {
	    my ($imitate, $prn) = @{$rc->{is_home}{$data}};
	    $rcdefs{$data}[1] and $prn = $rcdefs{$data}[1]->($prn);
	    defined $imitate and print $fh "WHEN I AM IMITATING $imitate ";
	    print $fh "I CAN $data $prn\n" or die "$tmp: $!\n";
	} else {
	    my $prn = $rc->{data}{$data};
	    $rcdefs{$data}[1] and $prn = $rcdefs{$data}[1]->($prn);
	    print $fh "I CAN $data $prn\n" or die "$tmp: $!\n";
	}
	print $fh "\n" or die "$tmp: $!\n";
    }
    if ($to ne '-') {
	close $fh or die "$tmp: $!\n";
	my $old = $to . '~';
	unlink($old);
	rename($to, $old);
	rename($tmp, $to) or die "rename($tmp, $to): $!\n";
    }
    $to;
}

1;
