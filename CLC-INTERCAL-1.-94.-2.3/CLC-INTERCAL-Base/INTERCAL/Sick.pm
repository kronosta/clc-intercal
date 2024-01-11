package Language::INTERCAL::Sick;

# Compiler/user interface/whatnot for CLC-INTERCAL

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Sick.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use File::Basename;
use File::Spec::Functions;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import has_type);
use Language::INTERCAL::Charset '1.-94.-2.1', qw(charset_name toascii charset);
use Language::INTERCAL::GenericIO '1.-94.-2';
use Language::INTERCAL::RegTypes '1.-94.-2.2', qw(REG_whp REG_spot);
use Language::INTERCAL::Backend '1.-94.-2.3', qw(backend all_backends generate_code);
use Language::INTERCAL::Listing '1.-94.-2.3', qw(listing all_listings);
use Language::INTERCAL::Interpreter '1.-94.-2.3', qw(IFLAG_initialise);

sub new {
    @_ == 2 or croak "Usage: new Language::INTERCAL::Sick(RC)";
    my ($class, $rc) = @_;
    bless {
	object_option => {
	    listing            => [],
	    backend            => [],
	    bug                => 1,
	    charset            => '',
	    name               => '%o',
	    optimise           => 0,
	    output             => '%p.%s',
	    directory          => '',
	    preload            => [],
	    add_preloads       => 0,
	    suffix             => '',
	    trace              => undef,
	    trace_fh           => undef,
	    ubug               => 0.01,
	    verbose            => 0,
	    grammar_profile    => 0,
	    grammar_profile_fh => undef,
	    grammar_profile_max => 0,
	    grammar_profile_count => 0,
	    grammar_profile_cost => 0,
	    stdwrite           => undef,
	    stdread            => undef,
	    stdsplat           => undef,
	},
	shared_option => {
	    default_backend    => 'Object',
	    default_charset    => [],
	    default_suffix     => [],
	    library_rule       => [],
	    library_search     => [],
	    preload_callback   => undef,
	},
	sources => [],
	filepath => {},
	shared_filepath => {},
	int_cache => {},
	loaded => 0,
	rc => $rc,
	server => 0,
	interpreter        => 'Language::INTERCAL::Interpreter',
    }, $class;
}

my $interpreter_class = 'Language::INTERCAL::Interpreter';

sub reset {
    @_ == 1 or croak "Usage: SICK->reset";
    my ($sick) = @_;
    $sick->{loaded} = 0;
    $sick->{sources} = [];
    $sick;
}

sub interpreter {
    @_ == 2 or croak "Usage: SICK->interpreter(CLASS)";
    my ($sick, $class) = @_;
    if ($class eq '') {
	# revert to default
	$class = $interpreter_class;
    } else {
	$class = "${interpreter_class}\::$class";
	eval "require $class";
	$@ and die $@;
    }
    $sick->{interpreter} = $class;
    $sick;
}

my %checkoption = (
    add_preloads          => [undef,            \&_check_bool],
    listing               => [\&all_listings,   \&_load_listings],
    backend               => [\&all_backends,   \&_load_backends],
    bug                   => [undef,            \&_check_bug],
    charset               => [undef,            \&_load_charset],
    default_backend       => [undef,            \&_load_backend],
    default_charset       => [undef,            \&_load_charset],
    default_suffix        => [undef,            \&_check_suffix],
    grammar_profile       => [undef,            \&_check_bool],
    grammar_profile_fh    => [undef,            \&_check_filehandle],
    grammar_profile_max   => [undef,            \&_check_int],
    grammar_profile_count => [undef,            \&_check_int],
    grammar_profile_cost  => [undef,            \&_check_int],
    optimise              => [undef,            \&_check_bool],
    preload               => [undef,            \&_check_object],
    preload_callback      => [undef,            \&_check_callback],
    trace                 => [undef,            \&_check_bool],
    trace_fh              => [undef,            \&_check_filehandle],
    ubug                  => [undef,            \&_check_bug],
    verbose               => [undef,            \&_check_filehandle],
);

my %object_type = (
    IACC        => 'COMPILER',
    COMPILER    => 'COMPILER',
    ASSEMBLER   => 'COMPILER',
    RUNCOMPILER => 'COMPILER',
    BASE        => 'ONEONLY',
    POSTPRE     => 'ONEONLY',
    EXTENSION   => 'REPEAT',
    OPTION      => 'REPEAT',
    OPTIMISER   => 'REPEAT',
    PROGRAM     => 'REPEAT',
);

sub option {
    @_ == 2 or @_ == 3 or croak "Usage: SICK->option(NAME [, VALUE])";
    @_ == 2 ? shift->getoption(@_) : shift->setoption(@_);
}

sub getoption {
    @_ == 2 or croak "Usage: SICK->getoption(NAME)";
    my ($sick, $on) = @_;
    (my $name = lc($on)) =~ tr/-/_/;
    my $value = exists $sick->{object_option}{$name}
	? $sick->{object_option}{$name}
	: exists $sick->{shared_option}{$name}
	    ? $sick->{shared_option}{$name}
	    : die "Unknown option $on\n";
    return $value unless ref $value;
    return $value if eval { $value->isa('Language::INTERCAL::GenericIO') };
    return @$value if 'ARRAY' eq ref $value;
    return map { ($_ => [@{$value->{$_}}]) } keys %$value
	if 'HASH' eq ref $value;
    return (); # should never get here
}

sub setoption {
    @_ == 3 or croak "Usage: SICK->setoption(NAME, VALUE)";
    my ($sick, $on, $value) = @_;
    (my $name = lc($on)) =~ tr/-/_/;
    my $hash = exists $sick->{object_option}{$name}
	? $sick->{object_option}
	: exists $sick->{shared_option}{$name}
	    ? $sick->{shared_option}
	    : die "Unknown option $on\n";
    my $special = 0;
    if (exists $checkoption{$name}) {
	$special = $checkoption{$name}[0];
	if ($special && ref $special && $value eq 'help') {
	    print "$_\n" for sort $special->();
	    return $sick;
	}
	$value = $checkoption{$name}[1]->($name, $sick, $value);
    }
    if ($special || ! ref $hash->{$name}) {
	$hash->{$name} = $value;
    } elsif (eval { $value->isa('Language::INTERCAL::GenericIO') }) {
	$hash->{$name} = $value;
    } elsif ('ARRAY' eq ref $hash->{$name}) {
	push @{$hash->{$name}}, $value;
    } elsif ('HASH' eq ref $hash->{$name}) {
	my ($key, $as, @add) = @$value;
	if (exists $hash->{$name}{$key}) {
	    $hash->{$name}{$key}[0] = $as;
	} else {
	    $hash->{$name}{$key} = [$as];
	}
	push @{$hash->{$name}{$key}}, @add;
    } else {
	# not supposed to get here
	die "Cannot set option $name\n";
    }
    $sick;
}

sub clearoption {
    @_ == 2 or croak "Usage: SICK->clearoption(NAME)";
    my ($sick, $name) = @_;
    my $hash = exists $sick->{object_option}{$name}
	? $sick->{object_option}
	: exists $sick->{shared_option}{$name}
	    ? $sick->{shared_option}
	    : die "Unknown option $name\n";
    if (ref $hash->{$name}) {
	if (eval { $hash->{$name}->isa('Language::INTERCAL::GenericIO') }) {
	    $hash->{$name} = 0;
	} elsif ('ARRAY' eq ref $hash->{$name}) {
	    $hash->{$name} = [];
	} elsif ('HASH' eq ref $hash->{$name}) {
	    $hash->{$name} = {};
	} else {
	    die "Cannot clear option $name\n";
	}
    } else {
	die "Cannot clear option $name\n";
    }
    $sick;
}

sub alloptions {
    @_ == 1 or @_ == 2 or croak "Usage: SICK->alloptions [(shared)]";
    my ($sick, $shared) = @_;
    my %vals = ();
    my @hash = ();
    push @hash, 'object_option';
    push @hash, 'shared_option' if ! defined $shared || $shared;
    for my $hash (@hash) {
	while (my ($name, $value) = each %{$sick->{$hash}}) {
	    if (! ref $value) {
		# nothing, but we don't want to be caught in next cases
	    } elsif (eval { $value->isa('Language::INTERCAL::GenericIO') }) {
		# nothing, but we don't want to be caught in next cases
	    } elsif ('ARRAY' eq ref $value) {
		# a shallow copy will do -- we know values are strings
		$value = [ @$value ];
	    } elsif ('HASH' eq ref $value) {
		# two level deep copy: the values are arrays of strings
		my %v = ();
		while (my ($key, $val) = each %$value) {
		    $v{$key} = [ @$val ];
		}
		$value = \%v;
	    } elsif (ref $value) {
		# WTF?
		$value = undef;
	    }
	    $vals{$name} = $value;
	}
    }
    %vals;
}

sub source {
    @_ == 2 or croak "Usage: SICK->source(FILENAME)";
    my ($sick, $file) = @_;
    $file = _check_file($sick, $file);
    push @{$sick->{sources}}, {
	source   => $file,
	option   => { $sick->alloptions(0) }, # don't copy shared options
	filepath => $sick->{filepath},
    };
    $sick->{loaded} = 0;
    $sick;
}

sub source_string {
    @_ == 2 or croak "Usage: SICK->source_string(STRING)";
    my ($sick, $string) = @_;
    push @{$sick->{sources}}, {
	string   => $string,
	option   => { $sick->alloptions(0) }, # don't copy shared options
    };
    $sick->{loaded} = 0;
    $sick;
}

sub load_objects {
    @_ == 1 or croak "Usage: SICK->load_objects()";
    my ($sick) = @_;
    return $sick if $sick->{loaded};
    for (my $i = 0; $i < @{$sick->{sources}}; $i++) {
	my $object = $sick->{sources}[$i];
	next if exists $object->{object};
	my $o = $object->{option};
	my $utf8_hack = 0;
	my ($obj, $fn, $base, $is_src) = _load_source($sick, $object, $o, \$utf8_hack);
	$object->{is_src} = $is_src;
	$object->{base} = $base;
	$object->{object} = $obj;
	$object->{filename} = $fn;
	$object->{utf8_hack} = \$utf8_hack;
    }
    $sick->{loaded} = 1;
    $sick;
}

sub save_objects {
    @_ == 2 or croak "Usage: SICK->save_objects(AND_KEEP?)";
    my ($sick, $keep) = @_;
    $sick->load_objects();
    for my $object (@{$sick->{sources}}) {
	my $o = $object->{option};
	my $out = $o->{output};
	next if $out eq '';
	my $backends = $o->{backend};
	$backends && @$backends or $backends = [$sick->{shared_option}{default_backend}];
	for my $backend (@$backends) {
	    next unless $object->{is_src} || $backend ne 'Object';
	    my $v = $o->{verbose} ? sub {
		my ($name) = @_;
		$o->{verbose}->read_text($name eq '' ? 'Running...'
						     : "Saving $name... ");
	    } : '';
	    my $orig = $object->{source};
	    defined $orig and $orig =~ s/\.[^.]*$//;
	    my $b = $sick->{rc}->getoption('build');
	    my %op = (
		verbose   => $v,
		build     => $b,
		utf8_hack => $object->{utf8_hack},
	    );
	    my %save;
	    for my $h (qw(stdwrite stdread stdsplat)) {
		defined $o->{$h} or next;
		my $name = 'O' . uc(substr($h, 3, 1)) . 'FH';
		$save{$name} = [$object->{object}->getreg($name)];
		$object->{object}->setreg($name, $o->{$h}, REG_whp);
	    }
	    generate_code($object->{object}, $backend, $o->{name},
			  $o->{directory}, $object->{base}, $out, $orig, \%op);
	    $o->{verbose}->read_text("OK\n") if $o->{verbose};
	    for my $h (keys %save) {
		$object->{object}->setreg($h, @{$save{$h}});
	    }
	}
	undef $object unless $keep;
    }
    $sick;
}

sub server {
    @_ == 2 or croak "Usage: SICK->server(SERVER)";
    my ($sick, $server) = @_;
    $sick->{server} = $server;
    $sick;
}

sub get_object {
    @_ == 2 or croak "Usage: SICK->get_object(NAME)";
    my ($sick, $name) = @_;
    for my $o (@{$sick->{sources}}) {
	defined $o->{source} or next;
	next if $o->{source} ne $name;
	return $o->{object};
    }
    undef;
}

sub get_text_object {
    @_ == 1 or croak "Usage: SICK->get_text_object";
    my ($sick) = @_;
    for my $o (@{$sick->{sources}}) {
	defined $o->{source} and next;
	return $o->{object};
    }
    undef;
}

sub all_objects {
    @_ == 2 || @_ == 3
	or croak "Usage: SICK->all_objects(CALLBACK [, JUST_FLAGS])";
    my ($sick, $callback, $just_flags) = @_;
    for my $search (@{$sick->{rc}->getoption('include')}) {
	opendir(SEARCH, $search) or next;
	while (defined (my $ent = readdir SEARCH)) {
	    $ent =~ /^(.*)\.io$/i or next;
	    my $name = $1;
	    my $file = catfile($search, $ent);
	    -f $file or next;
	    eval {
		my $fh = Language::INTERCAL::GenericIO->new('FILE', 'w', $file);
		my $ob = Language::INTERCAL::Object->write($fh, $just_flags);
		my $type = undef;
		$ob->has_flag('TYPE')
		    and $type = $ob->flag_value('TYPE');
		$callback->($name, $file, $type, $ob);
	    };
	}
	closedir SEARCH;
    }
    $sick;
}

# private methods follow

sub _check_bool {
    my ($name, $sick, $value) = @_;
    return $value if $value =~ /^\d+$/;
    return 1 if $value =~ /^t(?:rue)?$/i;
    return 1 if $value =~ /^y(?:es)?$/i;
    return 0 if $value =~ /^f(?:alse)?$/i;
    return 0 if $value =~ /^n(?:o)?$/i;
    die "Invalid value for $name\: '$value'\n";
}

sub _check_filehandle {
    my ($name, $sick, $value) = @_;
    return $value if ref $value &&
		     eval { $value->isa('Language::INTERCAL::GenericIO') };
    return undef if $value =~ /^\d+$/ && $value == 0;
    return undef if $value =~ /^n(?:one)?$/i;
    die "Invalid filehandle value '$value'\n";
}

sub _check_path {
    my ($name, $sick, $value) = @_;
    return $value if -d $value;
    die "Invalid path '$value'\n";
}

sub _check_bug {
    my ($name, $sick, $value) = @_;
    $value =~ /^(?:\d+(?:\.\d*)?|\.\d+)$/
	or die "Value '$value' is not a positive number\n";
    $value <= 100
	or die "Value '$value' is too large for a probability\n";
    $value;
}

sub _check_int {
    my ($name, $sick, $value) = @_;
    $value =~ /^(?:\d+)$/
	or die "Value '$value' is not a positive number\n";
    $value;
}

sub _check_extra {
    my ($name, $sick, $value) = @_;
    ref $value && ref $value eq 'ARRAY'
	or die "Invalid value for $name (must be a array ref)\n";
    @$value == 3
	or die "Invalid value for $name (requires three elements)\n";
    my ($extra, $preload, $as) = @$value;
    ref $preload && ref $preload eq 'ARRAY'
	or die "Invalid value for $name (preloads must be array ref)\n";
    [$extra, $preload, $as];
}

sub _check_suffix {
    my ($name, $sick, $value) = @_;
    ref $value && has_type($value, 'HASH')
	or die "Invalid value for $name (must be a hash ref)\n";
    for my $key (qw(SUFFIX AS)) {
	exists $value->{$key}
	    or die "Invalid value for $name (missing key $key)\n";
    }
    for my $key (qw(SUFFIX WITH IGNORING)) {
	exists $value->{$key} or next;
	ref $value->{$key} && has_type($value->{$key}, 'ARRAY')
	    or die "Invalid value for $name (key $key must be a array ref)\n";
	for my $v (@{$value->{$key}}) {
	    if ($key eq 'SUFFIX') {
		ref $v && has_type($v, 'ARRAY') && @$v == 2
		    or die "Invalid value for $name (key $key must be a array of pairs)\n";
		ref $v->[0]
		    and die "First element of each $key must be a scalar\n";
		ref $v->[1] && has_type($v->[1], 'Regexp')
		    or die "Second element of each $key must be a regex\n";
	    } else {
		ref $v
		    and die "Invalid value for $name (key $key must be a array of scalars)\n";
	    }
	}
    }
    for my $key (qw(AS RETRYING)) {
	exists $value->{$key} or next;
	ref $value->{$key}
	    and die "Invalid value for $name (key $key must be a scalar)\n";
    }
    $value;
}

sub _find_file {
    my ($sick, $value, $ftype, $cache, $path) = @_;
    return $cache->{$value} if exists $cache->{$value};
    # try opening file from current directory
    if (-f $value) {
	$cache->{$value} = $value;
	return $value;
    }
    if (! file_name_is_absolute($value)) {
	my ($file, $dir) = fileparse($value);
	$path = $sick->{rc}->getoption('include') if ! defined $path;
	for my $search (@$path) {
	    my $n = catfile($search, $dir, $file);
	    $n = canonpath($n);
	    if (-f $n) {
		$cache->{$value} = $n;
		return $n;
	    }
	}
    }
    die "Cannot find $ftype \"$value\"\n";
}

sub _check_file {
    my ($sick, $value) = @_;
    _find_file($sick, $value, 'file',
	       $sick->{filecache},
	       $sick->{rc}->getoption('include'));
    $value;
}

sub _find_object {
    my ($sick, $value, $cache, $path, $options) = @_;
    my $suffix = '';
    if ($value !~ /\.ior?$/) {
	# try adding suffix first
	my @try;
	$options->{optimise} and push @try, qw(.o.ior .o.io);
	push @try, qw(.ior .io);
	for my $try (@try) {
	    my $v = eval {
		_find_file($sick, $value . $try, 'object', $cache, $path);
	    };
	    $@ and next;
	    return $v;
	}
    }
    _find_file($sick, $value, 'object', $cache, $path);
}

sub _check_object {
    my ($name, $sick, $value) = @_;
#    _find_object($sick, $value,
#		 $sick->{filecache},
#		 $sick->{rc}->getoption('include'), {});
    $value;
}

sub _check_callback {
    my ($name, $sick, $value) = @_;
    ! $value and return $value; # unset callback
    ref $value && has_type($value, 'CODE')
	and return [$value];
    ref $value && has_type($value, 'ARRAY')
	or die "Invalid callback, must be a CODE or ARRAY reference\n";
    ref $value->[0] && has_type($value->[0], 'CODE')
	or die "Invalid callback, first element must be a CODE reference\n";
    $value;
}

sub _open_file {
    my ($sick, $source, $cache, $path) = @_;
    my $fn = _find_file($sick, $source, 'file', $cache, $path);
    my $fh = Language::INTERCAL::GenericIO->new('FILE', 'w', $fn);
    ($fn, $fh);
}

sub _load_backend {
    my ($name, $sick, $value) = @_;
    defined backend($value) or die "Invalid backend: $value\n";
    $value
}

sub _load_backends {
    my ($name, $sick, $value) = @_;
    my @v = split(/,/, $value);
    for my $v (@v) {
	defined backend($v) or die "Invalid backend: $v\n";
    }
    \@v;
}

sub _load_listings {
    my ($name, $sick, $value) = @_;
    $value eq 'none' and return [];
    my @v = split(/,/, $value);
    my @r = ();
    for my $v (@v) {
	my $ls = listing($v);
	defined $ls or die "Invalid listing module: $v\n";
	push @r, $ls;
    }
    \@r;
}

sub _load_charset {
    my ($name, $sick, $value) = @_;
    defined charset_name($value)
	or die "Invalid charset: $value\n";
    $value;
}

sub _load_source {
    my ($sick, $source, $o, $utf8_hack) = @_;
    my ($fn, $fh, $base, $suffix);
    if ($o->{suffix}) {
	$suffix = $o->{suffix};
	$suffix = '.' . $suffix if $suffix !~ /^\./;
    }
    if (exists $source->{source}) {
	($fn, $fh) = _open_file($sick, $source->{source},
			        $source->{filepath},
			        $sick->{rc}->getoption('include'));
	$base = $fn;
	if ($o->{suffix}) {
	    $base =~ s/(\.[^.]*)$//; # remove and ignore suffix
	} elsif ($base =~ s/(\.[^.]*)$//) {
	    $suffix = lc($1);
	}
	$o->{verbose}->read_text("$fn... ") if $o->{verbose};
    } elsif (exists $source->{string}) {
	$fh = Language::INTERCAL::GenericIO->new('STRING', 'w', \$source->{string});
	$o->{verbose}->read_text("Compiling constant string... ") if $o->{verbose};
    } else {
	die "Internal error, source does not contain an actual source?\n";
    }
    # first see if it is a real object (you never know)
    my $int;
    if (defined $fn) {
	$int = eval {
	    $sick->{interpreter}->write($fh);
	};
	if ($@) {
	    $@ =~ /^Invalid\s+Object\s+Format\s+\(no\s/i or die $@;
	}
	if (defined $int && ref $int) {
	    $o->{verbose}->read_text("[COMPILER OBJECT]\n") if $o->{verbose};
	    $int->server($sick->{server});
	    $int->rcfile($sick->{rc});
	    $int->setreg('TRFH', $o->{trace_fh}, REG_whp) if defined $o->{trace_fh};
	    $int->setreg('TM', $o->{trace}, REG_spot) if defined $o->{trace};
	    return ($int, $fn, $base, 0);
	}
    }
    # failed for whatever reason, we'll try loading as a source
    $fh->reset();
    my @preload = @{$o->{preload}};
    if ($o->{add_preloads} || ! @preload) {
	unshift @preload, _guess_preloads($sick, $suffix, $o);
    }
    # try to find a compiler
    my @options = ();
    my @compiler = ();
    my %preloaded = ();
    $sick->{_flags} = {};
    $sick->{extra_code} = [];
    my $postpre = $sick->{rc}->getoption('postpre') || 'postpre';
    for my $p (@preload, $postpre) {
	next if $p eq '';
	_preload($sick, $p, $source->{filepath}, $o, \%preloaded, \@options, \@compiler);
    }
    exists $preloaded{COMPILER}
	or die "Invalid preload list: no compiler\n";
    # load the compiler and run it if required
    my $profile;
    if ($compiler[1]) {
	# compiler saved using RunObject
	$int = $compiler[0];
    } else {
	# compiler saved using Object - create a new interpreter and run the
	# compiler in it
	$int = $sick->{interpreter}->new();
	unshift @options, $compiler[0];
	$profile = $o->{grammar_profile};
    }
    $int->server($sick->{server});
    $int->rcfile($sick->{rc});
    $int->setreg('TRFH', $o->{trace_fh}, REG_whp) if defined $o->{trace_fh};
    $int->setreg('TM', $o->{trace}, REG_spot) if defined $o->{trace};
    my $obj = $int->object;
    if ($o->{bug} > 0) {
	$obj->setbug(0, $o->{bug});
    } else {
	$obj->setbug(1, $o->{ubug});
    }
    if (! $obj->has_flag('TYPE')) {
	# copy flags set by preloads
	for my $flag (keys %{$sick->{_flags}}) {
	    $obj->add_flag($flag, $sick->{_flags}{$flag});
	}
	# mark the object as program
	$obj->add_flag('TYPE', 'PROGRAM');
    }
    # execute all the options
    for my $p (@options) {
	$int->start(IFLAG_initialise)->run($p)->stop();
    }
    # do we need to guess character set?
    my $chr = $o->{charset};
    if ($chr eq '') {
	$chr = _guess_charset($sick, $source->{source}, $fh);
    }
    $fh->set_utf8_hack($utf8_hack);
    $fh->write_charset($chr);
    $fh->reset();
    # now read file
    my $line = 1;
    my $col = 1;
    my $scount = 0;
    my $text = $fh->write_text('');
    $o->{verbose}->read_text("\n    source: " . length($text) . " bytes")
	if $o->{verbose};
    $int->verbose_compile($o->{verbose});
    $profile and $obj->parser(1)->start_profiling;
    if ($o->{listing}) {
	for my $ls (@{$o->{listing}}) {
	    $ls->prepare($obj);
	}
    }
    $int->compile($text);
    if ($o->{listing}) {
	for my $ls (@{$o->{listing}}) {
	    my $list = $ls->filename($o->{name}, $o->{directory}, $base, $o->{output}, $source->{source});
	    $o->{verbose}->read_text("Producing listing $list...")
		if $o->{verbpse};
	    my $len = $ls->list($text, $obj, $list);
	    $o->{verbose}->read_text(" $len bytes\n")
		if $o->{verbpse};
	}
    }
    # now see if we want to append any special code to this program
    _glue($sick, \$text, $source->{filepath}, $int, $o, \%preloaded);
    $o->{verbose}->read_text(" [object: " . _int_size($obj))
	if $o->{verbose};
    if (@{$sick->{extra_code}}) {
	$int->prepend_code(@{$sick->{extra_code}});
	$o->{verbose}->read_text(" => " . _int_size($obj)) if $o->{verbose};
    }
    $o->{verbose}->read_text(" bytes]\n") if $o->{verbose};
    if ($profile) {
	my $handle = $o->{grammar_profile_fh} ||
		     Language::INTERCAL::GenericIO->new('FILE', 'r', \*STDERR);
	my (@width, @total);
	my $olimit = $o->{grammar_profile_max};
	my $limit = $olimit ? \$olimit : undef;
	my $count = $o->{grammar_profile_count} || undef;
	my $cost = $o->{grammar_profile_cost} || undef;
	$obj->parser(1)->profile(\&_grammar_profile, $handle, \@width, \@total, $limit, $count, $cost);
	$handle->read_text(sprintf "%$width[0]d %$width[1]d\n", $total[0], $total[1]);
	$obj->parser(1)->stop_profiling;
    }
    return ($int, $fn, $base, 1);
}

sub _grammar_profile {
    my ($parser, $symboltable, $count, $cost, $symbol, $left, $right, $handle, $width, $total, $limit, $ctl, $csl) = @_;
    for (my $i = 0; $i < 2; $i++) {
	my $v = $i ? $cost : $count;
	$total->[$i] += $v;
	my $len = length($v) + 2;
	defined $width->[$i] && $width->[$i] >= $len or $width->[$i] = $len;
    }
    if ($limit) {
	$$limit > 0 or return;
	$$limit--;
    }
    defined $ctl && $count < $ctl and return;
    defined $csl && $cost < $csl and return;
    my $line = sprintf "%$width->[0]d %$width->[1]d %s :", $count, $cost, $symboltable->symbol($symbol);
    for my $lp (@$left) {
	my ($type, $data, $count) = @$lp;
	if ($type eq 's') {
	    $data = $symboltable->symbol($data);
	} elsif ($type eq 'c') {
	    if ($data =~ /\s,/) {
		$data = join(' + ', unpack('C*', $data));
	    }
	    $data = ",$data,";
	} elsif ($type eq 'r') {
	    $data = "/$data/";
	}
	if ($count) {
	    $count = '=' . ($count > 65534 ? '*' : $count);
	} else {
	    $count = '';
	}
	$line .= " $data$count";
    }
    $handle->read_text($line . "\n");
}

sub _preload {
    my ($sick, $file, $cache, $o, $preloaded, $options, $compiler) = @_;
    my $fn = _find_object($sick, $file, $cache, $sick->{rc}->getoption('include'), $o);
    $o->{verbose}->read_text("\n    [$file: $fn") if $o->{verbose};
    my ($ci, $size);
    if (exists $sick->{int_cache}{$fn}) {
	($ci, $size) = @{$sick->{int_cache}{$fn}};
	if ($o->{verbose} && ! $size) {
	    $sick->{int_cache}{$fn}[1] = $size = _int_size($ci);
	}
    } else {
	my $fh = Language::INTERCAL::GenericIO->new('FILE', 'w', $fn);
	$ci = $sick->{interpreter}->write($fh);
	$size = $o->{verbose} ? _int_size($ci) : 0;
	$sick->{int_cache}{$fn} = [$ci, $size];
    }
    my $object = $ci->object;
    $object->has_flag('TYPE')
	or die "Invalid object $file ($fn) - did not provide a type\n";
    my $ct = $object->flag_value('TYPE');
    exists $object_type{$ct} or die "Invalid object type: $ct\n";
    # copy any flags set by this preload (except TYPE and reserved names)
    # to a temporary hash, so we can remember them for later
    for my $flag ($object->all_flags) {
	$flag eq 'TYPE' and next;
	$flag =~ /^__/ and next;
	$sick->{_flags}{$flag} = $object->flag_value($flag);
    }
    my $ot = $object_type{$ct};
    if ($ot eq 'COMPILER') {
	exists $preloaded->{$ct}
	    and die "Invalid preloads list - compiler " .
		    "$preloaded->{$ot} already loaded\n";
	$preloaded->{$ot} = $file;
	$compiler->[0] = $ci;
	$compiler->[1] = $ct eq 'RUNCOMPILER';
    } elsif ($ot eq 'ONEONLY') {
	exists $preloaded->{$ct}
	    and die "Invalid preloads list - \L$ct\E " .
		    "$preloaded->{$ct} already loaded\n";
	$preloaded->{$ct} = $file;
	push @$options, $ci;
    } elsif ($ot eq 'REPEAT') {
	push @$options, $ci;
    } else {
	die "Internal error, unmapped type $ot\n";
    }
    $ct eq 'PROGRAM'
	and push @{$sick->{extra_code}}, $ci->save_code;
    # if they want to do additional checks, let them
    if ($sick->{shared_option}{preload_callback}) {
	my ($code, @args) = @{$sick->{shared_option}{preload_callback}};
	$code->($sick, $file, $fn, $ct, @args);
    }
    $o->{verbose}->read_text(": type \L$ct\E: $size bytes]") if $o->{verbose};
}

sub _glue {
    my ($sick, $source, $cache, $int, $o, $preloaded) = @_;
    my $object = $int->{object};
    my @prev_code = $int->save_code;
    my $nl;
    RULE: for my $rule (@{$sick->{shared_option}{library_rule}}) {
	my ($file, $optfile, $compiler, $cregex, $base_yes, $base_no, @ranges) = @$rule;
	defined $cregex and $preloaded->{COMPILER} !~ $cregex and next RULE;
	my $whirlpool = '';
	if (defined $base_yes || defined $base_no) {
	    my $base = $preloaded->{BASE} || 2;
	    defined $base_no && index($base_no, $base) >= 0 and next RULE;
	    if (defined $base_yes) {
		if ($base_yes eq '@') {
		    $whirlpool = $base;
		} else {
		    index($base_yes, $base) >= 0 or next RULE;
		}
	    }
	}
	for my $range (@ranges) {
	    my ($low, $high) = @$range;
	    $int->has_labels($low, $high) and next RULE;
	    $int->uses_labels($low, $high) or next RULE;
	}
	# if we get here, we'll have to add this library to the source, so look for it
	(my $fn = $file) =~ s/\@/$whirlpool/g;
	if ($o->{optimise}) {
	    my ($ok, $report);
	    eval {
		if (! defined $optfile) {
		    $optfile = $fn;
		    $optfile =~ s/\.[^\,]*i$/.o.io/;
		}
		# $optfile defined but empty is a special message: "do not
		# use an optimised version"
		if ($optfile ne '') {
		    my $v = _find_file($sick, $optfile, 'object', $cache, $sick->{rc}->getoption('include'));
		    # we found an optimised version, try loading it
		    $report = 1;
		    my $fh = Language::INTERCAL::GenericIO->new('FILE', 'w', $v);
		    my $ci = $sick->{interpreter}->write($fh);
		    my $object = $ci->object;
		    $object->has_flag('optimiser')
			or die "Invalid optimiser object $optfile\n";
		    $o->{verbose} and $o->{verbose}->read_text("\n    [$fn: $v: " . _int_size($ci) . " bytes]");
		    $object->freeze;
		    push @{$sick->{extra_code}}, $ci->save_code;
		    $nl = 1;
		    $ok = 1;
		}
	    };
	    $ok and next RULE;
	    # report an error, but not "couldn't find file" as we just fall back to nonoptimised objects
	    $report && $@ and print STDERR $@;
	}
	my $path;
	for my $dg (@{$sick->{shared_option}{library_search}}, curdir()) {
	    for my $dir (glob("'$dg'")) {
		my $fp = catfile($dir, $fn);
		-f $fp or next;
		$path = $fp;
		last;
	    }
	}
	defined $path or die "Cannot find library ($fn) to include\n";
	# system libraries come from C-INTERCAL and will be ASCII
	open(my $sl, '<', $path) or die "$path: $!\n";
	my $text;
	{
	    local $/ = undef;
	    $text = "PLEASE GIVE UP\n" . <$sl>;
	}
	close $sl;
	my $len = length($text);
	$o->{verbose} and $o->{verbose}->read_text("\n    [$fn: $path: $len bytes");
	$int->compile($text);
	push @{$sick->{extra_code}}, $int->save_code;
	$o->{verbose} and $o->{verbose}->read_text(" => " . _int_size($object) . " bytes]");
	$nl = 1;
    }
    $nl or return;
    $o->{verbose} and $o->{verbose}->read_text("\n   ");
    $int->restore_code(@prev_code);
}

sub _guess_preloads {
    my ($sick, $suffix, $o) = @_;
    # must guess preloads from suffix, and it's... complicated
    my (%preloads, @preloads, %as, @as);
SUFFIX:
    while (1) {
	for my $value (@{$sick->{shared_option}{default_suffix}}) {
	    for my $s (@{$value->{SUFFIX}}) {
		my $re = $s->[1];
		my @match = $suffix =~ $re;
		@match or next;
		if (! exists $as{$value->{AS}}) {
		    $as{$value->{AS}} = 1;
		    push @as, $value->{AS};
		}
		for my $with (@{$value->{WITH} || []}) {
		    exists $preloads{$with} and next;
		    $preloads{$with} = 1;
		    push @preloads, $with;
		}
		for my $ignore (@{$value->{IGNORING} || []}) {
		    # pretend we've already seen this
		    $preloads{$ignore} = 1;
		}
		if (! exists $value->{RETRYING} || $value->{RETRYING} eq '') {
		    $o->{optimise} && ! exists $preloads{optimise}
			and push @preloads, 'optimise';
		    $o->{verbose}->read_text(" [" . join(' + ', @as) . "]")
			if $o->{verbose};
		    return @preloads;
		}
		$suffix = $value->{RETRYING};
		$s->[0] =~ /\@/ or @match = ();
		my $match = join('', @match);
		$suffix =~ s/\@/$match/;
		$suffix =~ s/\@//g;
		next SUFFIX;
	    }
	}
	die "Cannot guess file type\n";
    }
}

sub guess_preloads {
    @_ == 2 || @_ == 3
	or croak "Usage: SICK->guess_preloads(SUFFIX [, OPTIMISE])";
    my ($sick, $suffix, $optimise) = @_;
    my %o = (
	verbose => undef,
	optimise => $optimise,
    );
    _guess_preloads($sick, $suffix, \%o);
}

sub _guess_charset {
    my ($sick, $source, $fh) = @_;
    my %counts = ();
    for my $name (@{$sick->{shared_option}{default_charset}}) {
	eval {
	    my $cnv = toascii($name);
	    my $count = 0;
	    while ((my $line = $fh->write_binary(4096)) ne '') {
		    my $cl = &$cnv($line);
		    $count++ while $cl =~ /DO|PLEASE/ig;
	    }
	    $counts{$name} = $count;
	};
	$fh->reset();
    }
    my @counts =
	sort {$counts{$b} <=> $counts{$a}} grep {$counts{$_}} keys %counts;
    if (@counts == 0 && $fh->write_binary(1) eq '') {
	$fh->reset();
	@counts = qw(ASCII);
	$counts{ASCII} = 1;
    }
    if (! @counts || $counts{$counts[0]} < 1) {
	my $cr = $sick->{object_option}{verbose} ? "\n" : "";
	die "${cr}File \"$source\": cannot guess character set\n";
    }
    $counts[0];
}

sub _int_size {
    my ($int) = @_;
    my $size = 0;
    my $fh = new Language::INTERCAL::GenericIO 'COUNT', 'r', \$size;
    $int->read($fh, 0);
    $size;
}

1
