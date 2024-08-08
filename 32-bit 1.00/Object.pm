package Language::INTERCAL::Object;

# Object file library

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Object.pm 1.-94.-2.4") =~ /\s(\S+)$/;

use Carp;
use Config;
use Language::INTERCAL::Exporter '1.-94.-2.1',
	qw(import is_intercal_number compare_version);
use Language::INTERCAL::GenericIO '1.-94.-2.1',
	qw($stdwrite $stdread $stdsplat $devnull);
use Language::INTERCAL::Parser '1.-94.-2.2';
use Language::INTERCAL::Optimiser '1.-94.-2.4';
use Language::INTERCAL::Splats '1.-94.-2.1', qw(faint SP_INDIGESTION SP_INTERNAL);
use Language::INTERCAL::ByteCode '1.-94.-2.4',
	qw(BC_STS BC_CRE BC_DES BC_NOT BC_DSX BC_LAB BC_QUA BC_BUG BC_BIT BC_FLA
	   BC_STR BC_UNS BC_UNA NUM_OPCODES BC bc_skip BCget is_constant);
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension);

use vars qw(@EXPORT_OK %EXPORT_TAGS @stmt_flags);
@EXPORT_OK = qw(
    UFLAG_nocreate UFLAG_nomultiple UFLAG_frozen
    @stmt_flags stmt_abstain stmt_quantum stmt_junk stmt_once stmt_again stmt_please
);
%EXPORT_TAGS = (
    UFLAG => [qw(UFLAG_nocreate UFLAG_nomultiple UFLAG_frozen)],
    SFLAG => [qw(@stmt_flags stmt_abstain stmt_quantum stmt_junk stmt_once stmt_again stmt_please)],
);

# unit flags; these are maintained by Object but could be used by the Interpreter to optimise things
use constant UFLAG_nocreate   => 0x01;
use constant UFLAG_nomultiple => 0x02;
use constant UFLAG_frozen     => 0x04;

# oldest objects we can write in and understand
use constant MIN_VERSION => '1.-94.-4';

# objects up to perversion OLD_VERSION have timestamps, so we need to know
# whether to skip and ignore them
use constant OLD_VERSION => '1.-94.-2.1';

# we always produce this object format, although we can understand others
use constant OBJECT_FORMAT => 2;

# minimum and maximum object format we understand
use constant MIN_OBJECT_FORMAT => 2;
use constant MAX_OBJECT_FORMAT => 2;

# flags stored in a bitmap in the object
use constant bm_is_optimiser    => 0x01;
use constant bm_is_compiler     => 0x02;
use constant bm_has_optimiser   => 0x04;

# flags stored in a bitmap in the statement
use constant stmt_abstain       => 0x01;  # BIT 0
use constant stmt_quantum       => 0x02;  # BIT 1
use constant stmt_junk          => 0x04;  # BIT 2
use constant stmt_once          => 0x08;  # BIT 3
use constant stmt_again         => 0x10;  # BIT 4
use constant stmt_please        => 0x20;  # BIT 5

# flag names
@stmt_flags = (
    [stmt_please,  'PLEASE'],
    [stmt_abstain, 'ABSTAINed'],
    [stmt_quantum, 'QUANTUM'],
    [stmt_junk,    'COMMENT'],
    [stmt_once,    'ONCE'],
    [stmt_again,   'AGAIN'],
);

# an object with TYPE set to one of these is a "compiler" for the purpose of
# storing comments (compilers never try to execute comments and don't have
# reinstate)
my %is_compiler = map { ($_ => undef) } qw(
    ASSEMBLER
    BASE
    COMPILER
    EXTENSION
    IACC
    OPTION
    POSTPRE
);

sub new {
    @_ == 1 or croak "Usage: new Language::INTERCAL::Object";
    my ($class) = @_;
    my $obj = _new($class, $VERSION, OBJECT_FORMAT, {});
    my $s = Language::INTERCAL::SymbolTable->new();
    $obj->{symbols} = $s;
    $obj->{parsers} = [
	Language::INTERCAL::Parser->new($s),
	Language::INTERCAL::Parser->new($s),
    ];
    $obj;
}

sub _new {
    my ($class, $perv, $form, $flags) = @_;
    bless {
	flags      => $flags,
	units      => [],
	bug        => [0, 1],
	perversion => $perv,
	format     => $form,
	optimiser  => scalar Language::INTERCAL::Optimiser->new,
    }, $class;
}

sub perversion {
    @_ == 1 or croak "Usage: OBJECT->perversion";
    my ($object) = @_;
    $object->{perversion};
}

sub format {
    @_ == 1 or croak "Usage: OBJECT->format";
    my ($object) = @_;
    $object->{format};
}

sub optimiser {
    @_ == 1 or croak "Usage: OBJECT->optimiser";
    my ($object) = @_;
    $object->{optimiser};
}

sub setbug {
    @_ == 3 or croak "Usage: OBJECT->setbug(TYPE, VALUE)";
    my ($object, $type, $value) = @_;
    $value < 0 || $value > 100 and croak "Invalid BUG value";
    $object->{bug} = [$type ? 1 : 0, $value];
    $object;
}

sub add_flag {
    @_ == 3 or croak "Usage: OBJECT->add_flag(NAME, VALUE)";
    my ($object, $flag, $value) = @_;
    $object->{flags}{$flag} = $value;
    $object;
}

sub has_flag {
    @_ == 2 or croak "Usage: OBJECT->has_flag(NAME)";
    my ($object, $flag) = @_;
    exists $object->{flags}{$flag};
}

sub flag_value {
    @_ == 2 or croak "Usage: OBJECT->flag_value(NAME)";
    my ($object, $flag) = @_;
    $object->{flags}{$flag};
}

sub delete_flag {
    @_ == 2 or croak "Usage: OBJECT->delete_flag(NAME)";
    my ($object, $flag) = @_;
    delete $object->{flags}{$flag};
    $object;
}

sub all_flags {
    @_ == 1 or croak "Usage: OBJECT->all_flags";
    my ($object) = @_;
    keys %{$object->{flags}};
}

sub symboltable {
    @_ == 1 or croak "Usage: OBJECT->symboltable";
    my ($object) = @_;
    $object->{symbols};
}

sub num_parsers {
    @_ == 1 or croak "Usage: OBJECT->num_parsers";
    my ($object) = @_;
    scalar @{$object->{parsers}};
}

sub parser {
    @_ == 2 or croak "Usage: OBJECT->parser(NUMBER)";
    my ($object, $number) = @_;
    $number < 1 || $number > @{$object->{parsers}}
	and croak "Invalid NUMBER";
    $object->{parsers}[$number - 1];
}

sub shift_parsers {
    @_ == 1 or croak "Usage: OBJECT->shift_parsers";
    my ($object) = @_;
    shift @{$object->{parsers}};
    my $p = Language::INTERCAL::Parser->new($object->{symbols});
    push @{$object->{parsers}}, $p;
}

sub write {
    @_ == 2 || @_ == 3 || @_ == 4
	or croak "Usage: write Language::INTERCAL::Object"
	       . "(FILEHANDLE [, JUST_FLAGS [, AVOID_SKIP?]])";
    my ($class, $fh, $fonly, $ask) = @_;
    my @fhdata = @{$fh->{data}};
    my $fhdataMatch = ("@fhdata" =~ m/(postpre\.io|iacc\.io)/);
    #print "fh location: @fhdata, matches: $fhdataMatch\n";
    unless ($ask) {
	while (1) {
	    my $line = $fh->write_text();
	    croak "Invalid Object Format (no __END__)"
		if ! defined $line || $line eq '';
	    last if $line =~ /__END__/ || $line =~ /__DATA__/;
	}
    }
    my $line = $fh->write_text();
    $line =~ /^CLC-INTERCAL (\S+) Object File\n$/
	or croak "Invalid Object Format (no PERVERSION)";
    my $perversion = $1;
    is_intercal_number($perversion)
	or croak "Invalid Object Perversion ($perversion)";
    compare_version($perversion, MIN_VERSION) >= 0
	or croak "Object too old to load with this perversion of sick";
    # the file format changed considerably after OLD_VERSION...
    compare_version($perversion, OLD_VERSION) <= 0
	and return _write_old($class, $fh, $perversion, $fonly, 1);
    # for a short time 1.-94.-2.2 had the old format, but it always
    # had all 0xff in the next 7 bytes
    my $maybe_ts = $fh->write_binary(7);
    $maybe_ts eq chr(0xff) x 7
	and return _write_old($class, $fh, $perversion, $fonly, 0);
    my ($format, $nflags, $nunits, $nparsers, $bitmap) =
	unpack('vvvvC', $maybe_ts . $fh->write_binary(2));
    # if we define a new OBJECT_FORMAT we'll have to change the next line so
    # that it can recognise more than one; for now it'll do
    $format < MIN_OBJECT_FORMAT
	and die "Object format ($format) too old\n";
    $format > MAX_OBJECT_FORMAT
	and die "Object format ($format) too new\n";
    my $optimiser = $bitmap & bm_is_optimiser;
    my $compiler = $bitmap & bm_is_compiler;
    my $discard = $optimiser || $compiler;
    my %flags;
    $optimiser and $flags{optimiser} = 0;
    $compiler and $flags{compiler} = 0;
    for (my $f = 0; $f < $nflags; $f++) {
	my ($nlen, $vlen) = unpack('vv', $fh->write_binary(4));
	my $fname = $fh->write_binary($nlen);
	my $fvalue = $fh->write_binary($vlen);
	$flags{$fname} = $fvalue;
    }
    my $obj = _new($class, $perversion, $format, \%flags);
    $fonly and return $obj;
    for (my $u = 0; $u < $nunits; $u++) {
	my $source = '';
	if (! $discard) {
	    my $slen = $fhdataMatch ? unpack('v', $fh->write_binary(2)) : unpack('V', $fh->write_binary(4));
	    $source = $fh->write_binary($slen);
	}
	my ($length, $ncptr, $uflags, $codelen) = $fhdataMatch
	? unpack('vvvv', $fh->write_binary(8))
	: unpack('VVvV', $fh->write_binary(14));
 #	print "length: $length, ncptr: $ncptr, codelen: $codelen\n";
	my $code = $fh->write_binary($codelen);
	my @cptr;
	while (@cptr < $ncptr) {
	    my ($sptr, $np) = $fhdataMatch ? unpack('vv', $fh->write_binary(4)) : unpack('VV', $fh->write_binary(8));
	    my @sptr;
	    for (my $p = 0; $p < $np; $p++) {
		my ($fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl) =
		    $fhdataMatch
			? 
			unpack('vvvvvvvvv', $fh->write_binary(18))
			: unpack('vVvvvvvvv', $fh->write_binary(20));
		my $ru;
		if (! $discard) {
		    my $rl = $fhdataMatch ? unpack('v', $fh->write_binary(2)) : unpack('V', $fh->write_binary(4));
		    $ru = $fh->write_binary($rl);
		    $ru eq '' and $ru = undef;
		}
		push @sptr, [$fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru];
	    }
	    push @cptr, [$sptr, \@sptr];
	}
	push @{$obj->{units}}, [$source, $length, $code, \@cptr, $uflags];
    }
    my $syms = Language::INTERCAL::SymbolTable->write($fh);
    $obj->{symbols} = $syms;
    $obj->{parsers} = [];
    for (my $p = 0; $p < $nparsers; $p++) {
	push @{$obj->{parsers}}, Language::INTERCAL::Parser->write($fh, $syms);
    }
    $bitmap & bm_has_optimiser
	and $obj->{optimiser} = Language::INTERCAL::Optimiser->write($fh);
    wantarray ? ($obj, $discard, 1) : $obj;
}

# write in pre-1.-94.-2.2 objects
sub _write_old {
    my ($class, $fh, $perversion, $fonly, $has_ts) = @_;
    # older objects have a timestamp in the next 7 bytes; newer objects
    # always fill it with 0xff; we ignore them if present
    $has_ts and $fh->write_binary(7);
    my $fcount = unpack('v', $fh->write_binary(2));
    my %flags = ();
    while ($fcount-- > 0) {
	my $flen = unpack('v', $fh->write_binary(2));
	my $fname = $fh->write_binary($flen);
	my $fvalue = '';
	$fvalue = $1 if $fname =~ s/=(.*)$//;
	$flags{$fname} = $fvalue;
    }
    my $obj = _new($class, $perversion, exists $flags{__object_format} ? 1 : 0,  \%flags);
    $fonly and return $obj;
    my ($fmask, $fsize);
    if (exists $flags{__object_format}) {
	$fmask = 'vvvvvvvCCvvv';
	$fsize = 22;
    } else {
	$fmask = 'vvvvvvCCCvvv';
	$fsize = 21;
    }
    my $clen = unpack('v', $fh->write_binary(2));
    my $code = $fh->write_binary($clen);
    my $ns = unpack('v', $fh->write_binary(2));
    my %code = ();
    while ($ns-- > 0) {
	my ($sval, $nr) = unpack('vv', $fh->write_binary(4));
	my @r = ();
	while (@r < $nr) {
	    my ($ju, $sl, $ls, $ll, $ds, $dl, $ge, $ab, $qu, $xs, $xl, $rl) =
		unpack($fmask, $fh->write_binary($fsize));
	    my $ru = $fh->write_binary($rl);
	    $ru =~ s/\0+$//;
	    $ru eq '' and $ru = undef;
	    $fsize == 21 && $ge == 255 and $ge = unpack('v', $fh->write_binary(2));
	    my $fl = 0;
	    $ab and $fl |= stmt_abstain;
	    $qu and $fl |= stmt_quantum;
	    $ju and $fl |= stmt_junk;
	    push @r, [$fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru];
	}
	$code{$sval} = \@r;
    }
    my $slen = unpack('v', $fh->write_binary(2)) || 0;
    my $source = $fh->write_binary($slen);
    my $syms = Language::INTERCAL::SymbolTable->write($fh);
    my $psize = unpack('v', $fh->write_binary(2)) || 0;
    my @p = ();
    while (@p < $psize) {
	push @p, Language::INTERCAL::Parser->write($fh, $syms);
    }
    $obj->{symbols} = $syms;
    $obj->{parsers} = \@p;
    # old objects had an optimiser but none was ever defined, so now we
    # just skip it; when we write one for new objects it'll be in the
    # other "write" method above
    $obj->{units} = [];
    if (exists $flags{__units}) {
	# units used to be just a list of source positions, convert it to the current
	# units format
	my @units = unpack('v*', delete $flags{__units});
	for my $unit (@units) {
	    my $codelen = length $code;
	    my (%unitcode, %newcode);
	    for my $sptr (keys %code) {
		if ($sptr < $unit) {
		    # code belonging to this unit
		    $unitcode{$sptr} = $code{$sptr};
		} else {
		    # code after this unit, adjust lengths if appropriate
		    for my $p (@{$code{$sptr}}) {
			my ($ju, $sl, $ls, $ll, $ds, $dl, $ge, $ab, $qu, $xs, $xl, $ru) = @$p;
			$ll > 0 && $codelen > $ls and $codelen = $ls;
			$dl > 0 && $codelen > $ds and $codelen = $ds;
			$codelen > $xs and $codelen = $xs;
		    }
		    $newcode{$sptr} = $code{$sptr};
		}
	    }
	    my @unitcode = map { [$_, $unitcode{$_}] } sort { $a <=> $b } keys %unitcode;
	    push @{$obj->{units}}, [
		substr($source, 0, $unit, ''),
		$unit,
		substr($code, 0, $codelen, ''),
		\@unitcode,
	    ];
	    # and now we need to rewrite %code with %newcode adjusting what needs
	    # to be adjusted
	    %code = ();
	    for my $sptr (keys %newcode) {
		for my $p (@{$newcode{$sptr}}) {
		    my ($fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru) = @$p;
		    $ll > 0 and $ls -= $codelen;
		    $dl > 0 and $ds -= $codelen;
		    $xs -= $codelen;
		    push @{$code{$sptr - $unit}},
			[$fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru];
		}
	    }
	}
    }
    # whatever is left of the source will be in the last unit
    my @code = map { [$_, $code{$_}] } sort { $a <=> $b } keys %code;
    push @{$obj->{units}}, [
	$source,
	length($source),
	$code,
	\@code,
	0,
    ];
    wantarray ? ($obj, 0, 0) : $obj;
}

sub read {
    @_ == 3 or croak "Usage: read Language::INTERCAL::Object(FILEHANDLE, RUNNABLE?)";
    my ($obj, $fh, $runnable) = @_;
    local $ENV{LC_COLLATE} = 'C'; # to make sort result reproducible
    if ($runnable) {
	$fh->read_text($Config{startperl} . "\n");
	$fh->read_text("eval 'exec $Config{perlpath} -w -S \$0 \${1+\"\$\@\"}'\n");
	$fh->read_text("    if 0; # not running under some shell\n");
	$fh->read_text("# GENERATED BY CLC-INTERCAL $VERSION\n");
	$fh->read_text("# TO MODIFY, EDIT SOURCE AND REPACKAGE\n");
	$fh->read_text("\n");
	# add "use lib" statements to find our modules, if required, but
	# do not include system library paths
	my %libraries = map { defined ? ($Config{$_} => undef) : () } qw(
	    installarchlib
	    installprivlib
	    installsitearch
	    installsitelib
	    installvendorarch
	    installvendorlib
	    privlib
	    privlibexp
	    sitearch
	    sitearchexp
	    sitelib
	    sitelib_stem
	    sitelibexp
	    vendorarch
	    vendorarchexp
	    vendorlib
	    vendorlib_stem
	    vendorlibexp
	);
	my @ext_names = map { /^LOAD_(.*)$/ ? $1 : () } $obj->all_flags;
	my @ext_modules = map { $_ . '::Extend' } @ext_names;
	for my $module (qw(GenericIO Interpreter Server Rcfile RunObject), @ext_modules) {
	    eval "require Language::INTERCAL::$module"; # in theory it's already loaded but anyway
	    no strict 'refs';
	    my $version = ${"Language::INTERCAL::${module}::VERSION"};
	    defined $version or die "Cannot figure out VERSION for $module\n";
	    (my $mp = $module) =~ s|::|/|g;
	    my $lib = $INC{"Language/INTERCAL/$mp.pm"};
	    defined $lib or die "Hmmm, \$INC{$module} not defined?\n";
	    $lib =~ s:/Language/INTERCAL/\Q$mp\E\.pm$::;
	    if (! exists $libraries{$lib}) {
		$fh->read_text("use lib '$lib';\n");
		$libraries{$lib} = undef;
	    }
	    if ($lib =~ s/\blib$/arch/i && ! exists $libraries{$lib}) {
		$fh->read_text("use lib '$lib';\n");
		$libraries{$lib} = undef;
	    }
	    $module eq 'RunObject'
		and $fh->read_text("use Language::INTERCAL::$module '$version', 'run_object';\n");
	}
	$fh->read_text("\n");
	if (@ext_names) {
	    $fh->read_text("run_object(qw(@ext_names));\n");
	} else {
	    $fh->read_text("run_object();\n");
	}
	$fh->read_text("exit 0;\n");
	$fh->read_text("\n");
    } else {
	$fh->read_text("OBJECT GENERATED BY CLC-INTERCAL $VERSION\n");
    }
    $fh->read_text("__DATA__\n");
    $fh->read_text("CLC-INTERCAL $VERSION Object File\n");
    my %flags = %{$obj->{flags}};
    my $optimiser = exists $flags{optimiser} ? 1 : 0;
    delete $flags{optimiser};
    my $compiler = exists $flags{compiler} ? 1 : 0;
    delete $flags{compiler};
    my $discard = $optimiser || $compiler;
    my @flags = sort keys %flags;
    my $parsers = $discard ? [] : $obj->{parsers};
    my $bitmap = bm_has_optimiser;
    $optimiser and $bitmap |= bm_is_optimiser;
    $compiler and $bitmap |= bm_is_compiler;
    $fh->read_binary(pack('vvvvC', OBJECT_FORMAT, scalar(@flags), scalar @{$obj->{units}},
				   scalar(@$parsers), $bitmap));
    for my $fname (@flags) {
	my $fvalue = $obj->{flags}{$fname};
	$fh->read_binary(pack('vva*a*', length($fname), length($fvalue), $fname, $fvalue));
    }
    for my $unit (@{$obj->{units}}) {
	my ($source, $length, $code, $cptr, $uflags) = @$unit;
	$discard or $fh->read_binary(pack('V/a*', $source));
 	$fh->read_binary(pack('VVvV/a*', $length, scalar(@$cptr), $uflags, $code));
	for my $sp (@$cptr) {
	    my ($sptr, $p) = @$sp;
	    $fh->read_binary(pack('VV', $sptr, scalar @$p));
	    for my $q (@$p) {
		my ($fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru) = @$q;
		$fh->read_binary(pack('vVvvvvvvv', $fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl));
		$discard and next;
		defined $ru or $ru = '';
		$fh->read_binary(pack('V/a*', $ru));
	    }
	}
    }
    # my $symbols = $discard ? Language::INTERCAL::SymbolTable->new() : $obj->{symbols};
    my $symbols = $obj->{symbols};
    $symbols->read($fh);
    for my $p (@$parsers) {
	$p->read($fh);
    }
    $obj->{optimiser}->read($fh);
    $discard;
}

sub clear_code {
    @_ == 1 or croak "Usage: OBJECT->clear_code";
    my ($obj) = @_;
    $obj->{units} = [];
    $obj;
}

sub num_units {
    @_ == 1 or croak "Usage: OBJECT->num_units";
    my ($obj) = @_;
    scalar(@{$obj->{units}});
}

sub unit_code {
    @_ == 2 || @_ == 5 || @_ == 6
	or croak "Usage: OBJECT->unit_code(UNIT [, SOURCE, LENGTH, NEWCODE, [OPTIMISE?]])";
    my $obj = shift;
    my $unit = shift;
    $unit =~ /^\d+$/ && $unit <= @{$obj->{units}} or croak "Invalid UNIT $unit";
    my @oldcode = @{$obj->{units}[$unit] || []};
    if (@_) {
	my ($source, $length, $origcode, $optimise) = @_;
#	length($source) > 0xffff || $length > 0xffff
#	    and faint(SP_INDIGESTION);
	my ($code, $cptr, $discard, $uflags) =
	    _setcode($obj->{bug}, $obj->{flags}, $origcode, $optimise ? $obj->{optimiser} : undef);
	$obj->{units}[$unit] = [$discard ? '' : $source, $length, $code, $cptr, $uflags];
    }
    @oldcode;
}

sub freeze {
    @_ == 1 or croak "Usage: OBJECT->freeze";
    my ($obj) = @_;
    for my $u (@{$obj->{units}}) {
	$u->[0] = '';
	$u->[4] |= UFLAG_nocreate | UFLAG_nomultiple | UFLAG_frozen;
	my $optr = $u->[3];
	my @optr;
	my $shadow = 0;
	for my $cp (@$optr) {
	    my ($sptr, $c) = @$cp;
	    $shadow > $sptr and next;
	    @$c or die "Invalid bytecode, empty statement\n";
	    my ($fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru) = @{$c->[0]};
	    push @optr, [$sptr, [[$fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl]]];
	}
	$u->[3] = \@optr;
    }
    $obj;
}

sub save_unit_code {
    @_ == 2 or croak "Usage: OBJECT->save_unit_code(UNIT)";
    my ($obj, $unit) = @_;
    $unit >= 0 && $unit < @{$obj->{units}}
	or croak "Invalid UNIT $unit";
    $obj->{units}[$unit];
}

sub restore_unit_code {
    @_ == 3 or croak "Usage: OBJECT->restore_unit_code(UNIT, SAVED)";
    my ($obj, $unit, $saved) = @_;
    # note <= not <, we allow to extend the units by one
    $unit >= 0 && $unit <= @{$obj->{units}}
	or croak "Invalid UNIT $unit";
    @$saved == 5 or croak "Invalid SAVED";
    $obj->{units}[$unit] = $saved;
    $obj;
}

sub prepend_unit_code {
    @_ == 2 or croak "Usage: OBJECT->prepend_unit_code(SAVED)";
    my ($obj, $saved) = @_;
    @$saved == 5 or croak "Invalid SAVED";
    unshift @{$obj->{units}}, $saved;
    $obj;
}

sub _addcode {
    my ($js, $cf) = @_;
    return 0 if $cf eq '';
    my $fp = index($$js, $cf);
    return $fp if $fp >= 0;
    $fp = length($$js);
    $$js .= $cf;
    return $fp;
}

sub _setcode {
    my ($bug, $flags, $code, $optcode) = @_;
    my %code = ();
    my $joincode = '';
    my $uflags = UFLAG_nocreate | UFLAG_nomultiple;
    my @code = @{ref $code ? $code : [$code]};
    if (@code && $bug->[1] > rand(100)) {
	my $bpos = int(rand scalar @code);
	$code[$bpos] .= pack('C*', BC_BUG, BC($bug->[0] ? 1 : 0));
    }
    delete $flags->{optimiser};
    delete $flags->{compiler};
    my ($compiler, $optimiser);
    STATEMENT:
    for my $cv (@code) {
	next if $cv eq '';
	my $ep = length $cv;
	unless (ord($cv) == BC_STS) {
	    my $bc = sprintf("%02X", ord($cv));
	    faint(SP_INTERNAL, "Generated code starts with $bc instead of STS");
	}
	my $ncp = 1;
	my $sflag = 0;
	my $start1 = BCget($cv, \$ncp, $ep);
 	my $start2 = BCget($cv, \$ncp, $ep);
 	my $start = $start2 * 65536 + $start1;
 	my $len1 = BCget($cv, \$ncp, $ep);
 	my $len2 = BCget($cv, \$ncp, $ep);
 #	print "lengths: $len1 $len2\n";
 	my $len = $len2 * 65536 + $len1;
	BCget($cv, \$ncp, $ep) and $sflag |= stmt_junk;
	my $count = BCget($cv, \$ncp, $ep);
	my $rules;
	$optimiser or $rules = substr($cv, $ncp, $count);
	$ncp += $count;
	my $gerund = BC_STS;
	my @label = (0, 0);
	my @dsx = (0, 0);
	while ($ncp < $ep) {
	    my $byte = vec($cv, $ncp++, 8);
	    if ($byte == BC_NOT) {
		$sflag |= stmt_abstain;
		next;
	    }
	    if ($byte == BC_QUA) {
		$sflag |= stmt_quantum;
		next;
	    }
	    if ($byte == BC_BIT) {
		$ncp < $ep or faint(SP_INTERNAL, 'Missing number after BIT');
		$byte = vec($cv, $ncp++, 8);
		$sflag |= 1 << ($byte & 0x1f);
		next;
	    }
	    if ($byte == BC_LAB) {
		$ncp < $ep or faint(SP_INTERNAL, 'Missing label after LAB');
		if (is_constant(vec($cv, $ncp, 8))) {
		    $label[0] = BCget($cv, \$ncp, $ep);
		    $label[1] = 0;
		} else {
		    my $start = $ncp;
		    bc_skip($cv, \$ncp, $ep)
			or faint(SP_INTERNAL, 'Invalid label after LAB');
		    my $diff = $ncp - $start;
		    $label[0] = _addcode(\$joincode, substr($cv, $start, $diff));
		    $label[1] = $diff;
		}
		next;
	    }
	    if ($byte == BC_DSX) {
		$ncp < $ep or faint(SP_INTERNAL, 'Missing percentage after DSX');
		if (is_constant(vec($cv, $ncp, 8))) {
		    $dsx[0] = 1 + BCget($cv, \$ncp, $ep);
		    $dsx[1] = 0;
		} else {
		    my $start = $ncp;
		    bc_skip($cv, \$ncp, $ep)
			or faint(SP_INTERNAL, 'Invalid percentage after DSX');
		    my $diff = $ncp - $start;
		    $dsx[0] = _addcode(\$joincode, substr($cv, $start, $diff));
		    $dsx[1] = $diff;
		}
		next;
	    }
	    if ($byte == BC_UNS || $byte == BC_UNA) {
		my $vcp = $ncp;
		$gerund = BCget($cv, \$vcp, $ep);
		$ncp--;
		last;
	    }
	    $gerund = $byte;
	    $ncp--;
	    last;
	}
	my $addcode = substr($cv, $ncp, $ep - $ncp);
	if ($gerund == BC_FLA) {
	    # don't store a flag, instead set it immediately
	    my $fb = $ncp + 1;
	    my ($flag, $value);
	    if (substr($cv, $fb, 1) eq chr(BC_STR)) {
		$fb++;
		my $length = BCget($cv, \$fb, $ep);
		faint(SP_INTERNAL, "Flag name after FLA extends past end of code")
		    if $length + $fb > $ep;
		$flag = substr($cv, $fb, $length);
		$fb += $length;
	    } else {
		my $length = BCget($cv, \$fb, $ep);
		$flag = '';
		while (length $flag < $length) {
		    $flag .= chr(BCget($cv, \$fb, $ep));
		}
	    }
	    if (substr($cv, $fb, 1) eq chr(BC_STR)) {
		$fb++;
		my $length = BCget($cv, \$fb, $ep);
		faint(SP_INTERNAL, "Flag name after FLA extends past end of code")
		    if $length + $fb > $ep;
		$value = substr($cv, $fb, $length);
		$fb += $length;
	    } else {
		my $length = BCget($cv, \$fb, $ep);
		$value = '';
		while (length $value < $length) {
		    $value .= chr(BCget($cv, \$fb, $ep));
		}
	    }
	    faint(SP_INTERNAL, 'FLA directive followed by extra data')
		if $fb != $ep;
	    unless ($sflag & stmt_abstain) {
		$flags->{$flag} = $value;
		# if this is an extension load, may want to load it!
		if ($flag =~ /^LOAD_(.*)$/) {
		    my $ext = $1;
		    load_extension($ext);
		}
		$flag eq 'optimiser' and $optimiser = 1;
		$flag eq 'TYPE' and exists $is_compiler{$value} and $compiler = 1;
	    }
	    $addcode = '';
	    $sflag |= stmt_abstain;
	}
	if ($optimiser || $compiler) {
	    # compilers and optimisers cannot be recompiled, although the
	    # grammar they provide can change
	    undef $rules;
	    # compilers and optimisers promise never to reinstate anything
	    $sflag & stmt_abstain and ($addcode, $gerund) = ('', 0);
	}
	# CRE and DES are supposed to be immediately followed by a small nonzero
	# constant, so we throw an error here if the second byte isn't valid;
	# then if the opcode is CRE and the grammar is #1 we also update $uflags
	if ($gerund == BC_CRE || $gerund == BC_DES) {
	    my $gra = vec($addcode, 1, 8);
	    $gra > NUM_OPCODES or faint(SP_INTERNAL, "Invalid grammar number after $gra");
	    $gerund == BC_CRE && $gra == 1 and $uflags &= ~UFLAG_nocreate;
	}
	# trim rules
	if (defined $rules) {
	    $rules =~ s/\0+$//;
	    $rules eq '' and $rules = undef;
	}
	$optcode and $addcode = $optcode->optimise($addcode);
	# look for the very same thing...
	my @addit = (
	    $sflag, $len,
	    $label[0], $label[1],
	    $dsx[0], $dsx[1],
	    $gerund,
	    _addcode(\$joincode, $addcode), length($addcode),
	    $rules,
	);
	# assert (@addit == 10)
	my $junk = $sflag & stmt_junk ? 1 : 0;
	if (exists $code{$start}{$junk}{$len}) {
	    TRY:
	    for my $p (@{$code{$start}{$junk}{$len}}) {
		for (my $i = 0; $i < 9; $i++) {
		    next TRY if $p->[$i] != $addit[$i];
		}
		next TRY if defined $rules && ! defined $p->[9];
		next TRY if ! defined $rules && defined $p->[9];
		next TRY if defined $rules && $rules ne $p->[9];
		# yup, it's the very same - no need to add it then
		next STATEMENT;
	    }
	}
	# we'll have to add this one
	push @{$code{$start}{$junk}{$len}}, \@addit;
    }
#    length $joincode > 0xffff
#	and faint(SP_INDIGESTION);
    # now go and transform each value of %code... note that we sort the
    # array so that noncomments are always before comments, and shorter
    # comments are preferred over longer; however within the same comment
    # length (or within the noncomment group) we prefer longer source
    # code; all else being equal, we prefer things which use more grammar
    # rules
    my @unitcode;
    for my $sp (sort { $a <=> $b } keys %code) {
	my @elems = ();
	for my $j (sort { $a <=> $b } keys %{$code{$sp}}) {
	    for my $l (sort { $b <=> $a } keys %{$code{$sp}{$j}}) {
		push @elems, sort {
		    scalar @$a <=> scalar @$b
		} @{$code{$sp}{$j}{$l}};
	    }
	}
	@elems > 1 and $uflags &= ~UFLAG_nomultiple;
	push @unitcode, [$sp, \@elems];
    }
    $compiler && ! exists $flags->{compiler} and $flags->{compiler} = 0;
    ($joincode, \@unitcode, $compiler, $uflags);
}

1;
