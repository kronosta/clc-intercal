package Language::INTERCAL::Interpreter;

# Interpreter and runtime environment

# This file is part of CLC-INTERCAL

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

use strict;
use vars qw($VERSION $PERVERSION $DATAVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/Base INTERCAL/Interpreter.pm 1.-94.-2.3") =~ /\s(\S+)$/;

use Carp;
use Language::INTERCAL::Exporter '1.-94.-2.3', qw(import has_type compare_version);
use Language::INTERCAL::Splats '1.-94.-2.2', qw(
    faint splatdescription SP_ARRAY SP_BUG SP_CLASS SP_CLASSWAR SP_COMEFROM SP_COMMENT
    SP_CONTEXT SP_CONVERT SP_CREATION SP_DIVERSION SP_EARLY SP_EVENT SP_EVOLUTION SP_FALL_OFF
    SP_HEADSPIN SP_HIDDEN SP_HOLIDAY SP_INDEPENDENT SP_INTERNAL SP_INVALID SP_INVBELONG SP_INVLABEL
    SP_INVUNDOC SP_ISARRAY SP_ISCLASS SP_ISSPECIAL SP_LECTURE SP_NEXTING SP_NOARRAY SP_NOBELONG
    SP_NOCURRICULUM SP_NODATA SP_NODIM SP_NORESUME SP_NOSTUDENT SP_NOSUCHBELONG
    SP_NOSUCHLABEL SP_NOSYSCALL SP_NOTCLASS SP_QUANTUM SP_READ SP_RESUME SP_SPLAT
    SP_SPOTS SP_SUBSCRIPT SP_SUBVERSION SP_SWAP SP_SYSCALL SP_TODO SP_TOOMANYLABS SP_UBUG
    SP_UNDOCUMENTED
);
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(
    bytedecode bytename bc_skip BCget is_constant NUM_OPCODES add_bytecode BC
    BC_BLM BC_CFG BC_CFL BC_CON BC_CRE BC_DES BC_GUP BC_HSN BC_NXG BC_NXL BC_NXT
    BC_OSN BC_QUA BC_STR BC_SUB BC_SWA BC_TRD BC_UNA BC_UNE BC_UNS BC_WHP
);
use Language::INTERCAL::Registers '1.-94.-2.2', qw(
    REG_spot REG_twospot REG_tail REG_hybrid REG_dos REG_whp REG_shf REG_cho
    reg_code2 reg_create reg_decode reg_list reg_translate
    DOS_AR DOS_AW DOS_BA DOS_CF DOS_CR DOS_CW DOS_DM DOS_GU DOS_IO DOS_IS
    DOS_JS DOS_OS DOS_PS DOS_RM DOS_RT DOS_SM DOS_SP DOS_SS DOS_TM DOS_WT
    WHP_ORFH WHP_OSFH WHP_OWFH WHP_TRFH
);
use Language::INTERCAL::Object '1.-94.-2.2', qw(:SFLAG);
use Language::INTERCAL::GenericIO '1.-94.-2', qw($stdsplat);
use Language::INTERCAL::Numbers '1.-94.-2.2', qw(
    n_interleave n_uninterleave n_select n_unselect
    n_bitdiv n_unbitdiv n_arithdiv n_unarithdiv
    n_awc n_unawc n_swb n_unswb n_but n_unbut
);
use Language::INTERCAL::Arrays '1.-94.-2.2',
    qw(make_array make_list get_element set_element replace_array array_elements);
use Language::INTERCAL::ReadNumbers '1.-94.-2', qw(read_number roman_type);
use Language::INTERCAL::WriteNumbers '1.-94.-2', qw(write_number);
use Language::INTERCAL::ArrayIO '1.-94.-2',
    qw(read_array_16 read_array_32 write_array_16 write_array_32 iotype_default);
use Language::INTERCAL::Charset::Baudot '1.-94.-2', qw(baudot2ascii);
use Language::INTERCAL::SharkFin '1.-94.-2.2', qw(make_sharkfin);
use Language::INTERCAL::DoubleOhSeven '1.-94.-2.2', qw(make_doubleohseven);
use Language::INTERCAL::Server '1.-94.-2.1';
use Language::INTERCAL::Extensions '1.-94.-2.1', qw(load_extension);
use Language::INTERCAL::Time '1.-94.-2.3', qw(current_time);

@EXPORT_OK = qw(
    add_opcode add_callback IFLAG_initialise IFLAG_norecompile IFLAG_clearcache

    reg_value reg_default reg_ignore reg_belongs reg_overload
    reg_enrol reg_assign reg_print reg_type reg_cache reg_trickle reg_pending

    thr_ab_gerund thr_ab_label thr_ab_once thr_assign thr_base thr_bytecode
    thr_cf_data thr_cf_gerund thr_code_cache thr_come_froms thr_current_pos
    thr_current_unit thr_diversions thr_grammar_record thr_in_diversion
    thr_in_loop thr_label_cache thr_lecture_stack thr_loop_code thr_loop_id
    thr_newline thr_next_stack thr_opcode thr_quantum thr_registers thr_rules
    thr_running thr_special thr_starting_pos thr_stash thr_statements thr_tid
    thr_trace_init thr_trace_item thr_trace_getnum thr_trace_mark
    thr_trace_exit thr_tracing thr_trickling
);

$DATAVERSION = '@@VERSION@@';
compare_version($VERSION, $DATAVERSION) < 0 and $VERSION = $DATAVERSION;

use constant MAX_NEXT => 80;

use constant IFLAG_initialise  => 0x01;
use constant IFLAG_norecompile => 0x02;
use constant IFLAG_clearcache  => 0x04;

# COME FROM / NEXT FROM description bits; CF_threaded and CF_gerund can also appear
# in the %CF register
use constant CF_threaded       => 0x01;
use constant CF_gerund         => 0x02;
use constant CF_save_return    => 0x04;
use constant CF_once           => 0x08;

# fields in a register
use constant reg_value          =>  0;
use constant reg_default        =>  1;
use constant reg_ignore         =>  2;
use constant reg_belongs        =>  3;
use constant reg_overload       =>  4;
use constant reg_enrol          =>  5;
use constant reg_assign         =>  6; # special register assignment callback
use constant reg_print          =>  7; # special register display value callback
use constant reg_type           =>  8; # special register type
use constant reg_cache          =>  9; # %CF caches come from data here
use constant reg_trickle        => 10; # trickle down state
use constant reg_pending        => 11; # pending updates

# fields in the thread pointer
use constant thr_ab_gerund      => 0;
use constant thr_ab_label       => 1;
use constant thr_ab_once        => 2;
use constant thr_assign         => 3;
use constant thr_base           => 4;    # ready for future use, ignored for now
use constant thr_bytecode       => 5;
use constant thr_cf_data        => 6;
use constant thr_cf_gerund      => 7;    # ready for future use, ignored for now
use constant thr_code_cache     => 8;
use constant thr_come_froms     => 9;
use constant thr_current_pos    => 10;
use constant thr_current_unit   => 11;
use constant thr_diversions     => 12;
use constant thr_grammar_record => 13;
use constant thr_in_diversion   => 14;   # ready for future use, ignored for now
use constant thr_in_loop        => 15;
use constant thr_label_cache    => 16;
use constant thr_lecture_stack  => 17;
use constant thr_loop_code      => 18;
use constant thr_loop_id        => 19;
use constant thr_newline        => 20;
use constant thr_next_stack     => 21;
use constant thr_opcode         => 22;
use constant thr_quantum        => 23;
use constant thr_registers      => 24;
use constant thr_rules          => 25;
use constant thr_running        => 26;
use constant thr_special        => 27;
use constant thr_starting_pos   => 28;
use constant thr_stash          => 29;
use constant thr_statements     => 30;
use constant thr_tid            => 31;
use constant thr_trace_exit     => 32;
use constant thr_trace_getnum   => 33;
use constant thr_trace_init     => 34;
use constant thr_trace_item     => 35;
use constant thr_trace_mark     => 36;
use constant thr_tracing        => 37;
use constant thr_trickling      => 38;

# load ByteCode specification
@@DATA ByteCode@@

my @statement_opcodes = (
    \&_s_@@NAME@@, # @@ARRAY STATEMENTS NUMBER@@
    undef,    # @@NUMBER@@
);

my @evaluable_opcodes = (
    \&_e_@@NAME@@, # @@ARRAY EVALUABLES NUMBER@@
    undef,    # @@NUMBER@@
);

my @assignable_opcodes = (
    \&_a_@@NAME@@, # @@ARRAY ASSIGNABLES NUMBER@@
    undef,    # @@NUMBER@@
);

my @regname_opcodes = (
    \&_r_@@NAME@@, # @@ARRAY REGNAMES NUMBER@@
    undef,    # @@NUMBER@@
);

my @all_opcodes = (
    1, # @@ARRAY OPCODES NUMBER@@
    0, # @@NUMBER@@
);

# line @@LINE@@

# four opcodes have special treatment
my @come_froms;
$come_froms[BC_CFL] = 0;
$come_froms[BC_CFG] = CF_gerund;
$come_froms[BC_NXL] = CF_save_return;
$come_froms[BC_NXG] = CF_gerund | CF_save_return;

my %causes_recompile = map { ( $_ => 1 ) } (DOS_PS, DOS_SS, DOS_JS, DOS_IS);
my %check_changes = (%causes_recompile, map { ( $_ => 1 ) } (DOS_CF, DOS_TM));

my %unx_cache; # see _i_UNx()

my %callback = (
    new    => [],
    start  => [],
    run    => [],
    stop   => [],
);

sub add_opcode {
    @_ >= 6 && @_ <= 8
	or croak "Usage: add_opcode(NUMBER, NAME, TYPE, ARGS, DESCR, CODE [, ACODE [, RCODE]])";
    my ($number, $name, $type, $args, $descr, $code, $acode, $rcode) = @_;
    $number >= 0 && $number < NUM_OPCODES or croak "Invalid opcode $number";
    $all_opcodes[$number] and croak "Duplicate opcode $number";
    ref $code && has_type($code, 'CODE')
	or croak "CODE must be a code reference";
    add_bytecode($name, $descr, $type, $number, $args);
    if ($type eq 'S') {
	@_ == 6 or croak "One CODE argument must be provided for TYPE 'S'";
	$statement_opcodes[$number] = $code;
    } elsif ($type =~ /^\?([LG])([CN])([AO])$/) {
	my $bitmap = 0;
	$1 eq 'N' and $bitmap |= CF_save_return;
	$2 eq 'G' and $bitmap |= CF_gerund;
	$3 eq 'O' and $bitmap |= CF_once;
	@_ == 6 or croak "One CODE argument must be provided for TYPE '$type'";
	$statement_opcodes[$number] = $code;
	$come_froms[$number] = $bitmap;
    } elsif ($type eq 'E') {
	@_ == 6 or croak "One CODE argument must be provided for TYPE 'E'";
	$evaluable_opcodes[$number] = $code;
    } elsif ($type eq 'A') {
	@_ == 7 or croak "Two CODE arguments must be provided for TYPE 'A'";
	ref $code && has_type($code, 'CODE')
	    or croak "CODE must be a code reference";
	ref $acode && has_type($acode, 'CODE')
	    or croak "ACODE must be a code reference";
	$evaluable_opcodes[$number] = $code;
	$assignable_opcodes[$number] = $acode;
    } elsif ($type eq 'R') {
	@_ == 8 or croak "Three CODE arguments must be provided for TYPE 'R'";
	ref $code && has_type($code, 'CODE')
	    or croak "CODE must be a code reference";
	ref $acode && has_type($acode, 'CODE')
	    or croak "ACODE must be a code reference";
	ref $rcode && has_type($rcode, 'CODE')
	    or croak "RCODE must be a code reference";
	$evaluable_opcodes[$number] = $code;
	$assignable_opcodes[$number] = $acode;
	$regname_opcodes[$number] = $rcode;
    } else {
	croak "Invalid TYPE, supported are A, E, R, S";
    }
    $all_opcodes[$number] = 1;
}

sub add_callback {
    @_ >= 2 or croak "Usage: add_callback(WHICH, CODE [, ARGS])";
    my ($which, $code, @args) = @_;
    exists $callback{$which} or croak "Invalid value for WHICH ($which)";
    ref $code && has_type($code, 'CODE')
	or croak "CODE must be a code reference";
    push @{$callback{$which}}, [$code, @args];
}

sub _run_callbacks {
    my ($which, $int) = @_;
    for my $cb (@{$callback{$which}}) {
	my ($code, @args) = @$cb;
	$code->($int, @args);
    }
}

sub new {
    @_ == 1 || @_ == 2
	or croak "Usage: Language::INTERCAL::Interpreter->new([OBJECT])";
    my $class = shift;
    my $object = @_ ? shift : Language::INTERCAL::Object->new;
    my %int = (
	tid => 0,
	threads => [],
	events => [],
	object => $object,
	loop_id => 0,
	ab_count => 0,
	syscode => {},
	record_grammar => 0,
	verbose => 0,
	server => 0,
	compiling => 0,
	stolen => {},
	rules => '',
	last_rule => 0,
    );
    for my $flag ($object->all_flags) {
	$flag =~ /^LOAD_(.*)$/ or next;
	my $ext = $1;
	load_extension($ext);
    }
    $int{default} = _make_thread($object, undef, \%int);
    bless \%int, $class;
    _run_callbacks('new', \%int);
    \%int;
}

sub verbose_compile {
    @_ == 1 || @_ == 2
	or croak "Usage: INTERPRETER->verbose_compile [(VALUE)]";
    my ($int) = shift;
    my $rv = $int->{verbose};
    $int->{verbose} = shift if @_;
    $rv;
}

sub object {
    @_ == 1 or croak "Usage: INTERPRETER->object";
    my ($int) = @_;
    $int->{object};
}

sub getreg {
    @_ == 2 or croak "Usage: INTERPRETER->getreg(NAME)";
    my ($int, $name) = @_;
    my ($type, $number) = reg_translate($name);
    # we've always followed overloads here so now that we moved overloads from
    # the values to the registers we need to call _get_register_2 to do the
    # necessary
    $int->{default}[thr_registers][$type][$number]
	and return _get_register_2($int, $int->{default}, $type, $number);
    croak "Unset register $name";
}

sub setreg {
    @_ == 4 or croak "Usage: INTERPRETER->setreg(NAME, VALUE, VTYPE)";
    my ($int, $name, $value, $vtype) = @_;
    my ($type, $number) = reg_translate($name);
    # we need to make sure things like base presets etc are set up, so rather
    # than saving the value here we imitate a STO $value REG
    _set_register_2($int, $int->{default}, $type, $number, $value, $vtype);
    $int;
}

sub allreg {
    @_ == 2 || @_ == 3
	or croak "Usage: INTERPRETER->allreg(CODE [, DEFAULT_MODE])";
    my ($int, $code, $dm) = @_;
    $dm ||= 'dn';
    # find all registers
    my $tp = $int->{default};
    my $show_default = $dm =~ /d/;
    my $show_nondefault = $dm =~ /n/;
    for my $type (REG_spot, REG_twospot, REG_tail, REG_hybrid, REG_dos, REG_shf, REG_whp) {
	my $rp = $tp->[thr_registers][$type];
	$rp or next;
	for (my $number = 0; $number < @$rp; $number++) {
	    $rp->[$number] or next;
	    if ($rp->[$number][reg_default]) {
		$show_default or next;
	    } else {
		$show_nondefault or next;
	    }
	    $code->($type, $number, $rp->[$number]);
	}
    }
}

sub has_labels {
    @_ == 3 or croak "Usage: INTERPRETER->has_labels(LOW, HIGH)";
    my ($int, $low, $high) = @_;
    my $num_units = $int->{object}->num_units;
    for (my $unit = 0; $unit < $num_units; $unit++) {
	my $cptr = ($int->{object}->unit_code($unit))[3];
	my $shadow = 0;
	for my $sp (@$cptr) {
	    my ($sptr, $S) = @$sp;
	    $shadow > $sptr and next;
	    @$S or next;
	    my (undef, $sl, $ls, $ll) = @{$S->[0]};
	    $shadow = $sptr + $sl;
	    $ll or next; # non-constant label
	    $ls or next; # not a label
	    $ls >= $low && $ls <= $high and return 1; # found it
	}
    }
    0;
}

sub uses_labels {
    @_ == 3 or croak "Usage: INTERPRETER->uses_labels(LOW, HIGH)";
    my ($int, $low, $high) = @_;
    my $num_units = $int->{object}->num_units;
    for (my $unit = 0; $unit < $num_units; $unit++) {
	my ($code, $cptr) = ($int->{object}->unit_code($unit))[2, 3];
	my $shadow = 0;
	for my $sp (@$cptr) {
	    my ($sptr, $S) = @$sp;
	    $shadow > $sptr and next;
	    @$S or next;
	    my (undef, $sl, undef, undef, undef, undef, $ge, $cs, $cl) = @{$S->[0]};
	    $shadow = $sptr + $sl;
	    $ge == BC_NXT or next; # only interested in "DO (label) NEXT"
	    my $ep = $cs + $cl;
	    while ($cs < $ep) {
		my $byte = vec($code, $cs, 8);
		if (is_constant($byte)) {
		    BCget($code, \$cs, $ep);
		} else {
		    $cs++;
		    $byte == $ge or next;
		    # the label will follow, is it constant?
		    $byte = vec($code, $cs, 8);
		    is_constant($byte) or last;
		    my $val = BCget($code, \$cs, $ep);
		    $val >= $low && $val <= $high and return 1;
		    last;
		}
	    }
	}
    }
    0;
}

sub read {
    @_ == 2 || @_ == 3
	or croak "Usage: INTERPRETER->read(FILEHANDLE [, RUNNABLE?]";
    my ($int, $fh, $runnable) = (@_, 1);
    local $ENV{LC_COLLATE} = 'C'; # to make sort result reproducible
    $int->{object}->add_flag('__interpreter_format', 1);
    my $discard = $int->{object}->read($fh, $runnable);
    my $tp = $int->{default};
    # find all rules
    my $rules = $tp->[thr_rules];
    if ($discard) {
	# read all counts
	$fh->read_binary(pack('v*', scalar @$rules, map { scalar @$_ } @$rules));
    } else {
	my $rp = $tp->[thr_registers];
	# add item types
	my (@rtype, %rtype);
	# all numeric special registers i.e. double-oh-seven
	my @nregs;
	for (my $number = 0; $number < @{$rp->[REG_dos]}; $number++) {
	    $rp->[REG_dos][$number] or next;
	    my $t = $rp->[REG_dos][$number][reg_type];
	    if (! exists $rtype{$t}) {
		$rtype{$t} = @rtype;
		push @rtype, $t;
	    }
	    push @nregs, [$number, $rp->[REG_dos][$number][reg_value], $rtype{$t}];
	}
	# all array special registers i.e. shark-fin
	my @aregs;
	for (my $number = 0; $number < @{$rp->[REG_shf]}; $number++) {
	    $rp->[REG_shf][$number] or next;
	    my $t = $rp->[REG_shf][$number][reg_type];
	    if (! exists $rtype{$t}) {
		$rtype{$t} = @rtype;
		push @rtype, $t;
	    }
	    push @aregs, [$number, $rp->[REG_shf][$number][reg_value], $rtype{$t}];
	}
	# read all counts
	$fh->read_binary(pack('v*', scalar @nregs, scalar @aregs, scalar @rtype,
				    scalar @$rules, map { scalar @$_ } @$rules));
	# read all registers
	for my $r (@rtype) {
	    $fh->read_binary(pack('v/a*', $r));
	}
	for my $r (@nregs) {
	    my ($n, $v, $t) = @$r;
	    $fh->read_binary(pack('vCv', $n, $t, $v));
	}
	for my $r (@aregs) {
	    my ($n, $v, $t) = @$r;
	    $fh->read_binary(pack('vCv*', $n, $t, scalar @$v, @$v));
	}
    }
    # read all rules
    my $bitmap = $int->{rules};
    for my $r (@$rules) {
	$fh->read_binary(pack('C*', map { $_ ? (vec($bitmap, $_, 1) ? 2 : 1) : 0 } @$r));
    }
    # read all syscode
    my @sys = sort keys %{$int->{syscode}};
    $fh->read_binary(pack('v', scalar @sys));
    for my $sys (@sys) {
	$fh->read_binary(pack('v v/a*', $sys, $int->{syscode}{$sys}));
    }
    $int;
}

sub write {
    @_ == 2 || @_ == 3
	or croak "Usage: Language::INTERCAL::Interpreter->write("
	       . "FILEHANDLE [, AVOID_SKIP?])";
    my ($class, $fh, $ask) = @_;
    my ($object, $discard, $format) = Language::INTERCAL::Object->write($fh, 0, $ask);
    my $int = $class->new($object);
    # write all counts
    my ($nregs, $aregs, $ntype, $rcount);
    if ($discard) {
	$nregs = $aregs = $ntype = 0;
	($rcount) = unpack('v', $fh->write_binary(2));
    } else {
	($nregs, $aregs, $ntype, $rcount) = unpack('v4', $fh->write_binary(8));
    }
    my @rcount = unpack('v*', $fh->write_binary(2 * $rcount));
    # write all registers
    my @rtype = ();
    while (@rtype < $ntype) {
	my $tlen = unpack('v', $fh->write_binary(2));
	push @rtype, $fh->write_binary($tlen);
    }
    my $ptr = $int->{default};
    my $rp = $ptr->[thr_registers];
    while ($nregs-- > 0) {
	my ($num, $type, $val) = unpack('vCv', $fh->write_binary(5));
	my ($value, $assign, $print, $dtype) =
	    make_doubleohseven($rtype[$type], $object, $val, REG_spot);
	my @newreg;
	$newreg[reg_value] = $value;
	$newreg[reg_assign] = $assign;
	$newreg[reg_print] = $print;
	$newreg[reg_type] = $dtype;
	$newreg[reg_ignore] = 0;
	$newreg[reg_default] = 0;
	$rp->[REG_dos][$num] = \@newreg;
    }
    while ($aregs-- > 0) {
	my ($num, $type, $val) = unpack('vCv', $fh->write_binary(5));
	my @val = unpack('v*', $fh->write_binary(2 * $val));
	my ($value, $assign, $print, $dtype) =
	    make_sharkfin($rtype[$type], $object, \@val, REG_tail);
	my @newreg;
	$newreg[reg_value] = $value;
	$newreg[reg_assign] = $assign;
	$newreg[reg_print] = $print;
	$newreg[reg_type] = $dtype;
	$newreg[reg_ignore] = 0;
	$newreg[reg_default] = 0;
	$rp->[REG_shf][$num] = \@newreg;
    }
    # write all rules
    my $bitmap = '';
    my $last_rule = 0;
    while ($rcount-- > 0) {
	my $r = shift @rcount;
	my @r = ();
	for my $v (unpack('C*', $fh->write_binary($r))) {
	    if ($v) {
		my $r = ++$last_rule;
		$v > 1 and vec($bitmap, $r, 1) = 1;
		push @r, $r;
	    } else {
		push @r, 0;
	    }
	}
	push @{$ptr->[thr_rules]}, \@r;
    }
    $int->{rules} = $bitmap;
    $int->{last_rule} = $last_rule;
    # write all syscode
    my $sys = unpack('v', $fh->write_binary(2));
    while ($sys-- > 0) {
	my ($num, $len) = unpack('vv', $fh->write_binary(4));
	$int->{syscode}{$num} = $fh->write_binary($len);
    }
    # old object formats had a opcode creation record, which we no longer support;
    # however we'll have to skip it
    if ($format == 0) {
	my $ncodes = $format ? 0 : unpack('v', $fh->write_binary(2));
	while ($ncodes-- > 0) {
	    my ($op, $tl, $cl) = unpack('vvv', $fh->write_binary(6));
	    $fh->write_binary($tl + $cl);
	}
    }
    $int;
}

sub _dup_thread {
    my ($int, $tp) = @_;
    my $dt = _make_thread($int->{object}, $tp, $int);
    push @{$int->{threads}}, $dt;
    $dt;
}

sub _make_thread {
    my ($object, $tp, $int) = @_;
    my @thread;
    $thread[thr_tid]            = ++$int->{tid};
    $thread[thr_registers]      = [];
    $thread[thr_stash]          = [];
    $thread[thr_rules]          = [];
    $thread[thr_running]        = 1;
    if ($tp) {
	# copy common pointers
	$thread[thr_current_unit] = $tp->[thr_current_unit];
	$thread[thr_current_pos] = $tp->[thr_current_pos];
	$thread[thr_bytecode] = $tp->[thr_bytecode];
	$thread[thr_special] = $tp->[thr_special];
	$thread[thr_cf_data] = [@{$tp->[thr_cf_data]}];
	# copy the thread's registers
	for my $type (REG_spot, REG_twospot, REG_tail, REG_hybrid, REG_dos, REG_shf, REG_whp) {
	    $thread[thr_registers][$type] = [];
	    my $rp = $tp->[thr_registers][$type];
	    $rp or next;
	    for (my $number = 0; $number < @$rp; $number++) {
		$rp->[$number] or next;
		$thread[thr_registers][$type][$number] = $rp->[$number];
		$tp->[thr_stash][$type][$number] or next;
		$thread[thr_stash][$type][$number] = $tp->[thr_stash][$type][$number];
	    }
	}
	$thread[thr_base] = $tp->[thr_base];
	$thread[thr_cf_gerund] = $tp->[thr_cf_gerund];
	# copy the thread's opcodes, assignments, stacks
	$thread[thr_statements] = [@{$tp->[thr_statements]}];
	$thread[thr_come_froms] = [@{$tp->[thr_come_froms]}];
	$thread[thr_assign] = {%{$tp->[thr_assign]}};
	$thread[thr_next_stack] = _deep_copy($tp->[thr_next_stack]);
	$thread[thr_lecture_stack] = _deep_copy($tp->[thr_lecture_stack]);
	# copy the thread's rules
	for my $ra (@{$tp->[thr_rules]}) {
	    my @ra = @{$ra || []};
	    push @{$thread[thr_rules]}, \@ra;
	}
	# copy cached statement data, note that at this point we share the cache
	$thread[thr_code_cache] = $tp->[thr_code_cache];
	$thread[thr_label_cache] = $tp->[thr_label_cache];
	# copy current abstain status
	$thread[thr_ab_label] = {%{$tp->[thr_ab_label]}};
	$thread[thr_ab_gerund] = {%{$tp->[thr_ab_gerund]}};
	$thread[thr_ab_once] = {%{$tp->[thr_ab_once]}};
	# copy any current loop
	$thread[thr_loop_code] = [@{$tp->[thr_loop_code]}];
	$thread[thr_loop_id] = {%{$tp->[thr_loop_id]}};
	$thread[thr_in_loop] = [@{$tp->[thr_in_loop]}];
	# copy the current records
	$thread[thr_grammar_record] = $tp->[thr_grammar_record];
	# undocumented I/O mode
	$thread[thr_newline] = $tp->[thr_newline];
	# roadworks
	$thread[thr_diversions] = [@{$tp->[thr_diversions]}];
	$thread[thr_in_diversion] = [@{$tp->[thr_in_diversion]}];
	# trickling summary information; we'll regenerate it when needed
	$thread[thr_trickling] = undef;
    } else {
	$thread[thr_current_unit] = 0;
	$thread[thr_current_pos] = 0;
	$thread[thr_newline] = 1;
	$thread[thr_base] = 2;
	$thread[thr_cf_gerund] = 0;
	$thread[thr_code_cache] = [];
	$thread[thr_label_cache] = [];
	$thread[thr_next_stack] = [];
	$thread[thr_lecture_stack] = [];
	$thread[thr_cf_data] = [];
	$thread[thr_statements] = [];
	$thread[thr_come_froms] = [];
	$thread[thr_assign] = {};
	$thread[thr_ab_label] = {};
	$thread[thr_ab_gerund] = {};
	$thread[thr_ab_once] = {};
	$thread[thr_loop_code] = [];
	$thread[thr_loop_id] = {};
	$thread[thr_in_loop] = [];
	$thread[thr_grammar_record] = [];
	$thread[thr_diversions] = [];
	$thread[thr_in_diversion] = [];
	$thread[thr_trickling] = undef;
	# create an initial set of registers
	for my $r (reg_list) {
	    my ($type, $number) = reg_translate($r);
	    my ($value, $assign, $print, $dtype) = reg_create($type, $number, $object);
	    my @newreg;
	    _create_register($int, \@thread, $type, $number);
	    $newreg[reg_value] = $value;
	    $newreg[reg_assign] = $assign;
	    $newreg[reg_print] = $print;
	    $newreg[reg_type] = $dtype;
	    $newreg[reg_ignore] = 0;
	    $newreg[reg_default] = 1;
	    $thread[thr_registers][$type][$number] = \@newreg;
	}
	# creates an initial set of opcodes - copy is intentional
	@{$thread[thr_statements]} = map { my $x = $_; \$x; } @statement_opcodes;
	@{$thread[thr_come_froms]} = map { my $x = $_; \$x; } @come_froms;
    }
    _set_thread_tracing($int, \@thread);
    return \@thread;
}

sub _deep_copy {
    my ($src) = @_;
    return $src if ! defined $src || ! ref $src;
    # don't copy filehandles...
    if (eval { $src->isa('Language::INTERCAL::GenericIO') }) {
	return $src;
    }
    if (ref $src eq 'GLOB' || has_type($src, 'GLOB')) {
	return $src;
    }
    if (ref $src eq 'CODE') {
	# no deep copy of code...
	return $src;
    }
    if (ref $src eq 'SCALAR' || ref $src eq 'REF') {
	my $c = $$src;
	return \$c;
    }
    if (has_type($src, 'SCALAR')) {
	my $c = $$src;
	bless \$c, ref $src;
	return \$c;
    }
    if (ref $src eq 'ARRAY') {
	my $c = [ map { _deep_copy($_) } @$src ];
	return $c;
    }
    if (has_type($src, 'ARRAY')) {
	my $c = [ map { _deep_copy($_) } @$src ];
	bless $c, ref $src;
	return $c;
    }
    if (ref $src eq 'HASH') {
	my $c = { map { ( $_ => _deep_copy($src->{$_}) ) } keys %$src };
	return $c;
    }
    if (has_type($src, 'HASH')) {
	my $c = { map { ( $_ => _deep_copy($src->{$_}) ) } keys %$src };
	bless $c, ref $src;
	return $c;
    }
    if (ref $src eq 'Regexp') {
	return qr/$src/;
    }
    if (has_type($src, 'Regexp')) {
	my $c = qr/$src/;
	bless $c, ref $src;
	return $c;
    }
    faint(SP_INTERNAL, "_deep_copy of unrecognised reference");
}

sub start {
    @_ == 1 || @_ == 2
	or croak "Usage: INTERPRETER->start [(FLAGS)]";
    my ($int, $flags) = @_;
    delete $int->{gave_up};
    $int->{threads} = [];
    $int->{tid} = 0;
    $int->{compiling} = $flags || 0;
    if ($int->{compiling} & IFLAG_initialise) {
	for my $type (REG_spot, REG_twospot, REG_tail, REG_hybrid) {
	    $int->{default}[thr_registers][$type] = [];
	}
	for my $type (REG_dos, REG_shf, REG_whp) {
	    my $rp = $int->{default}[thr_registers][$type];
	    $rp or next;
	    for my $reg (@$rp) {
		$reg and $reg->[reg_ignore] = 0;
	    }
	}
	$int->{default}[thr_stash] = [];
	$int->{default}[thr_assign] = {};
	$int->{default}[thr_next_stack] = [];
	$int->{default}[thr_lecture_stack] = [];
	$int->{default}[thr_ab_label] = {};
	$int->{default}[thr_ab_gerund] = {};
	$int->{default}[thr_ab_once] = {};
    }
    if ($int->{compiling} & (IFLAG_initialise | IFLAG_clearcache)) {
	$int->{default}[thr_code_cache] = [];
	$int->{default}[thr_label_cache] = [];
	$int->{default}[thr_registers][REG_dos][DOS_CF]
	    and $int->{default}[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    }
    _set_register_2($int, $int->{default}, REG_dos, DOS_SP, 1000, REG_spot);
    for my $flag ($int->{object}->all_flags) {
	$flag =~ /^LOAD_(.*)$/ or next;
	my $ext = $1;
	load_extension($ext);
    }
    _run_callbacks('start', $int);
    $int;
}

sub save_code {
    @_ == 1 or croak "Usage: INTERPRETER->save_code";
    my ($int) = @_;
    my $num_units = $int->{object}->num_units;
    my @code;
    for (my $unit = 0; $unit < $num_units; $unit++) {
	my $code = $int->{object}->save_unit_code($unit);
	# XXX we could save the cache here, but if we call _cache_statements here we get invalid code
#	push @code, [$dt->[thr_code_cache], $code];
	push @code, [undef, undef, $code];
    }
    @code;
}

sub prepend_code {
    @_ >= 1 or croak "Usage: INTERPRETER->prepend_code [(CODE, ...)]";
    my ($int, @code) = @_;
    @code or return $int;
    my $dt = $int->{default};
    while (@code) {
	my ($code_cache, $label_cache, $code) = @{pop @code};
	unshift @{$dt->[thr_code_cache]}, $code_cache;
	unshift @{$dt->[thr_label_cache]}, $label_cache;
	$int->{object}->prepend_unit_code($code);
    }
    $dt->[thr_registers][REG_dos][DOS_CF]
	and $dt->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    $int;
}

sub restore_code {
    @_ >= 1 or croak "Usage: INTERPRETER->restore_code [(CODE, ...)]";
    my ($int, @code) = @_;
    $int->{object}->clear_code;
    my $dt = $int->{default};
    @{$dt->[thr_code_cache]} = ();
    @{$dt->[thr_label_cache]} = ();
    for (my $unit = 0; $unit < @code; $unit++) {
	my ($code_cache, $label_cache, $code) = @{$code[$unit]};
	$dt->[thr_code_cache][$unit] = $code_cache;
	$dt->[thr_label_cache][$unit] = $label_cache;
	$int->{object}->restore_unit_code($unit, $code);
    }
    $dt->[thr_registers][REG_dos][DOS_CF]
	and $dt->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    $int;
}

sub stop {
    @_ == 1 or croak "Usage: INTERPRETER->stop";
    my ($int) = @_;
    _run_callbacks('stop', $int);
    $int->{threads} = [];
    $int->{loop_id} = 0;
    $int;
}

sub splat {
    @_ == 1 or croak "Usage: INTERPRETER->splat";
    my ($int) = @_;
    my $sp = $int->{default}[thr_registers][REG_dos][DOS_SP];
    $sp or return undef;
    $sp->[reg_print]->($int->{object}, $sp->[reg_value]);
}

sub server {
    @_ == 1 || @_ == 2 or croak "Usage: INTERPRETER->server [(NEW_SERVER)]";
    my $int = shift;
    my $old_server = $int->{server};
    $int->{server} = shift if @_;
    $old_server;
}

sub rcfile {
    @_ == 1 || @_ == 2 or croak "Usage: INTERPRETER->rcfile [(NEW_RCFILE)]";
    my $int = shift;
    my $old_rcfile = $int->{rc};
    $int->{rc} = shift if @_;
    $old_rcfile;
}

sub run {
    @_ == 1 || @_ == 2 or croak "Usage: INTERPRETER->run [(INTERPRETER)]";
    my ($int, $ci) = @_;
    my $default = $int->{default};
    if ($ci && $ci != $int) {
	$default->[thr_code_cache] = [];
	$default->[thr_label_cache] = [];
	my $cr = $ci->{default}[thr_rules][0];
	if ($cr) {
	    my $ir = $default->[thr_rules][0];
	    my $bm = $int->{rules};
	    my $lr = $int->{last_rule};
	    for (my $r = 0; $r < @$cr; $r++) {
		next unless $cr->[$r];
		$ir->[$r] = $cr->[$r];
		if (! $ir->[$r]) {
		    my $ptr = ++$lr;
		    vec($ci->{rules}, $cr->[$r], 1)
			and vec($bm, $ptr, 1) = 1;
		    $ir->[$r] = $ptr;
		}
	    }
	    $int->{rules} = $bm;
	    $int->{last_rule} = $lr;
	}
	$int->{runobject} = $ci->{object};
    } else {
	$default->[thr_code_cache] or $default->[thr_code_cache] = [];
	$default->[thr_label_cache] or $default->[thr_label_cache] = [];
	$int->{runobject} = $int->{object};
    }
    my $tp = _make_thread($int->{object}, $default, $int);
    $int->{threads} = [$tp];
    $int->{loop_id} = 0;
    $int->{events} ||= [];
    _run_callbacks('run', $int);
    $tp->[thr_current_unit] = 0;
    $tp->[thr_current_pos] = 0;
    $tp->[thr_bytecode] = ($int->{runobject}->unit_code(0))[2];
    $tp->[thr_special] = undef;
    my $ep = $int->{events};
    $tp = $int->{threads};
    while (@$tp) {
	$int->{server} and $int->{server}->progress(0);
	for (my $n = 0; $n < @$tp; $n++) {
	    $tp->[$n][thr_quantum] = undef;
	    if (@{$tp->[$n][thr_in_loop]}) {
		# if this is a loop condition, stop the body
		my $loop_id = pop @{$tp->[$n][thr_in_loop]};
		delete $tp->[$n][thr_loop_id]{$loop_id};
		@{$tp->[$n][thr_in_loop]}
		    or $tp->[$n][thr_bytecode] =
			($int->{runobject}->unit_code($tp->[$n][thr_current_unit]))[2];
	    }
	    &{$tp->[$n]->[thr_trace_init]};
	    eval { _step($int, $tp->[$n]) };
	    # report a splat if appropriate
	    if ($@) {
		_splat($int, $tp->[$n], $@);
		$tp->[$n][thr_quantum] or $tp->[$n][thr_running] = 0;
	    }
	    $tp->[$n][thr_trace_exit]->($tp->[$n]);
	    # check if the thread is still running e.g no GIVE UP or splat
	    if (! $tp->[$n][thr_running]) {
		splice(@$tp, $n, 1);
		$n--;
	    }
	}
	if (@$ep) {
	    for (my $e = 0; $e < @$ep; $e++) {
		my $etp = _make_thread($int->{object}, $default, $int);
		&{$etp->[thr_trace_init]};
		my ($cond, $body, $bge) = @{$ep->[$e]};
		$etp->[thr_bytecode] = $etp->[thr_special] = $cond;
		$etp->[thr_trace_mark]->($etp, 'EVENT', $e);
		eval {
		    # localise the effects of splatting so that we can safely just run
		    # the condition and see what happens, but the splat outside the
		    # eval will be whatever the thread had before; this is assuming
		    # that nobody has created something to be able to overload %SP,
		    # but if they do that they can sort out what that means
		    local $etp->[thr_registers][REG_dos][DOS_SP][reg_value] =
			  $etp->[thr_registers][REG_dos][DOS_SP][reg_value];
		    my $cp = 0;
		    _run_e($int, $etp, \$cp, length $cond);
		};
		if ($@) {
		    $etp->[thr_trace_exit]->($etp);
		    next;
		}
		$etp->[thr_trace_exit]->($etp);
		# the condition succeeds so keep this thread and make it run the body
		$etp->[thr_loop_code] = [$body, $bge, undef];
		$etp->[thr_cf_data] = [];
		splice(@$ep, $e, 1);
		$e--;
		push @$tp, $etp;
	    }
	}
    }
    $int;
}

sub _splat {
    my ($int, $tp, $smsg) = @_;
    my $scode;
    if ($smsg =~ s/^\*?(\d+)\s*//) {
	$scode = $1;
	$scode =~ s/^0*(\d)/$1/;
	$smsg = sprintf("*%03d %s", $scode, $smsg);
    } else {
	$scode = 0;
	$smsg = "*000 $smsg";
    }
    $smsg =~ s/\n*$/\n/;
    my $r = $tp->[thr_registers][REG_whp][WHP_OSFH][reg_value]{filehandle} || $stdsplat;
    eval { $r->read_text($smsg) };
    _create_register($int, $tp, REG_dos, DOS_SP);
    my $sp = $tp->[thr_registers][REG_dos][DOS_SP];
    $sp->[reg_default] = 0;
    $sp->[reg_value] = $sp->[reg_assign]->($int->{runobject}, $scode, REG_spot);
}

sub _cache_statements {
    my ($int, $tp, $unit) = @_;
    my %stmt;
    my @labs;
    my @cfroms;
    my $cfg = $tp->[thr_registers][REG_dos][DOS_CF]
	    ? $tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund
	    : undef;
    my $rules = $tp->[thr_rules][0];
    my $bitmap = $int->{rules};
    my ($code, $cptr) = ($int->{runobject}->unit_code($unit))[2, 3];
    my $shadow = 0;
    for my $sp (@$cptr) {
	my ($sptr, $S) = @$sp;
	$shadow > $sptr and next;
    STMT:
	for my $p (@$S) {
	    my ($fl, $sl, $ls, $ll, $ds, $dl, $ge, $xs, $xl, $ru) = @$p;
	    if ($rules && defined $ru) {
		for (my ($p, $rn) = (0, 0); $p < length $ru; $p++) {
		    if (vec($ru, $p, 8)) {
			for (my $q = 0; $q < 8; $q++, $rn++) {
			    vec($ru, $rn, 1) or next;
			    next STMT if ! vec($bitmap, $rules->[$rn], 1);
			}
		    } else {
			$rn += 8;
		    }
		}
	    }
	    # found an enabled statement
	    $shadow = $sptr + $sl;
	    # add this to the code cache
	    $stmt{$sptr} = [$xs, $xl, $sl, $fl, $ls, $ll, $ds, $dl, $ge];
	    # see if we need to add this to the label cache
	    $ls > 0 || $ll > 0 and push @labs, [$sptr, $ls, $ll];
	    # see if we need to add this to the COME FROM cache
	    defined $cfg or last STMT;
	    $xl > 0 or last STMT;
	    my $op = $tp->[thr_come_froms][$ge];
	    defined $op or last STMT; # not currently a COME FROM/NEXT FROM
	    $op = $$op;
	    defined $op or last STMT; # not currently a COME FROM/NEXT FROM
	    $xl += $xs;
	    $xs++;
	    # this is duplicated code from _make_comefrom_cache, however we are
	    # in an inner loop here so duplicated code is better than a sub call
	    my ($tn, $tc, $gl);
	    if ($op & CF_gerund) {
		$cfg or last STMT; # not enabled in this thread
		$gl = [_get_gerunds($tp, \$xs, $xl, 1)];
		@$gl or last STMT; # empty COME FROM?
	    } else {
		if (is_constant(vec($code, $xs, 8))) {
		    $tn = BCget($code, \$xs, $xl);
		} else {
		    $tc = substr($code, $xs, $xl - $xs);
		}
	    }
	    my $nxt = $op & CF_save_return;
	    my $lc;
	    $ll and $lc = substr($code, $ls, $ll);
	    my $dc;
	    $dl and $dc = substr($code, $ds, $dl);
	    push @cfroms, [$ls, $lc, $ge, $fl, $ds, $dc, $tn, $tc, $gl, $nxt, $sptr, $sl];
	    last STMT;
	}
    }
    $tp->[thr_code_cache][$unit] = \%stmt;
    $tp->[thr_label_cache][$unit] = \@labs;
    defined $cfg
	and $tp->[thr_registers][REG_dos][DOS_CF][reg_cache][$unit] = \@cfroms;
}

sub _step {
    my ($int, $tp) = @_;
    # check for any pending trickling down
    $tp->[thr_trickling] || _create_trickling($tp);
    if (defined $tp->[thr_trickling][REG_cho]) {
	my $now = current_time;
	my $trickling = $tp->[thr_trickling];
	if ($now >= $trickling->[REG_cho]) {
	    # there may be work to do...
	    $tp->[thr_trickling][REG_cho] = undef;
	    for (my $type = 0; $type < @$trickling; $type++) {
		$type == REG_cho and next;
		$trickling->[$type] or next;
		for my $number (sort { $a <=> $b } keys %{$trickling->[$type]}) {
		    my $list = $tp->[thr_registers][$type][$number][reg_pending];
		    $list or next;
		    my $p = 0;
		    while ($p < @$list) {
			my ($assign, $atype, $when) = @{$list->[$p]};
			if ($now >= $when) {
			    # we have to execute this assignment; note that this
			    # could trigger further trickling, including some
			    # trickling with delay 0 which we'll have to do now
			    splice(@$list, $p, 1);
			    if ($tp->[thr_tracing]) {
				my $d = reg_decode($type, $number);
				my $v;
				if (! defined $assign) {
				    $v = '(undef)';
				} elsif ($atype == REG_spot || $atype == REG_twospot) {
				    $v = "#$assign";
				} elsif ($atype == REG_tail || $atype == REG_hybrid) {
				    $v = $assign; # XXX convert this somehow
				} elsif ($atype == REG_whp) {
				    if (ref $assign && eval { $assign->isa('Language::INTERCAL::GenericIO') }) {
					$v = $assign->describe;
				    } else {
					$v = $assign; # XXX convert this somehow
				    }
				}
				$tp->[thr_trace_mark]->($tp, 'TRICKLED', $d, '<-', $v);
			    }
			    _set_register_2($int, $tp, $type, $number, $assign, $atype);
			} else {
			    defined $tp->[thr_trickling][REG_cho] &&
				$tp->[thr_trickling][REG_cho] <= $when
				    or $tp->[thr_trickling][REG_cho] = $when;
			    $p++;
			}
		    }
		}
	    }
	}
    }
    # find current statement - note that we may try to execute the middle of a comment!
    my ($cs, $cl, $ge, $fl, $lab, $ls, $ll, $cp, $un, $once);
    $tp->[thr_cf_data] = [];
    if (@{$tp->[thr_loop_code]}) {
	my ($code, $id);
	($code, $ge, $id) = @{$tp->[thr_loop_code]};
	if (defined $id) {
	    # check loop condition still exists
	    my $found = 0;
	    for my $t (@{$int->{threads}}) {
		next if ! $t->[thr_running] || ! exists $t->[thr_loop_id]{$id}; # XXX
		$found = 1;
		last;
	    }
	    if (! $found) {
		$tp->[thr_running] = 0;
		$tp->[thr_trace_mark]->($tp, 'ENDLOOP', $id);
		return;
	    }
	    $tp->[thr_trace_mark]->($tp, 'LOOP', $id);
	} else {
	    # event, which must be executed just this once, so next time
	    # we are going to find an unexistent loop_id; however note that
	    # we cannot just set thr_running = 0 here because the loop
	    # body could be a NEXT, LEARN or the tegrat of a NEXT FROM
	    # so we need to keep running until we return and pop this
	    # loop_id from the stack. Like is complicated
	    $tp->[thr_loop_code] = ['', 0, -1];
	    $tp->[thr_trace_mark]->($tp, 'EVENT', $id);
	}
	$fl = $lab = $ls = $ll = $cs = 0;
	$cl = length $code;
	$tp->[thr_bytecode] = $tp->[thr_special] = $code;
	$once = $cp = undef;
    } else {
	my ($sl, $ds, $dl);
	$un = $tp->[thr_current_unit];
	$cp = $tp->[thr_current_pos];
	# check if we are leaving the current diversion
	while (@{$tp->[thr_in_diversion]}) {
	    my ($du, $d0, $d1, $ou, $op) = @{$tp->[thr_in_diversion][-1]};
	    $du == $un && $d0 <= $cp && $cp < $d1 and last;
	    pop @{$tp->[thr_in_diversion]};
	    $tp->[thr_trace_mark]->($tp, 'END_DIVERSION', $du, $d0, $d1, $ou, $op);
	    $un = $ou;
	    $cp = $op;
	}
	# first thing first, see if we are trying to enter a road closure
	if (@{$tp->[thr_diversions]}) {
	    my %seen;
	LOOK:
	    while (1) {
		for my $rc (@{$tp->[thr_diversions]}) {
		    my ($ru, $r0, $r1) = @$rc;
		    $ru == $un && $r0 <= $cp && $cp < $r1 or next;
		    # yep, enter diversion
		    exists $seen{$ru}{$r0}{$r1} and faint(SP_HEADSPIN);
		    $seen{$ru}{$r0}{$r1} = 1;
		    my (undef, undef, undef, $du, $d0, $d1) = @$rc;
		    $tp->[thr_trace_mark]->($tp, 'ENTER_DIVERSION', $ru, $r0, $r1, $du, $d0, $d1);
		    push @{$tp->[thr_in_diversion]}, [$du, $d0, $d1, $un, $r1];
		    $un = $du;
		    $cp = $d0;
		    next LOOK;
		}
		last LOOK;
	    }
	}
	$tp->[thr_code_cache][$un]
	    or _cache_statements($int, $tp, $un);
	if (! exists $tp->[thr_code_cache][$un]{$cp}) {
	    # not a start of statement, so treat it as a non-abstained comment
	    # see if there's a valid statement following, which will be the end of the comment
	    ($sl) = sort { $a <=> $b } grep { $_ > $cp } keys %{$tp->[thr_code_cache][$un]};
	    $tp->[thr_trace_mark]->($tp, 'EOP', $cp, defined $sl ? $sl : '?');
	    my ($source) = $int->{runobject}->unit_code($un);
	    if (! defined $sl && $source ne '') {
		$sl = length($source);
	    } elsif ($source eq '') {
		faint(SP_COMMENT, "Invalid statement");
	    }
	    my $line = substr($source, $cp, $sl - $cp);
	    $line =~ s/^\s+//;
	    $line =~ s/\s+$//;
	    faint(SP_COMMENT, $line) if $line =~ /\S/;
	    faint(SP_FALL_OFF) if $source ne '' && $cp >= length($source);
	    faint(SP_COMMENT, "Invalid statement");
	}
	# we have a valid statement (which could still be a comment!) so use it
	($cs, $cl, $sl, $fl, $ls, $ll, $ds, $dl, $ge) = @{$tp->[thr_code_cache][$un]{$cp}};
	if ($tp->[thr_tracing]) {
	    my @fl = map { ($fl & $_->[0]) ? ($_->[1]) : () } @stmt_flags;
	    @fl or push @fl, '-';
	    $tp->[thr_trace_mark]->($tp, 'STS', $cs, $cl, $cp, $sl, $fl, @fl);
	}
	if ($ll > 0) {
	    my $xls = $ls;
	    $lab = _get_spot($int, $tp, \$xls, $xls + $ll);
	    $tp->[thr_trace_mark]->($tp, 'LAB', $lab);
	} elsif ($ls > 0) {
	    # label is a constant, but need to check if the value of the, ehm,
	    # constant, has changed
	    if (exists $tp->[thr_assign]{$ls}) {
		$lab = ${$tp->[thr_assign]{$ls}};
		$tp->[thr_trace_mark]->($tp, 'LAB', $lab, $ls);
	    } else {
		$lab = $ls;
		$tp->[thr_trace_mark]->($tp, 'LAB', $ls);
	    }
	}
	$cl += $cs;
	$tp->[thr_starting_pos] = $cp;
	$tp->[thr_current_pos] = $cp + $sl;
	if ($ds > 0 || $dl > 0) {
	    my $dsx = $dl > 0
		    ? _get_spot($int, $tp, \$ds, $ds + $dl)
		    : $ds - 1;
	    my $dsa = rand(100) >= $dsx ? 1 : 0;
	    $tp->[thr_trace_mark]->($tp, 'DSX', $dsx, $dsa);
	    if ($dsa) {
		$ls || $ll || ($ge && ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund))
		    and _comefrom($int, $tp, $ls, $ll, $ge, $un, $cp);
		return;
	    }
	}
	# nowadays one can ABSTAIN FROM QUANTUM COMPUTING
	if (($fl & stmt_quantum) && exists $tp->[thr_ab_gerund]{&BC_QUA}) {
	    $tp->[thr_ab_gerund]{&BC_QUA}[0] and $fl &= ~stmt_quantum;
	}
	$fl & (stmt_once | stmt_again) and $once = "$un.$cp";
    }
    # check if an ABSTAIN/REINSTATE applies to this statement
    my $abr = 'NOT';
    my $count = 0;
    my $ab = $fl & stmt_abstain;
    # ABSTAIN FROM (label) acts on a GIVE UP if %GU is nonzero: this happens when
    # running in C-INTERCAL compatibility mode
    if ($lab && exists $tp->[thr_ab_label]{$lab} && $count < $tp->[thr_ab_label]{$lab}[1]) {
	! $ge || $ge != BC_GUP
	 || ($tp->[thr_registers][REG_dos] &&
	     $tp->[thr_registers][REG_dos][DOS_GU] &&
	     $tp->[thr_registers][REG_dos][DOS_GU][reg_value])
		and ($abr, $ab, $count) = ("LAB$lab", @{$tp->[thr_ab_label]{$lab}});
    }
    # ABSTAIN FROM (gerund) never acts on a GIVE UP or TRICKLE DOWN
    $ge && $ge != BC_GUP && $ge != BC_TRD &&
	exists $tp->[thr_ab_gerund]{$ge} && $count < $tp->[thr_ab_gerund]{$ge}[1]
	    and ($abr, $ab, $count) = ("GER$ge", @{$tp->[thr_ab_gerund]{$ge}});
    defined $once && exists $tp->[thr_ab_once]{$once} && $count < $tp->[thr_ab_once]{$once}[1]
	and ($abr, $ab, $count) = ("ONCE", @{$tp->[thr_ab_once]{$once}});
    # if this is a COME FROM check if this counts as "execution" for the "ONCE"
    # qualifier
    if (defined $once && $cs < $cl) {
	my $op = vec($tp->[thr_bytecode], $cs, 8);
	my $cf = $tp->[thr_come_froms][$op];
	if (defined $cf && defined $$cf) {
	    $$cf & CF_once or $once = undef;
	}
    }
    my @qu = ();
    if (defined $once) {
	# we have three possible things here; "once", "again" and "once and again"
	# "once" changes the abstain state to the opposite of the original
	# "again" restores the original abstain state
	# "once and again" is the quantum version which does both at once
	my $newcount = ++$int->{ab_count};
	my $newab = $fl & stmt_abstain;
	if ($fl & stmt_once) {
	    if ($fl & stmt_again) {
		# record an undo for this... unless we are abstaining from
		# quantum computing
		if (! (exists $tp->[thr_ab_gerund]{&BC_QUA} && $tp->[thr_ab_gerund]{&BC_QUA}[0])) {
		    # we execute the "again" in one place and the "once" in the other;
		    # note that this bit and the other one are now entangled
		    push @qu, [[$newab, $newcount], thr_ab_once, $once];
		    # make sure we do actually add this
		    $count = 0;
		}
	    }
	    $newab = ! $newab;
	}
	# add this if it would make any difference
	if (! exists $tp->[thr_ab_once]{$once}) {
	    $tp->[thr_ab_once]{$once} = [$newab, $newcount];
	    for my $T ($int->{default}, @{$int->{threads}}) {
		exists $T->[thr_ab_once]{$once}
		    or $T->[thr_ab_once]{$once} = $tp->[thr_ab_once]{$once};
	    }
	} elsif ($count != $tp->[thr_ab_once]{$once}[1] || $newab == $tp->[thr_ab_once]{$once}[0]) {
	    @{$tp->[thr_ab_once]{$once}} = ($newab, $newcount);
	}
    }
    if ($ab) {
	# ABSTAINed FROM
	$tp->[thr_trace_mark]->($tp, 'ABSTAIN', $abr);
	$ls || $ll || ($ge && ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund))
	    and _comefrom($int, $tp, $ls, $ll, $ge, $un, $cp);
	return;
    }
    if ($fl & stmt_quantum) {
	$tp->[thr_quantum] = \@qu;
    }
    delete $int->{recompile};
    $tp->[thr_cf_data] = [$ls, $ll, $ge, $un, $cp];
    while ($cs < $cl && $tp->[thr_running]) {
	_run_s($int, $tp, \$cs, $cl);
    }
    # COME FROM data could have changed, for example RESUME or FINISH LECTURE
    # would restore it to what it was at the time of the corresponding NEXT
    # or LEARNS. So reread it now
    ($ls, $ll, $ge, $un, $cp) = @{$tp->[thr_cf_data]};
    if (@qu) {
	# undo the effects of the statement while not undoing it
	my @tc = ();
	for my $T (@{$int->{threads}}) {
	    # do we share anything with this thread?
	    my $share = 0;
	    SHARE:
	    for my $item (@qu) {
		my ($undo, @ptr) = @$item;
		my $ptr = $tp;
		my $spt = $T;
		for my $p (@ptr) {
		    if (! ref $ptr) {
			next SHARE;
		    } elsif (has_type($ptr, 'ARRAY')) {
			$ptr = $ptr->[$p];
			$spt = $spt->[$p];
		    } else {
			$ptr = $ptr->{$p};
			$spt = $spt->{$p};
		    }
		    defined $ptr && defined $spt or next SHARE;
		}
		$ptr == $spt or next SHARE;
		$share = 1;
		last SHARE;
	    }
	    next unless $share;
	    push @tc, $T;
	}
	for my $T (@tc) {
	    my $dt = _dup_thread($int, $T);
	    # do we share anything with this thread?
	    SHARE:
	    for my $item (@qu) {
		my ($undo, @ptr) = @$item;
		my $ptr = $tp;
		my $spt = $T;
		my $dpt = $dt;
		my $lptr = pop @ptr;
		for my $p (@ptr) {
		    if (has_type($ptr, 'ARRAY')) {
			$ptr = $ptr->[$p];
			$spt = $spt->[$p];
			$dpt = $dpt->[$p];
		    } else {
			$ptr = $ptr->{$p};
			$spt = $spt->{$p};
			$dpt = $dpt->{$p};
		    }
		    defined $ptr && defined $spt or next SHARE;
		}
		if (has_type($ptr, 'ARRAY')) {
		    $ptr = $ptr->[$lptr];
		    $spt = $spt->[$lptr];
		    defined $ptr && defined $spt or next SHARE;
		    $dpt->[$lptr] = $undo;
		} else {
		    $ptr = $ptr->{$lptr};
		    $spt = $spt->{$lptr};
		    defined $ptr && defined $spt or next SHARE;
		    $dpt->{$lptr} = $undo;
		}
	    }
	    $T == $tp or next;
	    $ls || $ll || ($ge && ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund))
		and _comefrom($int, $dt, $ls, $ll, $ge, $un, $cp);
	}
    }
    if ($int->{recompile} && ! ($int->{compiling} & IFLAG_norecompile)) {
	$tp->[thr_trace_mark]->($tp, 'RECOMPILE');
	my $num_units = $int->{runobject}->num_units;
	for (my $unit = 0; $unit < $num_units; $unit++) {
	    my ($source, $length) = $int->{runobject}->unit_code($unit);
	    ! defined $source || $source eq '' and next;
	    _compile_unit($int, $source, $length, $unit);
	}
	for my $nt (@{$int->{threads}}) {
	    $nt->[thr_special]
		or $nt->[thr_bytecode] =
		    ($int->{runobject}->unit_code($nt->[thr_current_unit]))[2];
	}
	for my $nt ($int->{default}, @{$int->{threads}}) {
	    @{$nt->[thr_code_cache]} = ();
	    @{$nt->[thr_label_cache]} = ();
	    $nt->[thr_registers][REG_dos][DOS_CF]
		and $nt->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
	}
    }
    delete $int->{recompile};
    $ls || $ll || ($ge && ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund))
	and _comefrom($int, $tp, $ls, $ll, $ge, $un, $cp);
}

sub compile {
    @_ == 2 || @_ == 3 or croak "Usage: INTERPRETER->compile(source [, LAST_ONLY])";
    my ($int, $src, $last_only) = @_;
    my $unit;
    if ($last_only) {
	$unit = $int->{object}->num_units - 1;
    } else {
	$int->{object}->clear_code;
	$unit = 0;
    }
    $int->{runobject} = $int->{object};
    _compile_unit($int, $src, length($src), $unit);
    delete $int->{recompile};
    for my $nt ($int->{default}, @{$int->{threads}}) {
	if ($last_only) {
	    $nt->[thr_code_cache][$unit] = undef;
	    $nt->[thr_label_cache][$unit] = undef;
	} else {
	    @{$nt->[thr_code_cache]} = ();
	    @{$nt->[thr_label_cache]} = ();
	}
	$nt->[thr_registers][REG_dos][DOS_CF]
	    and $nt->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    }
    $int;
}

sub _compile_unit {
    my ($int, $src, $len, $unit) = @_;
    my $ps = $int->{default}[thr_registers][REG_dos][DOS_PS][reg_value];
    my $is = $int->{default}[thr_registers][REG_dos][DOS_IS][reg_value];
    my $ss = $int->{default}[thr_registers][REG_dos][DOS_SS][reg_value];
    my $js = $int->{default}[thr_registers][REG_dos][DOS_JS][reg_value];
    my $parser = $int->{object}->parser(1);
    my @code = $parser->compile_top($ps, $is, $src, 0, $ss, $js, $int->{verbose});
    $int->{runobject}->unit_code($unit, $src, $len, \@code);
}

# scan all currently valid statements in all units and prepare a list of
# statements which could be considered COME FROM of some form and are enabled
# by the current value of %cf; make a list of them in the order the programmer
# may expect the side-effect of these statements to happen
sub _make_comefrom_cache {
    my ($int, $tp) = @_;
    _create_register($int, $tp, REG_dos, DOS_CF);
    my $cfg = $tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund;
    my $num_units = $int->{runobject}->num_units;
    $tp->[thr_registers][REG_dos][DOS_CF][reg_cache] = [];
    for (my $unit = 0; $unit < $num_units; $unit++) {
	if ($tp->[thr_code_cache][$unit]) {
	    # we already have a code cache, use it to create a come from cache
	    my @list;
	    my $code = ($int->{runobject}->unit_code($unit))[2];
	    my $sptr = $tp->[thr_code_cache][$unit];
	    for my $stmt (sort { $a <=> $b } keys %$sptr) {
		my ($xs, $xl, $sl, $fl, $ls, $ll, $ds, $dl, $ge) = @{$sptr->{$stmt}};
		$xl > 0 or next;
		my $op = $tp->[thr_come_froms][$ge];
		defined $op or next; # not currently a COME FROM/NEXT FROM
		$op = $$op;
		defined $op or next; # not currently a COME FROM/NEXT FROM
		$xl += $xs;
		$xs++;
		my ($tn, $tc, $gl);
		if ($op & CF_gerund) {
		    $cfg or next; # not enabled in this thread
		    $gl = [_get_gerunds($tp, \$xs, $xl, 1)];
		    @$gl or $gl = undef;
		} else {
		    if (is_constant(vec($code, $xs, 8))) {
			$tn = BCget($code, \$xs, $xl);
		    } else {
			$tc = substr($code, $xs, $xl - $xs);
		    }
		}
		my $nxt = $op & CF_save_return;
		my $lc;
		$ll and $lc = substr($code, $ls, $ll);
		my $dc;
		$dl and $dc = substr($code, $ds, $dl);
		push @list, [$ls, $lc, $ge, $fl, $ds, $dc, $tn, $tc, $gl, $nxt, $stmt, $sl];
	    }
	    $tp->[thr_registers][REG_dos][DOS_CF][reg_cache][$unit] = \@list;
	} else {
	    # _cache_statements will also create a come from cache
	    _cache_statements($int, $tp, $unit);
	}
    }
}

sub _comefrom {
    my ($int, $tp, $cls, $cll, $cger, $hunit, $hstmt) = @_;
    local $tp->[thr_quantum] = undef;
    my ($clab, $lab_change, $lab_code);
    $cger && ! ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund) and $cger = 0;
    if ($cll) {
	# computed label might have changed since we last calculated it
	my $p = $cls;
	$clab = _get_spot($int, $tp, \$p, $cls + $cll);
	$clab || $cger or return;
	$lab_code = substr($tp->[thr_bytecode], $cls, $cll);
    } elsif ($cls) {
	# constant label might have changed too. Happens
	if (exists $tp->[thr_assign]{$cls}) {
	    $clab = ${$tp->[thr_assign]{$cls}};
	} else {
	    $clab = $cls;
	}
	$clab || $cger or return;
    } elsif (! $cger) {
	return;
    }
    my $prnlab;
    if ($tp->[thr_tracing]) {
	$prnlab = '';
	$clab and $prnlab .= " ($clab)";
	$cger and $prnlab .= ' ' . (bytename($cger) || "#$cger");
	$prnlab =~ s/^ //;
	$tp->[thr_trace_mark]->($tp, 'COMEFROM', $prnlab);
    }
    $tp->[thr_registers][REG_dos][DOS_CF] && $tp->[thr_registers][REG_dos][DOS_CF][reg_cache]
	or _make_comefrom_cache($int, $tp);
    my @cflist;
    my $quantum = 0;
    {
	local $tp->[thr_bytecode];
	for (my $unit = 0; $unit < @{$tp->[thr_registers][REG_dos][DOS_CF][reg_cache]}; $unit++) {
	    my $cfp = $tp->[thr_registers][REG_dos][DOS_CF][reg_cache][$unit];
	    $cfp or next;
	    COME_FROM:
	    for my $cf (@$cfp) {
		my ($ls, $lc, $ge, $fl, $ds, $dc, $tn, $tc, $gl, $nxt, $stmt, $sl) = @$cf;
		# check if this COME FROM is in a road closure; note that we do not enter the diversion
		for my $rc (@{$tp->[thr_diversions]}) {
		    my ($ru, $r0, $r1) = @$rc;
		    $ru == $unit && $r0 <= $stmt && $stmt <= $r1 or next;
		    # yep
		    next COME_FROM;
		}
		# first check if this statement is actually active
		my $count = 0;
		my $ab = $fl & stmt_abstain;
		if ($lc) {
		    $tp->[thr_bytecode] = $lc;
		    my $p = 0;
		    my $lab = _get_spot($int, $tp, \$p, length($lc));
		    $lab_change = 1;
		    $lab && exists $tp->[thr_ab_label]{$lab} && $count < $tp->[thr_ab_label]{$lab}[1]
			and ($ab, $count) = @{$tp->[thr_ab_label]{$lab}};
		} elsif ($ls) {
		    exists $tp->[thr_assign]{$ls} and $ls = ${$tp->[thr_assign]{$ls}};
		    $ls && exists $tp->[thr_ab_label]{$ls} && $count < $tp->[thr_ab_label]{$ls}[1]
			and ($ab, $count) = @{$tp->[thr_ab_label]{$ls}};
		}
		$ge && exists $tp->[thr_ab_gerund]{$ge} && $count < $tp->[thr_ab_gerund]{$ge}[1]
		    and ($ab, $count) = (@{$tp->[thr_ab_gerund]{$ge}});
		my $once;
		if ($fl & (stmt_once | stmt_again)) {
		    $once = "$unit.$stmt";
		    exists $tp->[thr_ab_once]{$once} && $count < $tp->[thr_ab_once]{$once}[1]
			and ($ab, $count) = (@{$tp->[thr_ab_once]{$once}});
		}
		$ab and next COME_FROM;
		# is there a double-oh-seven?
		if ($dc) {
		    $tp->[thr_bytecode] = $dc;
		    my $p = 0;
		    my $dsx = _get_spot($int, $tp, \$p, length($dc));
		    rand(100) >= $dsx and next COME_FROM;
		    $lab_change = 1;
		} elsif ($ds) {
		    rand(100) >= $ds - 1 and next COME_FROM;
		}
		# now check if it points at this label or gerund
		my $do_it = 0;
		if (($cls || $cll) && ($tn || $tc)) {
		    # both the statement label and the tegrat of the COME FROM could have
		    # changed due to side-effect of testing for COME FROMs.
		    if (defined $lab_code) {
			$tp->[thr_bytecode] = $lab_code;
			my $p = 0;
			$clab = _get_spot($int, $tp, \$p, length($lab_code));
		    } elsif ($lab_change) {
			exists $tp->[thr_assign]{$cls} and $clab = ${$tp->[thr_assign]{$cls}};
			$lab_change = 0;
		    }
		    if ($clab) {
			if ($tc) {
			    $tp->[thr_bytecode] = $tc;
			    my $p = 0;
			    my $tlab = _get_spot($int, $tp, \$p, length($tc));
			    $tlab == $clab and $do_it = 1;
			    $lab_change = 1;
			} else {
			    exists $tp->[thr_assign]{$tn} and $tn = ${$tp->[thr_assign]{$tn}};
			    $tn == $clab and $do_it = 1;
			}
		    }
		}
		$cger && ! $do_it && defined $gl && (grep { $_ == $cger } @$gl) and $do_it = 1;
		$do_it or next COME_FROM;
		# OK we have to do this one
		if (defined $once) {
		    push @cflist, [$unit, $stmt, $nxt, $fl, $once, $count];
		} else {
		    push @cflist, [$unit, $stmt, $nxt];
		}
		$quantum ||= $fl & stmt_quantum;
		($fl & stmt_once) && ($fl & stmt_again) and $quantum = 1;
	    }
	}
	# check if this is the tegrat of a system call
	if (($cls || $cll) && $tp->[thr_registers][REG_dos][DOS_OS]) {
	    # naturally, our label could have changed again due to side effects
	    if (defined $lab_code) {
		$tp->[thr_bytecode] = $lab_code;
		my $p = 0;
		$clab = _get_spot($int, $tp, \$p, length($lab_code));
	    } elsif ($lab_change) {
		exists $tp->[thr_assign]{$cls} and $clab = ${$tp->[thr_assign]{$cls}};
	    }
	    my $os = $tp->[thr_registers][REG_dos][DOS_OS][reg_value];
	    if ($os == $clab) {
		# we need to check we are not abstaining from NEXT FROM LABEL
		my $ab = exists $tp->[thr_ab_gerund]{&BC_NXL}
		       ? $tp->[thr_ab_gerund]{&BC_NXL}[0]
		       : 0;
		if (! $ab) {
		    @{$tp->[thr_registers][REG_dos][DOS_OS][reg_belongs]}
			or faint(SP_SYSCALL);
		    # get the last assignment, and make it a spot
		    my $n = $tp->[thr_registers][REG_dos][DOS_OS][reg_belongs][0][1];
		    $tp->[thr_registers][REG_spot][$n] or faint(SP_SYSCALL);
		    unshift @cflist, ['', '', $tp->[thr_registers][REG_spot][$n][reg_value]];
		}
	    }
	}
    }
    @cflist or return;
    # nowadays one can ABSTAIN FROM QUANTUM COMPUTING
    if ($quantum && exists $tp->[thr_ab_gerund]{&BC_QUA}) {
	$quantum = ! $tp->[thr_ab_gerund]{&BC_QUA}[0];
    }
    if (@cflist > 1 && ! ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_threaded)) {
	if (! defined $prnlab) {
	    $prnlab = '';
	    $clab and $prnlab .= " ($clab)";
	    $cger and $prnlab .= ' ' . (bytename($cger) || "#$cger");
	    $prnlab =~ s/^ //;
	}
	if ($quantum) {
	    # we must splat while at the same time not splatting...
	    _splat($int, $tp, splatdescription(SP_COMEFROM, $prnlab));
	    # and then we don't actually take the COME FROMs
	    return;
	}
	faint(SP_COMEFROM, $prnlab);
    }
    # whev! that was a lot of work. Now we have either a single destination,
    # or multiple destinations but threading is enabled, so let's go to all
    # these places at once!
    my $loops = 0;
    while (@cflist) {
	my $cf = shift @cflist;
	my ($unit, $stmt, $nxt, $fl, $once, $count) = @$cf;
	if ($stmt eq '') {
	    # system call - determine system call number
	    exists $int->{syscode}{$nxt}
		or faint(SP_NOSYSCALL, '#' . $nxt);
	    my $c = $int->{syscode}{$nxt};
	    eval {
		# we assume that the syscall implementation does not contain things
		# like NEXT or LEARNS or even RESUME or FINISH LECTURE. If they
		# do, they'll get the wrong bytecode and result in a weird
		# runtime error (undefined subroutine most likely). Don't do that.
		local $tp->[thr_special] = $c;
		local $tp->[thr_bytecode] = $c;
		my $cp = 0;
		while ($cp < length $c) {
		    _run_s($int, $tp, \$cp, length $c);
		}
	    };
	    die $@ if $@;
	    next;
	}
	# not a system call, a normal COME FROM or NEXT FROM
	# do we need to create a new thread?
	my $nt = @cflist || $quantum ? _dup_thread($int, $tp) : $tp;
	# ONCE and/or AGAIN?
	if (defined $once) {
	    # we have three possible things here; "once", "again" and "once and again"
	    # "once" changes the abstain state to the opposite of the original
	    # "again" restores the original abstain state
	    # "once and again" is the quantum version which does both at once
	    my $newcount = ++$int->{ab_count};
	    my $newab = $fl & stmt_abstain;
	    if ($fl & stmt_once) {
		if ($quantum && ($fl & stmt_again)) {
		    # we execute the "again" in one place and the "once" in the other;
		    # note that this bit and the other one are now entangled
		    $tp->[thr_ab_once]{$once} = [$newab, $newcount];
		    # make sure we do actually add this
		    $count = 0;
		}
		$newab = ! $newab;
	    }
	    # add this if it would make any difference
	    if (! exists $nt->[thr_ab_once]{$once}) {
		$nt->[thr_ab_once]{$once} = [$newab, $newcount];
		for my $T ($int->{default}, @{$int->{threads}}) {
		    exists $T->[thr_ab_once]{$once}
			or $T->[thr_ab_once]{$once} = $nt->[thr_ab_once]{$once};
		}
	    } elsif ($count != $nt->[thr_ab_once]{$once}[1] || $newab == $nt->[thr_ab_once]{$once}[0]) {
		@{$nt->[thr_ab_once]{$once}} = ($newab, $newcount);
	    }
	}
	if ($nxt) {
	    # this is a NEXT FROM
	    @{$nt->[thr_next_stack]} >= MAX_NEXT and faint(SP_NEXTING, MAX_NEXT);
	    push @{$nt->[thr_next_stack]}, [
		$nt->[thr_current_unit],
		$nt->[thr_current_pos],
		$nt->[thr_special],
		[@{$nt->[thr_loop_code]}],
		[@{$nt->[thr_in_loop]}],
		[], # otherwise we get a NEXT FROM loop when we RESUME
	    ];
	}
	$nt->[thr_current_unit] = $unit;
	$nt->[thr_current_pos] = $stmt;
	$nt->[thr_bytecode] = ($int->{runobject}->unit_code($nt->[thr_current_unit]))[2];
	$nt->[thr_special] = undef;
	@{$nt->[thr_loop_code]} = ();
	$nt->[thr_cf_data] = [];
	@{$nt->[thr_in_loop]} = ();
	defined $hstmt or next;
	$hunit == $unit or next;
	$hstmt == $stmt or next;
	$loops = 1;
    }
    $loops or return;
    # avoid wasting CPU time on a tight loop - see if there's something useful
    # we can do instead; if something is about to happen wait until then,
    # otherwise wait 0.1 seconds
    $tp->[thr_trickling] || _create_trickling($tp);
    my $when = $tp->[thr_trickling][REG_cho];
    for my $tt (@{$int->{threads}}) {
        $tt->[thr_trickling] || _create_trickling($tt);
        my $tw = $tt->[thr_trickling][REG_cho];
        defined $tw or next;
        ! defined $when || $when > $tw and $when = $tw;
    }
    my $delay = 0.1;
    if ($when) {
	my $now = current_time;
	$now < $when and $delay = ($when - $now)->numify / 1e6;
    }
    if ($int->{server}) {
	$int->{server}->progress($delay);
    } else {
	select undef, undef, undef, $delay;
    }
}

sub _load_opcode ($$$) {
    my ($int, $tp, $byte) = @_;
    # most frequent (hopefully!) case first: we have the opcode and can run it
    defined $tp->[thr_statements][$byte] and return;
    # second most frequent: an extension loaded the opcode after this thread started
    if (defined $statement_opcodes[$byte]) {
	# we can't have done a conveert/swap on this opcode because that would
	# have loaded it, so we know it's just the same as the default
	my $ptr = $statement_opcodes[$byte];
	for my $p ($int->{default}, @{$int->{threads}}) {
	    $tp->[thr_statements][$byte] ||= \$ptr;
	}
	my $cf = $come_froms[$byte];
	if (defined $cf) {
	    # it's a new COME FROM / NEXT FROM, so we need to record it and
	    # also need to regenerate the COME FROM cache
	    for my $p ($int->{default}, @{$int->{threads}}) {
		$tp->[thr_come_froms][$byte] ||= \$cf;
	    }
	    $tp->[thr_registers][REG_dos][DOS_CF]
		and $tp->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
	}
	return;
    }
    # we don't have this opcode, try to figure out why we don't have it:
    # if it's not a statement, produce an SP_INVALID
    $byte >= NUM_OPCODES and faint(SP_INVALID, $byte, 'statement');
    my (undef, undef, $type) = bytedecode($byte);
    defined $type && $type eq 'S' or faint(SP_INVALID, $byte, 'statement');
    # it's supposed to be a valid statement, but we haven't implemented it?
    # or maybe we need to load an extension we haven't?
    faint(SP_TODO, $byte);
}

# run bytecode in the assumption it's a statement
sub _run_s {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_FALL_OFF) if $$cp >= $ep;
    my $byte = vec($tp->[thr_bytecode], $$cp++, 8);
    $tp->[thr_trace_item]->($byte, 0);
    faint(SP_INVALID, $byte, 'statement')
	if ! defined $statement_opcodes[$byte];
    _load_opcode($int, $tp, $byte);
    $tp->[thr_opcode] = $byte;
    my $ptr = ${$tp->[thr_statements][$byte]};
    $ptr->($int, $tp, $cp, $ep);
}

# run bytecode in the assumption it's an expression and is not being assigned to
sub _run_e {
    my ($int, $tp, $cp, $ep) = @_;
    my $byte = vec($tp->[thr_bytecode], $$cp++, 8);
    # we used to have "if (is_constant($byte))" and then just call BCget for any
    # constant; this turns out to be slow and unfolding the condition results
    # in a noticeable time difference; and of course we use constants a lot in
    # any normal program: register numbers, labels, actual numbers
    if ($byte >= NUM_OPCODES) {
	# 1-byte constant (which may be variable)
	$byte -= NUM_OPCODES;
	if ($tp->[thr_tracing]) {
	    if (exists $tp->[thr_assign]{$byte}) {
		my $ov = $byte;
		$byte = ${$tp->[thr_assign]{$byte}};
		$tp->[thr_trace_item]->("#$ov->$byte", 1, $byte);
	    } else {
		$tp->[thr_trace_item]->("#" . $byte, 1, $byte);
	    }
	} else {
	    exists $tp->[thr_assign]{$byte}
		and $byte = ${$tp->[thr_assign]{$byte}};
	}
	return ($byte, REG_spot);
    } elsif ($byte == BC_HSN) {
	# half spot constant (which may be variable)
	my $val;
	if ($tp->[thr_tracing]) {
	    $$cp--;
	    my $ocp = $$cp;
	    $val = BCget($tp->[thr_bytecode], $cp, $ep);
	    if (exists $tp->[thr_assign]{$val}) {
		my $ov = $val;
		$val = ${$tp->[thr_assign]{$val}};
		$tp->[thr_trace_item]->("#$ov->$val", 1,
					unpack('C*', substr($tp->[thr_bytecode],
							    $ocp, $$cp - $ocp)));
	    } else {
		$tp->[thr_trace_item]->("#" . $val, 1,
					unpack('C*', substr($tp->[thr_bytecode],
							    $ocp, $$cp - $ocp)));
	    }
	} else {
	    faint(SP_FALL_OFF) if $$cp >= $ep;
	    $val = vec($tp->[thr_bytecode], $$cp++, 8);
	    exists $tp->[thr_assign]{$val}
		and $val = ${$tp->[thr_assign]{$val}};
	}
	return ($val, REG_spot);
    } elsif ($byte == BC_OSN) {
	# one spot constant (which may be variable)
	$$cp--;
	my $val;
	if ($tp->[thr_tracing]) {
	    my $ocp = $$cp;
	    $val = BCget($tp->[thr_bytecode], $cp, $ep);
	    if (exists $tp->[thr_assign]{$val}) {
		my $ov = $val;
		$val = ${$tp->[thr_assign]{$val}};
		$tp->[thr_trace_item]->("#$ov->$val", 1,
					unpack('C*', substr($tp->[thr_bytecode],
							    $ocp, $$cp - $ocp)));
	    } else {
		$tp->[thr_trace_item]->("#" . $val, 1,
					unpack('C*', substr($tp->[thr_bytecode],
							    $ocp, $$cp - $ocp)));
	    }
	} else {
	    $val = BCget($tp->[thr_bytecode], $cp, $ep);
	    exists $tp->[thr_assign]{$val}
		and $val = ${$tp->[thr_assign]{$val}};
	}
	return ($val, REG_spot);
    } else {
	$tp->[thr_trace_item]->($byte, 0);
	if (! defined $evaluable_opcodes[$byte]) {
	    faint(SP_FALL_OFF) if $$cp > $ep;
	    faint(SP_INVALID, $byte, 'expression');
	}
	$tp->[thr_opcode] = $byte;
	return &{$evaluable_opcodes[$byte]}($int, $tp, $cp, $ep);
    }
}

# run bytecode in the assumption it's assigning to an expression; the extra arguments
# (compared to _run_e()) are the value to assign and its type (a REG_* constant)
sub _run_a {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    my $byte = vec($tp->[thr_bytecode], $$cp++, 8);
    # assigning happens less than evaluating expressions but we do the same unfolding
    # of is_constant as _run_e because it helps a bit, and the code is the same so
    # it's just a bit of copy and paste (minus the overloading checks which are
    # not relevant here)
    if ($byte >= NUM_OPCODES) {
	# 1-byte constant (which may be variable)
	$byte -= NUM_OPCODES;
	$tp->[thr_trace_item]->("#" . $byte, 1, $byte);
	_assign_constant($int, $tp, $byte, $assign, $atype);
    } elsif ($byte == BC_HSN) {
	# half spot constant (which may be variable)
	my $val;
	if ($tp->[thr_tracing]) {
	    $$cp--;
	    my $ocp = $$cp;
	    $val = BCget($tp->[thr_bytecode], $cp, $ep);
	    $tp->[thr_trace_item]->("#" . $val, 1,
				    unpack('C*', substr($tp->[thr_bytecode],
							$ocp, $$cp - $ocp)));
	} else {
	    faint(SP_FALL_OFF) if $$cp >= $ep;
	    $val = vec($tp->[thr_bytecode], $$cp++, 8);
	}
	_assign_constant($int, $tp, $val, $assign, $atype);
    } elsif ($byte == BC_OSN) {
	# one spot constant (which may be variable)
	$$cp--;
	my $val;
	if ($tp->[thr_tracing]) {
	    my $ocp = $$cp;
	    $val = BCget($tp->[thr_bytecode], $cp, $ep);
	    $tp->[thr_trace_item]->("#" . $val, 1,
				    unpack('C*', substr($tp->[thr_bytecode],
							$ocp, $$cp - $ocp)));
	} else {
	    $val = BCget($tp->[thr_bytecode], $cp, $ep);
	}
	_assign_constant($int, $tp, $val, $assign, $atype);
    } else {
	$tp->[thr_trace_item]->($byte, 0);
	if (! defined $assignable_opcodes[$byte]) {
	    faint(SP_FALL_OFF) if $$cp > $ep;
	    faint(SP_INVALID, $byte, 'assignable expression');
	}
	$tp->[thr_opcode] = $byte;
	&{$assignable_opcodes[$byte]}($int, $tp, $cp, $ep, $assign, $atype);
    }
}

# run bytecode in the assumption it's a register and return its name
sub _run_r {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    my $byte = vec($tp->[thr_bytecode], $$cp++, 8);
    $tp->[thr_trace_item]->($byte, 0);
    if (! defined $regname_opcodes[$byte]) {
	faint(SP_FALL_OFF) if $$cp > $ep;
	faint(SP_INVALID, $byte, 'register');
    }
    $tp->[thr_opcode] = $byte;
    return &{$regname_opcodes[$byte]}($int, $tp, $cp, $ep, $no_overload);
}

sub _create_register {
    # create/separate register if necessary
    my ($int, $tp, $type, $number, $undo) = @_;
    if (! $tp->[thr_registers][$type][$number]) {
	my ($value, $assign, $print, $dtype) = reg_create($type, $number, $int->{object});
	my @newreg;
	$newreg[reg_value] = $value;
	$newreg[reg_assign] = $assign;
	$newreg[reg_print] = $print;
	$newreg[reg_type] = $dtype;
	$newreg[reg_ignore] = 0;
	$newreg[reg_default] = 0;
	my @newstash = ();
	for my $t (@{$int->{threads}}, $int->{default}, $tp) {
	    $t->[thr_registers][$type][$number] = \@newreg
		if ! $t->[thr_registers][$type][$number];
	    $t->[thr_stash][$type][$number] = \@newstash
		if ! $t->[thr_stash][$type][$number];
	}
    }
    if ($tp->[thr_quantum]) {
	$undo ||= \&_deep_copy;
	push @{$tp->[thr_quantum]},
	    [$undo->($tp->[thr_registers][$type][$number]), thr_registers, $type, $number],
	    [_deep_copy($tp->[thr_stash][$type][$number]), thr_stash, $type, $number];
    }
}

sub _stash_register {
    my ($int, $tp, $type, $number) = @_;
    _create_register($int, $tp, $type, $number);
    push @{$tp->[thr_stash][$type][$number]}, _deep_copy($tp->[thr_registers][$type][$number]);
}

sub _retrieve_register {
    my ($int, $tp, $type, $number) = @_;
    _create_register($int, $tp, $type, $number);
    $tp->[thr_stash][$type][$number] && @{$tp->[thr_stash][$type][$number]}
	or faint(SP_HIDDEN, reg_decode($type, $number));
    my $pop = pop @{$tp->[thr_stash][$type][$number]};
    # we must copy the hash rather than the ref otherwise any other threads
    # sharing this register don't get the retrieve
    @{$tp->[thr_registers][$type][$number]} = @$pop
	if ! $tp->[thr_registers][$type][$number][reg_ignore] ||
	   $tp->[thr_registers][REG_dos][DOS_RM][reg_value];
}

sub _make_register_belong ($$$$$$) {
    my ($int, $tp, $btype, $bnumber, $otype, $onumber) = @_;
    _create_register($int, $tp, $btype, $bnumber);
    $tp->[thr_registers][$btype][$bnumber][reg_default] = 0;
    unshift @{$tp->[thr_registers][$btype][$bnumber][reg_belongs]}, [$otype, $onumber];
}

sub _no_longer_belong ($$$$$$) {
    my ($int, $tp, $btype, $bnumber, $otype, $onumber) = @_;
    _create_register($int, $tp, $btype, $bnumber);
    $tp->[thr_registers][$btype][$bnumber][reg_belongs]
	&& @{$tp->[thr_registers][$btype][$bnumber][reg_belongs]}
	    or faint(SP_INDEPENDENT, reg_decode($btype, $bnumber));
    my @no = ();
    my $found = 0;
    for my $o (@{$tp->[thr_registers][$btype][$bnumber][reg_belongs]}) {
	if ($found || $o->[0] != $otype || $o->[1] != $onumber) {
	    push @no, $o;
	} else {
	    $found = 1;
	}
    }
    $found or faint(SP_NOBELONG, reg_decode($btype, $bnumber), reg_decode($otype, $onumber));
    $tp->[thr_registers][$btype][$bnumber][reg_belongs] = \@no;
}

sub _get_regname {
    my ($int, $tp, $type, $cp, $ep, $no_overload) = @_;
    my $num = _get_spot($int, $tp, $cp, $ep);
    # if the register is not overloaded, then just return its name; if it does
    # not exist it's obviously not overloaded and here we don't actually create
    # it, but the caller may decide to do that
    $tp->[thr_registers][$type][$num] && $tp->[thr_registers][$type][$num][reg_overload]{''}
	or return ($type, $num);
    # whole register is overloaded, get the overload code and try to interpret
    # it as a register; make sure we avoid overloading loops
    $no_overload and return ($type, $num);
    my $code = $tp->[thr_registers][$type][$num][reg_overload]{''};
    local $tp->[thr_registers][$type][$num][reg_overload]{''} = undef;
    local $tp->[thr_bytecode] = $code;
    local $tp->[thr_special] = $code;
    my $x = 0;
    _make_register_belong($int, $tp, REG_whp, 0, $type, $num);
    ($type, $num) = eval { _run_r($int, $tp, \$x, length $code) };
    shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
    $@ and die $@;
    ($type, $num);
}

sub _get_register {
    my ($int, $tp, $type, $cp, $ep) = @_;
    my $num = _get_spot($int, $tp, $cp, $ep);
    _get_register_2($int, $tp, $type, $num);
}

sub _get_register_2 {
    my ($int, $tp, $type, $number) = @_;
    # if the register is not overloaded, then just return its value; if it does
    # not exist it's obviously not overloaded but we create it so it gets its
    # default value
    if (! $tp->[thr_registers][$type][$number] || ! $tp->[thr_registers][$type][$number][reg_overload]{''}) {
	$type == REG_cho and faint(SP_ISSPECIAL);
	_create_register($int, $tp, $type, $number);
	my $value = $tp->[thr_registers][$type][$number][reg_value];
	$type == REG_dos and $type = REG_spot;
	$type == REG_shf and $type = REG_tail;
	return ($value, $type);
    }
    # whole register is overloaded, get the overload code and try to interpret
    # it as an expression; make sure we avoid overloading loops
    my $code = $tp->[thr_registers][$type][$number][reg_overload]{''};
    local $tp->[thr_registers][$type][$number][reg_overload]{''} = undef;
    local $tp->[thr_bytecode] = $code;
    local $tp->[thr_special] = $code;
    my $x = 0;
    _make_register_belong($int, $tp, REG_whp, 0, $type, $number);
    my $value;
    ($value, $type) = eval { _run_e($int, $tp, \$x, length $code) };
    shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
    $@ and die $@;
    ($value, $type);
}

sub _set_register {
    my ($int, $tp, $type, $cp, $ep, $assign, $atype) = @_;
    my $num = _get_spot($int, $tp, $cp, $ep);
    _set_register_2($int, $tp, $type, $num, $assign, $atype);
}

sub _set_register_2 {
    my ($int, $tp, $type, $number, $assign, $atype) = @_;
    # if the register is overloaded, we assign to the overload expression instead
    if ($tp->[thr_registers][$type][$number] && $tp->[thr_registers][$type][$number][reg_overload]{''}) {
	my $code = $tp->[thr_registers][$type][$number][reg_overload]{''};
	local $tp->[thr_registers][$type][$number][reg_overload]{''} = undef;
	local $tp->[thr_bytecode] = $code;
	local $tp->[thr_special] = $code;
	my $x = 0;
	_make_register_belong($int, $tp, REG_whp, 0, $type, $number);
	eval { _run_a($int, $tp, \$x, length $code, $assign, $atype) };
	shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
	$@ and die $@;
	return;
    }
    _set_register_3($int, $tp, $type, $number, $assign, $atype);
}

sub _set_register_3 {
    my ($int, $tp, $type, $number, $assign, $atype) = @_;
    $type == REG_cho and faint(SP_ISSPECIAL);
    # not overloaded, now check if it may have some side effects
    if ($type == REG_dos && exists $causes_recompile{$number} && $tp->[thr_quantum]) {
	# can't do that (yet), sorry
	faint(SP_QUANTUM, "Assignment to grammar registers");
    }
    # create it now so we can refer to it later
    _create_register($int, $tp, $type, $number);
    my $rp = $tp->[thr_registers][$type][$number];
    # special treatment for system call interface
    if ($tp->[thr_registers][REG_dos][DOS_OS] && ! ($type == REG_dos && $number == DOS_OS)) {
	@{$tp->[thr_registers][REG_dos][DOS_OS][reg_belongs]} = [$type, $number];
    }
    # check if the register is ignored
    $rp->[reg_ignore] and return;
    # any tricking down?
    if ($rp->[reg_trickle] && @{$rp->[reg_trickle]}) {
	# check that we are not ABSTAINed FROM TRICKLING DOWN
	if (! exists $tp->[thr_ab_gerund]{&BC_TRD} || ! $tp->[thr_ab_gerund]{&BC_TRD}[0]) {
	    $tp->[thr_trickling] || _create_trickling($tp);
	    my $now = current_time();
	    my $first = $tp->[thr_trickling][REG_cho];
	    for my $down (@{$rp->[reg_trickle]}) {
		my ($dtype, $dnumber, $delay) = @$down;
		$delay < 1 and $delay = 1;
		_create_register($int, $tp, $dtype, $dnumber);
		my $dp = $tp->[thr_registers][$dtype][$dnumber];
		my $when = $now + $delay * 1000;
		$dp->[reg_pending] ||= [];
		# we need to install it in the right spot
		my $pending = $dp->[reg_pending];
		my $p = 0;
		$p++ while ($p < @$pending && $pending->[$p][3] <= $when);
		splice(@$pending, $p, 0, [$assign, $atype, $when]);
		$tp->[thr_trickling][$dtype]{$dnumber} = 0;
		defined $first && $first <= $when
		    or $first = $when;
	    }
	    $tp->[thr_trickling][REG_cho] = $first;
	}
    }
    my $oldval;
    $rp->[reg_default] = 0;
    my $check_change = $type == REG_dos && exists $check_changes{$number};
    $check_change and $oldval = $rp->[reg_value];
    if ($type == REG_spot || $type == REG_twospot) {
	_check_number($atype);
	$type == REG_spot && $assign > 0xffff
	    and faint(SP_SPOTS, $assign, 'one spot');
	$rp->[reg_value] = $assign;
	return;
    }
    if ($type == REG_tail || $type == REG_hybrid) {
	# dimension array
	$atype == REG_whp and faint(SP_ISCLASS);
	$atype == REG_tail || $atype == REG_hybrid || $atype == REG_spot || $atype == REG_twospot
	    or faint(SP_ARRAY, "Value assigned cannot be interpreted as dimension");
	$rp->[reg_value] = make_array($assign);
	return;
    }
    if ($type == REG_whp) {
	ref $assign or faint(SP_ISCLASS);
	ref $assign eq 'HASH' # && exists $assign->{filehandle}
	    and $assign = $assign->{filehandle};
	if ($assign) {
	    $assign->isa('Language::INTERCAL::GenericIO')
		or faint(SP_ISCLASS);
	} else {
	    $assign = undef;
	}
	$rp->[reg_value]{filehandle} = $assign;
	$number == WHP_TRFH and _set_tracing($int);
	return;
    }
    $type == REG_dos || $type == REG_shf or faint(SP_ISSPECIAL);
    $rp->[reg_value] = $rp->[reg_assign]->($int->{runobject}, $assign, $atype);
    $check_change or return;
    my $newval = $rp->[reg_value];
    $oldval == $newval and return;
    if ($number == DOS_CF) {
	# changes in the threading bit don't matter to the cache; changes to the
	# gerund bits on the other hand require to rebuild it; if we do rebuild
	# the come from cache, we can keep label and statement caches as they
	# are not affected by %CF
	($oldval & CF_gerund) == ($newval & CF_gerund) and return;
	$tp->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    } elsif ($number == DOS_TM) {
	_set_tracing($int);
    } elsif (exists $causes_recompile{$number}) {
	_has_source($int, $tp)
	    or faint(SP_CONTEXT, 'Frozen object cannot change ' . reg_decode($type, $number));
	$int->{recompile} = 1;
    }
}

sub _create_trickling {
    my ($tp) = @_;
    $tp->[thr_trickling] = [];
    my $rp = $tp->[thr_registers];
    my $first = undef;
    for (my $type = 0; $type < @{$tp->[thr_registers]}; $type++) {
	$rp->[$type] or next;
	for (my $number = 0; $number < @{$rp->[$type]}; $number++) {
	    $rp->[$type][$number] or next;
	    $rp->[$type][$number][reg_pending] or next;
	    @{$rp->[$type][$number][reg_pending]} or next;
	    for my $pending (@{$rp->[$type][$number][reg_pending]}) {
		my ($assign, $atype, $when) = @$pending;
		defined $first && $first <= $when
		    or $first = $when;
	    }
	    $tp->[thr_trickling][$type]{$number} = 0;
	}
    }
    $tp->[thr_trickling][REG_cho] = $first;
}

sub _has_source {
    my ($int, $tp) = @_;
    my $num_units = $int->{runobject}->num_units;
    for (my $unit = 0; $unit < $num_units; $unit++) {
	my ($source) = $int->{runobject}->unit_code($unit);
	$source ne '' and return 1;
	# even if we have sources for some units, if we don't have them
	# for the current unit we can't do a CREATE
	defined $tp && $unit == $tp->[thr_current_unit] and return 0;
    }
    return 0;
}

sub _r_SPO {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_spot, $cp, $ep, $no_overload);
}

sub _e_SPO {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_spot, $cp, $ep);
}

sub _a_SPO {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_spot, $cp, $ep, $assign, $atype);
}

sub _r_TSP {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_twospot, $cp, $ep, $no_overload);
}

sub _e_TSP {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_twospot, $cp, $ep);
}

sub _a_TSP {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_twospot, $cp, $ep, $assign, $atype);
}

sub _r_TAI {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_tail, $cp, $ep, $no_overload);
}

sub _e_TAI {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_tail, $cp, $ep);
}

sub _a_TAI {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_tail, $cp, $ep, $assign, $atype);
}

sub _r_HYB {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_hybrid, $cp, $ep, $no_overload);
}

sub _e_HYB {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_hybrid, $cp, $ep);
}

sub _a_HYB {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_hybrid, $cp, $ep, $assign, $atype);
}

sub _r_WHP {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_whp, $cp, $ep, $no_overload);
}

sub _e_WHP {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_whp, $cp, $ep);
}

sub _a_WHP {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_whp, $cp, $ep, $assign, $atype);
}

sub _r_DOS {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_dos, $cp, $ep, $no_overload);
}

sub _e_DOS {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_dos, $cp, $ep);
}

sub _a_DOS {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_dos, $cp, $ep, $assign, $atype);
}

sub _r_SHF {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_shf, $cp, $ep, $no_overload);
}

sub _e_SHF {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_shf, $cp, $ep);
}

sub _a_SHF {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_shf, $cp, $ep, $assign, $atype);
}

sub _r_CHO {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    _get_regname($int, $tp, REG_cho, $cp, $ep, $no_overload);
}

sub _e_CHO {
    my ($int, $tp, $cp, $ep) = @_;
    _get_register($int, $tp, REG_cho, $cp, $ep);
}

sub _a_CHO {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _set_register($int, $tp, REG_cho, $cp, $ep, $assign, $atype);
}

sub _r_TYP {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    # this needs to get a register name, extract the type, and then continue
    # with _get_regname
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _get_regname($int, $tp, $type, $cp, $ep, $no_overload);
}

sub _e_TYP {
    my ($int, $tp, $cp, $ep) = @_;
    # this needs to get a register name, extract the type, and then continue
    # with _get_register
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _get_register($int, $tp, $type, $cp, $ep);
}

sub _a_TYP {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    # this needs to get a register name, extract the type, and then continue
    # with _set_register to do the real assignment
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _set_register($int, $tp, $type, $cp, $ep, $assign, $atype);
}

sub _e_NUM {
    my ($int, $tp, $cp, $ep) = @_;
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    ($number, REG_spot);
}

sub _a_NUM {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    # assigning to a register number is equivalent to assigning to constant
    _assign_constant($int, $tp, $number, $assign, $atype);
}

sub _assign_constant {
    my ($int, $tp, $val, $assign, $atype) = @_;
    _check_number($atype);
    $assign > 0xffff and faint(SP_SPOTS, $assign, 'assign to constant');
    $tp->[thr_trace_item]->("[#$val <- #$assign]", 1);
    if (! exists $tp->[thr_assign]{$val}) {
	for my $t (@{$int->{threads}}, $int->{default}) {
	    $t->[thr_assign]{$val} = \$assign;
	}
    }
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	    [_deep_copy($tp->[thr_assign]{$val}), thr_assign, $val];
    }
    ${$tp->[thr_assign]{$val}} = $assign;
}

sub _r_SUB {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    # used as register name, a subscript is only valid if it refers to an overloaded
    # array element; so we get the element and then check for overloading, and if
    # found we try to run it as a register; note that the whole register could be
    # overloaded, as well as a single element; the call to _run_r handles the
    # overloading on the whole register, we check the element
    $no_overload and faint(SP_NOARRAY);
    my $sub = _get_spot($int, $tp, $cp, $ep);
    my $S = join(' ', @{_maybe_subscripts($int, $tp, $cp, $ep, $sub)});
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    $tp->[thr_registers][$type][$number] or faint(SP_NODIM);
    my $code = $tp->[thr_registers][$type][$number][reg_overload]{$S};
    $code or faint(SP_NODIM);
    # make sure we avoid an overload loop
    local $tp->[thr_registers][$type][$number][reg_overload]{$S} = undef;
    local $tp->[thr_bytecode] = $code;
    local $tp->[thr_special] = $code;
    my $x = 0;
    _make_register_belong($int, $tp, REG_whp, 0, $type, $number);
    ($type, $number) = eval { _run_r($int, $tp, \$x, length $code) };
    shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
    $@ and die $@;
    ($type, $number);
}

sub _e_SUB {
    my ($int, $tp, $cp, $ep) = @_;
    my $sub = _get_spot($int, $tp, $cp, $ep);
    # get any remaining subscripts, add $sub to the end of it, then get a register
    # and return its value
    my $S = _maybe_subscripts($int, $tp, $cp, $ep, $sub);
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _create_register($int, $tp, $type, $number);
    my $JS = join(' ', @$S);
    my $code = $tp->[thr_registers][$type][$number][reg_overload]{$JS};
    if ($code) {
	# the element is overloaded, return the value of the overload expression
	local $tp->[thr_registers][$type][$number][reg_overload]{$JS} = undef;
	local $tp->[thr_bytecode] = $code;
	local $tp->[thr_special] = $code;
	my $x = 0;
	_make_register_belong($int, $tp, REG_whp, 0, $type, $number);
	my ($value, $type) = eval { _run_e($int, $tp, \$x, length $code) };
	shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
	$@ and die $@;
	return ($value, $type);
    } else {
	# no overload, just get the array element
	$type == REG_tail || $type == REG_hybrid || $type == REG_whp || $type == REG_shf
	    or faint(SP_NOARRAY);
	$tp->[thr_registers][$type][$number] or faint(SP_NODIM);
	$tp->[thr_registers][$type][$number][reg_value] or faint(SP_NODIM);
	my $e;
	if ($type == REG_whp) {
	    @$S == 1 or faint(SP_SUBSCRIPT, scalar(@$S) . ' items', 'filehandles take 1 subscript');
	    $e = $tp->[thr_registers][$type][$number][reg_value]{$S->[0]} or faint(SP_CLASS, "#$S->[0]");
	} else {
	    @{$tp->[thr_registers][$type][$number][reg_value]} or faint(SP_NODIM);
	    $e = get_element($tp->[thr_registers][$type][$number][reg_value], @$S);
	}
	return ($e, $type == REG_hybrid ? REG_twospot : REG_spot);
    }
}

sub _a_SUB {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    my $sub = _get_spot($int, $tp, $cp, $ep);
    # get any remaining subscripts, add $sub to the end of it, then get a register
    # and return its value
    my $S = _maybe_subscripts($int, $tp, $cp, $ep, $sub);
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _create_register($int, $tp, $type, $number);
    my $JS = join(' ', @$S);
    my $code = $tp->[thr_registers][$type][$number][reg_overload]{$JS};
    if ($code) {
	# the element is overloaded, assign to the overload expression
	local $tp->[thr_registers][$type][$number][reg_overload]{$JS} = undef;
	local $tp->[thr_bytecode] = $code;
	local $tp->[thr_special] = $code;
	my $x = 0;
	_make_register_belong($int, $tp, REG_whp, 0, $type, $number);
	eval { _run_a($int, $tp, \$x, length $code, $assign, $atype) };
	shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
	$@ and die $@;
	return;
    } else {
	# no overload, and we know there cannot be side effects on array elements,
	# so just assign
	_check_number($atype);
	$type == REG_tail || $type == REG_hybrid || $type == REG_whp || $type == REG_shf
	    or faint(SP_NOARRAY);
	$tp->[thr_registers][$type][$number] or faint(SP_NODIM);
	$tp->[thr_registers][$type][$number][reg_value] or faint(SP_NODIM);
	@{$tp->[thr_registers][$type][$number][reg_value]} or faint(SP_NODIM);
	$type == REG_hybrid || $atype == REG_spot || $assign < 0x10000
	    or faint(SP_SPOTS, $assign, 'one spot');
	if ($type == REG_whp) {
	    @$S == 1 or faint(SP_SUBSCRIPT, scalar(@$S) . ' items', 'filehandles take 1 subscript');
	    $assign < 1000 and faint(SP_EARLY, $assign);
	    $assign > 0xffff and faint(SP_SPOTS, $assign, 'label');
	    $tp->[thr_registers][$type][$number][reg_value]{$S->[0]} = $assign;
	} else {
	    set_element($tp->[thr_registers][$type][$number][reg_value], $type, $assign, $atype, @$S);
	}
    }
}

sub _maybe_subscripts {
    my ($int, $tp, $cp, $ep, @subs) = @_;
    # we need to execute the equivalent of _e_SUB here so that we get the subscripts
    # without trying to access the register
    $$cp >= $ep and return @subs;
    my $byte = vec($tp->[thr_bytecode], $$cp, 8);
    while ($byte == BC_SUB) {
	$tp->[thr_trace_item]->($byte, 0);
	$$cp++;
	unshift @subs, _get_spot($int, $tp, $cp, $ep);
	$$cp >= $ep and return @subs;
	$byte = vec($tp->[thr_bytecode], $$cp, 8);
    }
    \@subs;
}

sub _r_BLM {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    my $fo = _get_spot($int, $tp, $cp, $ep);
    # get rest of belonging path
    my $O = _maybe_belongs($int, $tp, $cp, $ep, $fo);
    # now get the register we start with
    my ($type, $number) = _run_r($int, $tp, $cp, $ep, $no_overload);
    for my $F (@$O) {
	$tp->[thr_registers][$type][$number]
	    && $tp->[thr_registers][$type][$number][reg_belongs]
	    && @{$tp->[thr_registers][$type][$number][reg_belongs]}
		or faint(SP_INDEPENDENT, reg_decode($type, $number));
	$F > 0 or faint(SP_INVBELONG, $F);
	$F <= @{$tp->[thr_registers][$type][$number][reg_belongs]}
	    or faint(SP_NOSUCHBELONG, reg_decode($type, $number), $F,
		     scalar @{$tp->[thr_registers][$type][$number][reg_belongs]});
	($type, $number) = @{$tp->[thr_registers][$type][$number][reg_belongs][$F - 1]};
    }
    $tp->[thr_registers][$type][$number] && $tp->[thr_registers][$type][$number][reg_overload]{''}
	or return ($type, $number);
    # whole register is overloaded, get the overload code and try to interpret
    # it as a register; make sure we avoid overloading loops
    $no_overload and return ($type, $number);
    my $code = $tp->[thr_registers][$type][$number][reg_overload]{''};
    local $tp->[thr_registers][$type][$number][reg_overload]{''} = undef;
    local $tp->[thr_bytecode] = $code;
    local $tp->[thr_special] = $code;
    _make_register_belong($int, $tp, REG_whp, 0, $type, $number);
    ($type, $number) = eval { my $x = 0; _run_r($int, $tp, \$x, length $code) };
    shift @{$tp->[thr_registers][REG_whp][0][reg_belongs]};
    $@ and die $@;
    ($type, $number);
}

sub _e_BLM {
    my ($int, $tp, $cp, $ep) = @_;
    # use _r_BLM to get the real final register
    my ($type, $number) = _r_BLM($int, $tp, $cp, $ep, 1);
    _get_register_2($int, $tp, $type, $number);
}

sub _a_BLM {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    # use _r_BLM to get the real final register
    my ($type, $number) = _r_BLM($int, $tp, $cp, $ep, 1);
    _set_register_2($int, $tp, $type, $number, $assign, $atype);
}

sub _maybe_belongs {
    my ($int, $tp, $cp, $ep, @belongs) = @_;
    $$cp >= $ep and return @belongs;
    my $byte = vec($tp->[thr_bytecode], $$cp, 8);
    while ($byte == BC_BLM) {
	$tp->[thr_trace_item]->($byte, 0);
	$$cp++;
	unshift @belongs, _get_spot($int, $tp, $cp, $ep);
	$$cp >= $ep and return @belongs;
	$byte = vec($tp->[thr_bytecode], $$cp, 8);
    }
    \@belongs;
}

sub _r_OVR {
    my ($int, $tp, $cp, $ep, $no_overload) = @_;
    # using the overload register means first getting the real register bypassing
    # any overloading, then setting up new overloading but returning the original
    # value; array elements are not allowed here as they can't be used as register
    # names, even if they are overloaded to a simple register, we can't return
    # the original value as a name
    my $expr = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify register for " .
		 bytename($tp->[thr_opcode]));
    my $elen = $$cp - $expr;
    my ($type, $number) = _run_r($int, $tp, $cp, $ep, 1);
    _add_overload($int, $tp, $type, $number, $expr, $elen, '');
    ($type, $number);
}

sub _e_OVR {
    my ($int, $tp, $cp, $ep) = @_;
    # evaluating an overload register means first getting the real register bypassing
    # any overloading, then setting up new overloading but returning the original
    # value; we do that by getting a register name (and subscripts so we can overload
    # array elements); removing any existing overload to get at the real value,
    # then setting up new overloading
    my $expr = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify register for " .
		 bytename($tp->[thr_opcode]));
    my $elen = $$cp - $expr;
    my $S = _maybe_subscripts($int, $tp, $cp, $ep);
    my $JS = join(' ', @$S);
    my ($type, $number) = _run_r($int, $tp, $cp, $ep, 1);
    _remove_overload($int, $tp, $type, $number, $JS);
    my $value = $tp->[thr_registers][$type][$number][reg_value];
    @$S and $value = get_element($value, @$S);
    _add_overload($int, $tp, $type, $number, $expr, $elen, $JS);
    $type == REG_dos and $type = REG_spot;
    $type == REG_shf and $type = REG_tail;
    ($value, $type);
}

sub _a_OVR {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    # evaluating an overload register means first assigning to the real register
    # bypassing any overloading, then setting up new overloading; we do that by
    # getting a register name (and subscripts so we can overload array elements);
    # removing any existing overload to do the assignment, then setting up new overloading
    my $expr = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify register for " .
		 bytename($tp->[thr_opcode]));
    my $elen = $$cp - $expr;
    my $S = _maybe_subscripts($int, $tp, $cp, $ep);
    my $JS = join(' ', @$S);
    my ($type, $number) = _run_r($int, $tp, $cp, $ep, 1);
    _remove_overload($int, $tp, $type, $number, $JS);
    if (@$S) {
	# assigning to an element will not have other side effects
	set_element($tp->[thr_registers][$type][$number][reg_value], $assign, $atype, @$S);
    } else {
	# call _set_register_3 in case assigning to this has other side effects
	_set_register_3($int, $tp, $type, $number, $assign, $atype);
    }
    _add_overload($int, $tp, $type, $number, $expr, $elen, $JS);
}

sub _remove_overload {
    my ($int, $tp, $type, $number, $JS) = @_;
    _create_register($int, $tp, $type, $number);
    delete $tp->[thr_registers][$type][$number][reg_overload]{$JS};
}

sub _add_overload {
    my ($int, $tp, $type, $number, $expr, $elen, $JS) = @_;
    # if the overload code is the register itself, just remove any
    # existing overload
    my $code = substr($tp->[thr_bytecode], $expr, $elen);
    if ($code eq pack('C*', reg_code2($type, $number)) || $code eq pack('C*', BC_BLM, BC(1), BC_WHP, BC(0))) {
	$tp->[thr_registers][$type][$number]
	    and delete $tp->[thr_registers][$type][$number][reg_overload]{$JS};
    } else {
	_create_register($int, $tp, $type, $number);
	$tp->[thr_registers][$type][$number][reg_overload]{$JS} = $code;
    }
}

sub _overload_many {
    my ($int, $tp, $expr, $elen, $N) = @_;
    my ($first, $last) = n_uninterleave($N, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    while ($first <= $last) {
	for my $type (REG_spot, REG_twospot, REG_tail, REG_hybrid, REG_whp) {
	    _remove_overload($int, $tp, $type, $first, '');
	    _add_overload($int, $tp, $type, $first, $expr, $elen, '');
	}
	$first++;
    }
    $N;
}

sub _e_OVM {
    my ($int, $tp, $cp, $ep) = @_;
    my $expr = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify range for " .
		 bytename($tp->[thr_opcode]));
    my $elen = $$cp - $expr;
    my ($N, $type) = _get_numsize($int, $tp, $cp, $ep);
    _overload_many($int, $tp, $expr, $elen, $N);
    ($N, $type);
}

sub _a_OVM {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    my $expr = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify range for " .
		 bytename($tp->[thr_opcode]));
    my $elen = $$cp - $expr;
    my $old_cp = $$cp;
    # first we get the expression as it is now
    my $N = _get_number($int, $tp, \$old_cp, $ep);
    # then we assign a new value and overload using the old value
    _run_a($int, $tp, $cp, $ep, $assign, $atype);
    _overload_many($int, $tp, $expr, $elen, $N);
}

sub _s_STO {
    my ($int, $tp, $cp, $ep) = @_;
    my ($assign, $atype) = _run_e($int, $tp, $cp, $ep);
    _run_a($int, $tp, $cp, $ep, $assign, $atype);
}

sub _s_CFL {
    my ($int, $tp, $cp, $ep) = @_;
    # note: bc_skip because we don't want to trigger any side effects caused
    # by evaluating the label: these will instead be triggered when we check
    # for COME FROMs because we see a label
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify label for " .
		 bytename($tp->[thr_opcode]));
}

*_s_NXL = \&_s_CFL;

sub _s_CFG {
    my ($int, $tp, $cp, $ep) = @_;
    _skip_gerunds($tp, $cp, $ep);
}

*_s_NXG = \&_s_CFG;

my $_skip_gerunds = join('', map { sprintf "\\x%02x", $_ } BC_HSN, BC_OSN);
$_skip_gerunds = qr/^(.*?)[$_skip_gerunds]/;

sub _skip_gerunds {
    my ($tp, $cp, $ep) = @_;
    my $num = BCget($tp->[thr_bytecode], $cp, $ep);
    # in the normal case, we have just a list of bytes, but there could
    # also be other constants, so check for that
    while ($num > 0) {
	$$cp + $num <= $ep
	    or faint(SP_INTERNAL,
		     "Generated bytecode did not specify gerund list for " .
		     bytename($tp->[thr_opcode]));
	if (substr($tp->[thr_bytecode], $$cp, $num) =~ $_skip_gerunds) {
	    $$cp += length($1);
	    $num -= length($1);
	    BCget($tp->[thr_bytecode], $cp, $ep);
	    $num--;
	} else {
	    $$cp += $num;
	    $num = 0;
	}
    }
}

sub _get_gerunds {
    my ($tp, $cp, $ep, $skip_trace) = @_;
    my $ocp = $$cp;
    my $num = BCget($tp->[thr_bytecode], $cp, $ep);
    my $onum = $num;
    my $acp = $$cp;
    # in the normal case, we have just a list of bytes, but there could
    # also be other constants, so check for that
    my @list;
    while ($num > 0) {
	$$cp + $num <= $ep
	    or faint(SP_INTERNAL,
		     "Generated bytecode did not specify gerund list for " .
		     bytename($tp->[thr_opcode]));
	my $s = substr($tp->[thr_bytecode], $$cp, $num);
	if ($s =~ $_skip_gerunds) {
	    my $len = length($1);
	    push @list, map { $_ & 0x7f } unpack('C*', $1);
	    $$cp += $len;
	    $num -= $len;
	    push @list, BCget($tp->[thr_bytecode], $cp, $ep);
	    $num--;
	} else {
	    push @list, map { $_ & 0x7f } unpack('C*', $s);
	    $$cp += $num;
	    $num = 0;
	}
    }
    if ($tp->[thr_tracing] && ! $skip_trace) {
	$tp->[thr_trace_item]("#" . $onum, 1,
			      unpack('C*', substr($tp->[thr_bytecode],
						  $ocp, $acp - $ocp)));
	$tp->[thr_trace_item]->("<", 1);
	$tp->[thr_trace_item]->($_, 0) for @list;
	$tp->[thr_trace_item]->(">", 1);
    }
    @list;
}

sub _e_SPL {
    my ($int, $tp, $cp, $ep) = @_;
    my $sp = $tp->[thr_registers][REG_dos][DOS_SP];
    $sp or faint(SP_SPLAT);
    defined $sp->[reg_print]->($int->{runobject}, $sp->[reg_value])
	or faint(SP_SPLAT);
    ($sp->[reg_value], REG_spot);
}

sub _a_SPL {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _check_number($atype);
    _create_register($int, $tp, REG_dos, DOS_SP);
    my $sp = $tp->[thr_registers][REG_dos][DOS_SP];
    $assign = $sp->[reg_assign]->($int->{runobject}, $assign, $atype);
    $sp->[reg_value] = $assign;
    # what do you expect?
    faint($assign);
}

sub _e_UDV {
    my ($int, $tp, $cp, $ep) = @_;
    my ($num, $spots) = _get_numsize($int, $tp, $cp, $ep);
    if ($tp->[thr_registers][REG_dos][DOS_DM][reg_value]) {
	# bitwise unary divide
	return (n_bitdiv($num, $spots, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]), $spots);
    } else {
	# arithmetic unary divide
	return (n_arithdiv($num, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]), $spots);
    }
}

sub _a_UDV {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _check_number($atype);
    if ($tp->[thr_registers][REG_dos][DOS_DM][reg_value]) {
	# bitwise unary divide
	$assign = n_unbitdiv($assign, $atype, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    } else {
	# arithmetic unary divide
	$assign = n_unarithdiv($assign, $atype, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    }
    _run_a($int, $tp, $cp, $ep, $assign, $atype);
}

sub _s_MSP {
    my ($int, $tp, $cp, $ep) = @_;
    my $splat = _get_spot($int, $tp, $cp, $ep);
    my $narg = $tp->[thr_trace_getnum]($cp, $ep);
    my @arg = ();
    while (@arg < $narg) {
	push @arg, _get_string($int, $tp, $cp, $ep);
    }
    faint($splat, @arg);
}

sub _s_STA {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    while ($num-- > 0) {
	my ($type, $number) = _run_r($int, $tp, $cp, $ep);
	_stash_register($int, $tp, $type, $number);
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _s_RET {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    while ($num-- > 0) {
	my ($type, $number) = _run_r($int, $tp, $cp, $ep);
	_retrieve_register($int, $tp, $type, $number);
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _s_IGN {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    while ($num-- > 0) {
	my ($type, $number) = _run_r($int, $tp, $cp, $ep);
	_create_register($int, $tp, $type, $number, \&_y_IGN);
	$tp->[thr_registers][$type][$number][reg_ignore] = 1;
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _y_IGN {
    my ($reg) = @_;
    $reg = _deep_copy($reg);
    $reg->[reg_ignore] = 0;
    $reg;
}

sub _s_REM {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    while ($num-- > 0) {
	my ($type, $number) = _run_r($int, $tp, $cp, $ep);
	_create_register($int, $tp, $type, $number, \&_y_REM);
	$tp->[thr_registers][$type][$number][reg_ignore] = 0;
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _y_REM {
    my ($reg) = @_;
    $reg = _deep_copy($reg);
    $reg->[reg_ignore] = 1;
    $reg;
}

sub _abstain_reinstate {
    my ($int, $tp, $abstain, $label, @gerunds) = @_;
    my $count = ++$int->{ab_count};
    my $qp = $tp->[thr_quantum];
    if ($label) {
	my @P = ($abstain, $count);
	push @$qp, [[! $abstain, $count], thr_ab_label, $label] if ($qp);
	if (exists $tp->[thr_ab_label]{$label}) {
	    @{$tp->[thr_ab_label]{$label}} = @P;
	} else {
	    for my $t (@{$int->{threads}}, $int->{default}) {
		next if exists $t->[thr_ab_label]{$label};
		$t->[thr_ab_label]{$label} = \@P;
	    }
	}
    }
    for my $_ger (@gerunds) {
	# ABSTAIN FROM EVOLUTION means REINSTATE CREATION etc
	my ($abs, $ger) = $_ger ? ($abstain, $_ger) : ($abstain ? 0 : 1, BC_CRE);
	my @P = ($abs, $count);
	push @$qp, [[! $abs, $count], thr_ab_gerund, $ger] if ($qp);
	if (exists $tp->[thr_ab_gerund]{$ger}) {
	    @{$tp->[thr_ab_gerund]{$ger}} = @P;
	} else {
	    for my $t (@{$int->{threads}}, $int->{default}) {
		next if exists $t->[thr_ab_gerund]{$ger};
		$t->[thr_ab_gerund]{$ger} = \@P;
	    }
	}
    }
}

sub _s_ABL {
    my ($int, $tp, $cp, $ep) = @_;
    my $lab = _get_spot($int, $tp, $cp, $ep);
    faint(SP_INVLABEL, $lab) if $lab < 1 || $lab > 0xffff;
    _abstain_reinstate($int, $tp, 1, $lab);
    undef;
}

sub _s_ABG {
    my ($int, $tp, $cp, $ep) = @_;
    my @ger = _get_gerunds($tp, $cp, $ep);
    _abstain_reinstate($int, $tp, 1, 0, @ger);
    undef;
}

sub _s_REL {
    my ($int, $tp, $cp, $ep) = @_;
    my $lab = _get_spot($int, $tp, $cp, $ep);
    faint(SP_INVLABEL, $lab) if $lab < 1 || $lab > 0xffff;
    _abstain_reinstate($int, $tp, 0, $lab);
    undef;
}

sub _s_REG {
    my ($int, $tp, $cp, $ep) = @_;
    my @ger = _get_gerunds($tp, $cp, $ep);
    _abstain_reinstate($int, $tp, 0, 0, @ger);
    undef;
}

sub _s_BUG {
    my ($int, $tp, $cp, $ep) = @_;
    my $t = $tp->[thr_trace_getnum]($cp, $ep);
    faint($t ? SP_UBUG : SP_BUG);
}

sub _s_ROU {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_QUANTUM, 'READ OUT') if $tp->[thr_quantum];
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    my $fh = $tp->[thr_registers][REG_whp][WHP_ORFH][reg_value]{filehandle};
    _set_read_charset($tp, $fh);
    while ($num-- > 0) {
	my ($value, $type) = _run_e($int, $tp, $cp, $ep);
	if ($type == REG_spot || $type == REG_twospot) {
	    # numeric read
	    my $wimp = $tp->[thr_registers][REG_dos][DOS_WT][reg_value];
	    my $rt = $wimp ? roman_type('WIMPMODE') : $tp->[thr_registers][REG_dos][DOS_RT][reg_value];
	    read_number($value, $rt, $fh);
	} elsif ($type == REG_tail || $type == REG_hybrid) {
	    # array read
	    my $io = $tp->[thr_registers][REG_dos][DOS_IO][reg_value];
	    _create_register($int, $tp, REG_dos, DOS_AR);
	    my $ar = $tp->[thr_registers][REG_dos][DOS_AR][reg_value];
	    my @v = make_list($value);
	    @v or faint(SP_NODIM);
	    if ($type == REG_hybrid) {
		read_array_32($io, \$ar, $fh, \@v, 0);
	    } else {
		my $nl = $tp->[thr_newline] && ($io == 0 || $io == iotype_default);
		read_array_16($io, \$ar, $fh, \@v, $nl);
	    }
	    $tp->[thr_registers][REG_dos][DOS_AR][reg_value] = $ar;
	} elsif ($type == REG_whp) {
	    # whirlpool: set filehandle
	    $value && $value->{filehandle} or faint(SP_READ, 'READ OUT');
	    $fh = $value->{filehandle};
	    _set_read_charset($tp, $fh);
	} else {
	    faint(SP_READ, 'READ OUT');
	}
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _s_WIN {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    my $fh = $tp->[thr_registers][REG_whp][WHP_OWFH][reg_value]{filehandle};
    _set_write_charset($tp, $fh);
    while ($num-- > 0) {
	# first try of we can write it as a register, and then we know
	# what to do; otherwise we'll try a numeric write in and assign
	# to whatever follows
	my $ocp = $$cp;
	my ($type, $number) = eval { _run_r($int, $tp, \$ocp, $ep); };
	if ($@) {
	    # do a numeric Write, then try to assign the result
	    my $wimp = $tp->[thr_registers][REG_dos][DOS_WT][reg_value];
	    my $assign = write_number($fh, $wimp);
	    my $atype = $assign < 0x10000 ? REG_spot : REG_twospot;
	    _run_a($int, $tp, $cp, $ep, $assign, $atype);
	} else {
	    # a register
	    $$cp = $ocp;
	    $type == REG_cho and faint(SP_READ, 'WRITE IN');
	    _create_register($int, $tp, $type, $number);
	    # now see its type so we know how to write things in
	    my $r = $tp->[thr_registers][$type][$number];
	    my $i = $r->[reg_ignore];
	    $r = $r->[reg_value];
	    if ($type == REG_spot || $type == REG_twospot || $type == REG_dos) {
		# numeric read and we use _set_register_3 to deal with side effects
		my $wimp = $tp->[thr_registers][REG_dos][DOS_WT][reg_value];
		my $val = write_number($fh, $wimp);
		my $atype = $val < 0x10000 ? REG_spot : REG_twospot;
		_set_register_3($int, $tp, $type, $number, $val, $atype);
	    } elsif ($type == REG_tail || $type == REG_hybrid || $type == REG_shf) {
		my $io = $tp->[thr_registers][REG_dos][DOS_IO][reg_value];
		_create_register($int, $tp, REG_dos, DOS_AW);
		my $aw = $tp->[thr_registers][REG_dos][DOS_AW][reg_value];
		my @v;
		eval {
		    my $ne = array_elements($r);
		    if ($type == REG_hybrid) {
			@v = write_array_32($io, \$aw, $fh, $ne);
		    } else {
			@v = write_array_16($io, \$aw, $fh, $ne);
		    }
		};
		$@ && substr($@, 0, 4) ne sprintf('*%03d', SP_NODATA) and die $@;
		$i or replace_array($r, $type, @v);
		$tp->[thr_registers][REG_dos][DOS_AW][reg_value] = $aw;
	    } elsif ($type == REG_whp) {
		$fh = $r->{filehandle};
		$fh or faint(SP_READ, 'WRITE IN');
		_set_write_charset($tp, $fh);
	    } else {
		faint(SP_READ, 'WRITE IN');
	    }
	}
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _s_DIV {
    my ($int, $tp, $cp, $ep) = @_;
    $tp->[thr_quantum]
	and push @{$tp->[thr_quantum]},
	    [_deep_copy($tp->[thr_diversions]), thr_diversions];
    my ($cu, $c0, $c1) = _get_region($int, $tp, $cp, $ep);
    my ($du, $d0, $d1) = _get_region($int, $tp, $cp, $ep);
    $c1 < $d0 || $d1 < $c0 or faint(SP_SUBVERSION);
    # if there is already a road closure for the same region, update it;
    # otherwise add a new one
    for my $rc (@{$tp->[thr_diversions]}) {
	my ($ru, $r0, $r1) = @$rc;
	$ru == $cu && $r0 == $c0 && $r1 == $c1 or next;
	$rc->[3] = $du;
	$rc->[4] = $d0;
	$rc->[5] = $d1;
	return;
    }
    push @{$tp->[thr_diversions]}, [$cu, $c0, $c1, $du, $d0, $d1];
}

sub _s_REO {
    my ($int, $tp, $cp, $ep) = @_;
    $tp->[thr_quantum]
	and push @{$tp->[thr_quantum]},
	    [_deep_copy($tp->[thr_diversions]), thr_diversions];
    my ($cu, $c0, $c1) = _get_region($int, $tp, $cp, $ep);
    # look for this road closure and delete it; note that if we happen to be in
    # the corresponding diversion, we still remain in it until the end
    for (my $i = 0; $i < @{$tp->[thr_diversions]}; $i++) {
	my ($ru, $r0, $r1) = @{$tp->[thr_diversions][$i]};
	$ru == $cu && $r0 == $c0 && $r1 == $c1 or next;
	splice(@{$tp->[thr_diversions]}, $i, 1);
	return;
    }
    faint(SP_HEADSPIN);
}

sub _get_region {
    my ($int, $tp, $cp, $ep) = @_;
    my $lab1 = _get_spot($int, $tp, $cp, $ep);
    my $lab2 = _get_spot($int, $tp, $cp, $ep);
    my ($unit1, $pos1) = _find_label($int, $tp, $lab1);
    my ($unit2, $pos2) = _find_label($int, $tp, $lab2);
    $unit1 == $unit2 or faint(SP_DIVERSION, $lab1, 'in a different unit from');
    $pos1 <= $pos2 or faint(SP_DIVERSION, $lab1, 'after', $lab2);
    # advance end position to be just after the final statement
    exists $tp->[thr_code_cache][$unit2]{$pos2} or faint(SP_HEADSPIN);
    my (undef, undef, $cs) = @{$tp->[thr_code_cache][$unit2]{$pos2}};
    $pos2 += $cs;
    ($unit1, $pos1, $pos2);
}

sub _e_INT {
    my ($int, $tp, $cp, $ep) = @_;
    my $num1 = _get_number($int, $tp, $cp, $ep);
    my $num2 = _get_number($int, $tp, $cp, $ep);
    (n_interleave($num1, $num2, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]), REG_twospot);
}

sub _a_INT {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _check_number($atype);
    my ($num1, $num2) = n_uninterleave($assign, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    _run_a($int, $tp, $cp, $ep, $num1, REG_spot);
    _run_a($int, $tp, $cp, $ep, $num2, REG_spot);
}

sub _e_RIN {
    my ($int, $tp, $cp, $ep) = @_;
    # we must execute the operands in reverse order, or side-effects won't
    # work as advertised.
    my $firstop = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify first operand for " .
		 bytename($tp->[thr_opcode]));
    my $firstend = $$cp;
    my $num1 = _get_number($int, $tp, $cp, $ep);
    my $num2 = _get_number($int, $tp, \$firstop, $firstend);
    (n_interleave($num1, $num2, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]), REG_twospot);
}

sub _a_RIN {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    # we must execute the operands in reverse order, or side-effects won't
    # work as advertised.
    my $firstop = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify first operand for " .
		 bytename($tp->[thr_opcode]));
    my $firstend = $$cp;
    _check_number($atype);
    my ($num1, $num2) = n_uninterleave($assign, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    _run_a($int, $tp, $cp, $ep, $num1, REG_spot);
    _run_a($int, $tp, \$firstop, $firstend, $num2, REG_spot);
}

sub _e_SEL {
    my ($int, $tp, $cp, $ep) = @_;
    my $num1 = _get_number($int, $tp, $cp, $ep);
    my ($num2, $spots) = _get_numsize($int, $tp, $cp, $ep);
    my $num = n_select($num1, $num2, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    $spots == REG_twospot && $num < 0x10000 && $tp->[thr_registers][DOS_SM][reg_value]
	and $spots = REG_spot;
    ($num, $spots);
}

sub _a_SEL {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _check_number($atype);
    my $num = n_unselect($assign, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    _run_a($int, $tp, $cp, $ep, $assign, $atype);
    _run_a($int, $tp, $cp, $ep, $num, $atype);
}

sub _e_RSE {
    my ($int, $tp, $cp, $ep) = @_;
    # we must execute the operands in reverse order, or side-effects won't
    # work as advertised.
    my $firstop = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify first operand for " .
		 bytename($tp->[thr_opcode]));
    my $firstend = $$cp;
    my $num1 = _get_number($int, $tp, $cp, $ep);
    my ($num2, $spots) = _get_numsize($int, $tp, \$firstop, $firstend);
    my $num = n_select($num1, $num2, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    $spots == REG_twospot && $num < 0x10000 && $tp->[thr_registers][DOS_SM][reg_value]
	and $spots = REG_spot;
    ($num, $spots);
}

sub _a_RSE {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    # we must execute the operands in reverse order, or side-effects won't
    # work as advertised.
    my $firstop = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify first operand for " .
		 bytename($tp->[thr_opcode]));
    my $firstend = $$cp;
    _check_number($atype);
    my $num = n_unselect($assign, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    _run_a($int, $tp, $cp, $ep, $assign, $atype);
    _run_a($int, $tp, \$firstop, $firstend, $num, $atype);
}

sub _e_SWB {
    my ($int, $tp, $cp, $ep) = @_;
    my ($num, $spots) = _get_numsize($int, $tp, $cp, $ep);
    (n_swb($num, $spots, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]), $spots);
}

sub _a_SWB {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _check_number($atype);
    my $new_value = n_unswb($assign, $atype, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    _run_a($int, $tp, $cp, $ep, $new_value, $atype);
}

sub _e_AWC {
    my ($int, $tp, $cp, $ep) = @_;
    my ($num, $spots) = _get_numsize($int, $tp, $cp, $ep);
    (n_awc($num, $spots, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]), $spots);
}

sub _a_AWC {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    _check_number($atype);
    my $new_value = n_unawc($assign, $atype, $tp->[thr_registers][REG_dos][DOS_BA][reg_value]);
    _run_a($int, $tp, $cp, $ep, $new_value, $atype);
}

sub _e_BUT {
    my ($int, $tp, $cp, $ep) = @_;
    my $prefer = $tp->[thr_trace_getnum]($cp, $ep);
    my ($num, $spots) = _get_numsize($int, $tp, $cp, $ep);
    (n_but($num, $spots, $tp->[thr_registers][REG_dos][DOS_BA][reg_value], $prefer), $spots);
}

sub _a_BUT {
    my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
    my $prefer = $tp->[thr_trace_getnum]($cp, $ep);
    _check_number($atype);
    my $new_value = n_unbut($assign, $atype, $tp->[thr_registers][REG_dos][DOS_BA][reg_value], $prefer);
    _run_a($int, $tp, $cp, $ep, $new_value, $atype);
}

sub _s_CON {
    my ($int, $tp, $cp, $ep) = @_;
    my ($o1, $o2) = _opcode_pair($tp, $cp, $ep, SP_CONVERT);
    if ($int->{record_grammar}) {
	push @{$tp->[thr_grammar_record]}, [BC_CON, $o1, $o2];
    }
    _ii_CON($int, $tp, $o1, $o2);
}

sub _ii_CON {
    my ($int, $tp, $o1, $o2) = @_;
    _load_opcode($int, $tp, $o2);
    ${$tp->[thr_statements][$o1]} = ${$tp->[thr_statements][$o2]};
    # if we are converting a COME FROM to something which isn't a COME FROM,
    # or a non-COME FROM to a COME FROM, we'll have to rebuild the cache:
    my $cf1 = $tp->[thr_come_froms][$o1];
    my $cf2 = $tp->[thr_come_froms][$o2];
    (defined $cf1 && defined $$cf1) == (defined $cf2 && defined $$cf2)
	and return;
    for my $nt ($int->{default}, @{$int->{threads}}) {
	$nt->[thr_registers][REG_dos][DOS_CF]
	    and $nt->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    }
    $$cf1 = $$cf2;
}

sub _s_SWA {
    my ($int, $tp, $cp, $ep) = @_;
    my ($o1, $o2) = _opcode_pair($tp, $cp, $ep, SP_SWAP);
    if ($int->{record_grammar}) {
	push @{$tp->[thr_grammar_record]}, [BC_SWA, $o1, $o2];
    }
    _ii_SWA($int, $tp, $o1, $o2);
}

sub _ii_SWA {
    my ($int, $tp, $o1, $o2) = @_;
    _load_opcode($int, $tp, $o1);
    _load_opcode($int, $tp, $o2);
    (${$tp->[thr_statements][$o1]}, ${$tp->[thr_statements][$o2]}) =
	(${$tp->[thr_statements][$o2]}, ${$tp->[thr_statements][$o1]});
    # if we are swapping a COME FROM with something which isn't a COME FROM,
    # we'll have to rebuild the cache:
    my $cf1 = $tp->[thr_come_froms][$o1];
    my $cf2 = $tp->[thr_come_froms][$o2];
    (defined $cf1 && defined $$cf1) == (defined $cf2 && defined $$cf2)
	and return;
    for my $nt ($int->{default}, @{$int->{threads}}) {
	$nt->[thr_registers][REG_dos][DOS_CF]
	    and $nt->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    }
    ($$cf1, $$cf2) = ($$cf2, $$cf1);
}

sub _opcode_pair {
    my ($tp, $cp, $ep, $splat) = @_;
    $$cp + 2 <= $ep
	or faint(SP_INTERNAL,
		 "Generated bytecode did not specify opcodes for " .
		 bytename($tp->[thr_opcode]));
    my $o1 = vec($tp->[thr_bytecode], $$cp++, 8);
    my @d1 = bytedecode($o1)
	or faint(SP_INVALID, $o1, bytename($tp->[thr_opcode]) . " (first opcode)");
    my $o2 = vec($tp->[thr_bytecode], $$cp++, 8);
    my @d2 = bytedecode($o2)
	or faint(SP_INVALID, $o2, bytename($tp->[thr_opcode]) . " (second opcode)");
    defined ${$tp->[thr_statements][$o1]} &&
	defined ${$tp->[thr_statements][$o2]} &&
	$d1[4] eq $d2[4]
	    or faint($splat, $d1[0], $d2[0]);
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	    [_deep_copy($tp->[thr_statements][$o1]), thr_statements, $o1],
	    [_deep_copy($tp->[thr_statements][$o2]), thr_statements, $o2],
	    [_deep_copy($tp->[thr_come_froms][$o1]), thr_come_froms, $o1],
	    [_deep_copy($tp->[thr_come_froms][$o2]), thr_come_froms, $o2];
    }
    ($o1, $o2);
}

sub _s_FRZ {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_QUANTUM, 'FREEZE') if $tp->[thr_quantum];
    $int->{object}->freeze->shift_parsers;
    for my $thr (@{$int->{threads}}, $int->{default}) {
	shift @{$thr->[thr_rules]};
	@{$thr->[thr_code_cache]} = ();
	@{$thr->[thr_label_cache]} = ();
	$thr->[thr_registers][REG_dos][DOS_CF]
	    and $thr->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
    }
    undef;
}

sub _e_MUL {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]->("<", 1);
    my @vec = ();
    while (@vec < $num) {
	my $v = _get_spot($int, $tp, $cp, $ep);
	push @vec, $v;
    }
    $tp->[thr_trace_item]->(">", 1);
    (\@vec, REG_tail);
}

sub _e_STR {
    # treat STR as a compact form of MUL - if internal optimisations are
    # possible, they will be done instead of calling _e_STR
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $$cp + $num <= $ep
	or faint(SP_INVALID, "String extends past end of code", bytename($tp->[thr_opcode]));
    my $str = substr($tp->[thr_bytecode], $$cp, $num);
    $$cp += $num;
    my @vec = unpack('C*', $str);
    if ($tp->[thr_tracing]) {
	$str =~ s/([\\<>\P{IsPrint}])/sprintf("\\x%02x", ord($1))/ge;
	$str = "<$str>";
	while (length $str > 40) {
	    my $x = substr($str, 0, 40, '');
	    $tp->[thr_trace_item]->($x, 1);
	}
	$tp->[thr_trace_item]->($str, 1);
    }
    (\@vec, REG_tail);
}

sub _s_CRE {
    my ($int, $tp, $cp, $ep) = @_;
    $int->{object} or faint(SP_CONTEXT, "Creation without a grammar");
    my $gra = $tp->[thr_trace_getnum]($cp, $ep);
    $gra >= 1 && $gra <= $int->{object}->num_parsers
	or faint(SP_EVOLUTION, 'Invalid grammar number');
    my $sym = _get_symbol($int, $tp, $cp, $ep);
    my $left = _get_left($int, $tp, $cp, $ep);
    my $right = _get_right($int, $tp, $cp, $ep);
    if ($int->{record_grammar}) {
	push @{$tp->[thr_grammar_record]}, [BC_CRE, $gra, $sym, $left, $right];
    }
    _ii_CRE($int, $tp, $gra, $sym, $left, $right);
}

sub _ii_CRE {
    my ($int, $tp, $gra, $sym, $left, $right) = @_;
    my $r = $int->{object}->parser($gra)->add($sym, $left, $right);
    # if they have modified the other grammar, that's all we need to do
    # if the rule was already in the grammar just enable it
    if ($r < 0) {
	$r = -$r;
	$tp->[thr_trace_item]->("o$r", 1);
	_create_rule($int, $tp, $gra - 1, $r);
	vec($int->{rules}, $tp->[thr_rules][$gra - 1][$r], 1) = 1;
	if ($gra == 1) {
	    @{$tp->[thr_code_cache]} = ();
	    @{$tp->[thr_label_cache]} = ();
	    $tp->[thr_registers][REG_dos][DOS_CF]
		and $tp->[thr_registers][REG_dos][DOS_CF][reg_cache] = undef;
	}
	return;
    }
    $tp->[thr_trace_item]->("n$r", 1);
    _create_rule($int, $tp, $gra - 1, $r);
    # a new rule - must recompile the program if $gra == 1
    if ($gra == 1) {
	_has_source($int, $tp)
	    or faint(SP_CONTEXT, "CREATE requires recompile, but there is no source");
	$int->{recompile} = 1 if $gra == 1;
    }
    vec($int->{rules}, $tp->[thr_rules][$gra - 1][$r], 1) = 1;
}

sub _create_rule {
    my ($int, $tp, $gra, $r) = @_;
    my $rnum = ++$int->{last_rule};
    my @cp = ();
    my @lp = ();
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	    [$tp->[thr_rules][$gra][$r] || 0, thr_rules, $gra, $r];
	$gra == 0
	    and push @{$tp->[thr_quantum]},
		    [[@{$tp->[thr_code_cache]}], thr_code_cache],
		    [[@{$tp->[thr_label_cache]}], thr_label_cache];
    }
    for my $thr (@{$int->{threads}}, $int->{default}) {
	$thr->[thr_rules][$gra][$r] or $thr->[thr_rules][$gra][$r] = $rnum;
	$gra == 0 or next;
	$thr->[thr_code_cache] or $thr->[thr_code_cache] = \@cp;
	$thr->[thr_label_cache] or $thr->[thr_label_cache] = \@lp;
    }
}

sub _s_DES {
    my ($int, $tp, $cp, $ep) = @_;
    $int->{object} or faint(SP_CONTEXT, "Destruction without a grammar");
    my $gra = $tp->[thr_trace_getnum]($cp, $ep);
    $gra >= 1 && $gra <= $int->{object}->num_parsers
	or faint(SP_EVOLUTION, 'Invalid grammar number');
    my $sym = _get_symbol($int, $tp, $cp, $ep);
    my $left = _get_left($int, $tp, $cp, $ep);
    if ($int->{record_grammar}) {
	push @{$tp->[thr_grammar_record]}, [BC_DES, $gra, $sym, $left];
    }
    _ii_DES($int, $tp, $gra, $sym, $left);
}

sub _ii_DES {
    my ($int, $tp, $gra, $sym, $left) = @_;
    my @r = $int->{object}->parser($gra)->find_rule($sym, $left);
    for my $r (@r) {
	$tp->[thr_trace_item]->("r$r", 1);
	_create_rule($int, $tp, $gra - 1, $r);
	vec($int->{rules}, $tp->[thr_rules][$gra - 1][$r], 1) = 0;
    }
    if ($gra == 1) {
	@{$tp->[thr_code_cache]} = ();
	@{$tp->[thr_label_cache]} = ();
    }
}

sub _s_CWB {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_QUANTUM, 'LOOP') if $tp->[thr_quantum];
    my $body = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		 " did not provide loop body");
    $body = substr($tp->[thr_bytecode], $body, $$cp - $body);
    $body eq '' and faint(SP_INVALID, 'empty body', bytename($tp->[thr_opcode]));
    my $bge = vec($body, 0, 8);
    my $cond = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		 " did not provide loop condition");
    $cond = substr($tp->[thr_bytecode], $cond, $$cp - $cond);
    $cond eq '' and faint(SP_INVALID, 'empty condition', bytename($tp->[thr_opcode]));
    my $cge = vec($cond, 0, 8);
    my $cab = $cge && $cge != BC_GUP && $cge != BC_TRD && exists $tp->[thr_ab_gerund]{$cge}
	    ? $tp->[thr_ab_gerund]{$cge}[0]
	    : 0;
    my $bt = _dup_thread($int, $tp);
    my $loop_id = ++$int->{loop_id};
    $bt->[thr_loop_code] = [$body, $bge, $loop_id];
    $bt->[thr_cf_data] = [];
    $tp->[thr_loop_id]{$loop_id} = 1;
    push @{$tp->[thr_in_loop]}, $loop_id;
    if (! $cab) {
	local $tp->[thr_bytecode] = $cond;
	local $tp->[thr_special] = $cond;
	my $p = 0;
	_run_s($int, $tp, \$p, length $cond);
    }
    # there may be a COME FROM gerund looking at the condition
    $cge && ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund)
	and _comefrom($int, $tp, 0, 0, $cge,
		      $tp->[thr_current_unit], $tp->[thr_starting_pos]);
}

sub _s_BWC {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_QUANTUM, 'LOOP') if $tp->[thr_quantum];
    my $cond = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		 " did not provide loop condition");
    $cond = substr($tp->[thr_bytecode], $cond, $$cp - $cond);
    $cond eq '' and faint(SP_INVALID, 'empty condition', bytename($tp->[thr_opcode]));
    my $cge = vec($cond, 0, 8);
    my $cab = $cge && $cge != BC_GUP && $cge != BC_TRD && exists $tp->[thr_ab_gerund]{$cge}
	    ? $tp->[thr_ab_gerund]{$cge}[0]
	    : 0;
    my $body = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		 " did not provide loop body");
    $body = substr($tp->[thr_bytecode], $body, $$cp - $body);
    $body eq '' and faint(SP_INVALID, 'empty body', bytename($tp->[thr_opcode]));
    my $bge = vec($body, 0, 8);
    my $bt = _dup_thread($int, $tp);
    my $loop_id = ++$int->{loop_id};
    $bt->[thr_loop_code] = [$body, $bge, $loop_id];
    $bt->[thr_cf_data] = [];
    $tp->[thr_loop_id]{$loop_id} = 1;
    push @{$tp->[thr_in_loop]}, $loop_id;
    if (! $cab) {
	local $tp->[thr_bytecode] = $cond;
	local $tp->[thr_special] = $cond;
	my $p = 0;
	_run_s($int, $tp, \$p, length $cond);
    }
    # there may be a COME FROM gerund looking at the condition
    $cge && ($tp->[thr_registers][REG_dos][DOS_CF][reg_value] & CF_gerund)
	and _comefrom($int, $tp, 0, 0, $cge,
		      $tp->[thr_current_unit], $tp->[thr_starting_pos]);
}

sub _s_EBC {
    faint(SP_EVENT);
}

sub _s_ECB {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_QUANTUM, 'EVENT') if $tp->[thr_quantum];
    my $cond = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		 " did not provide loop condition");
    $cond = substr($tp->[thr_bytecode], $cond, $$cp - $cond);
    $cond eq '' and faint(SP_INVALID, 'empty condition', bytename($tp->[thr_opcode]));
    my $body = $$cp;
    bc_skip($tp->[thr_bytecode], $cp, $ep)
	or faint(SP_INTERNAL,
		 "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		 " did not provide loop body");
    $body = substr($tp->[thr_bytecode], $body, $$cp - $body);
    $body eq '' and faint(SP_INVALID, 'empty body', bytename($tp->[thr_opcode]));
    my $bge = vec($body, 0, 8);
    push @{$int->{events}}, [$cond, $body, $bge];
}

sub _s_SYS {
    my ($int, $tp, $cp, $ep) = @_;
    faint(SP_QUANTUM, 'System call definition') if $tp->[thr_quantum];
    my $sysnum = _get_spot($int, $tp, $cp, $ep);
    my $count = $tp->[thr_trace_getnum]($cp, $ep);
    my $base = $$cp;
    for (my $n = 0; $n < $count; $n++) {
	my $ocp = $$cp;
	bc_skip($tp->[thr_bytecode], $cp, $ep)
	    or faint(SP_INTERNAL,
		     "Generated bytecode for " .  bytename($tp->[thr_opcode]) .
		     " did not provide argument #$n");
	$tp->[thr_tracing] or next;
	$tp->[thr_trace_exit]($tp);
	$tp->[thr_trace_item]("S$n", 1,
			      unpack('C*', substr($tp->[thr_bytecode],
						  $ocp, $$cp - $ocp)));
    }
    $int->{syscode}{$sysnum} = substr($tp->[thr_bytecode], $base, $$cp - $base);
}

sub _s_GUP {
    my ($int, $tp, $cp, $ep) = @_;
    if ($tp->[thr_current_unit] + 1 < $int->{runobject}->num_units) {
	if ($tp->[thr_quantum]) {
	    push @{$tp->[thr_quantum]},
		 [$tp->[thr_current_unit], thr_current_unit],
		 [$tp->[thr_current_pos], thr_current_pos],
		 [$tp->[thr_special], thr_special],
		 [_deep_copy($tp->[thr_loop_code]), thr_loop_code],
		 [_deep_copy($tp->[thr_in_loop]), thr_in_loop],
		 [$tp->[thr_cf_data], thr_cf_data];
	}
	$tp->[thr_current_unit]++;
	$tp->[thr_current_pos] = 0;
	$tp->[thr_bytecode] = ($int->{runobject}->unit_code($tp->[thr_current_unit]))[2];
	@{$tp->[thr_loop_code]} = ();
	$tp->[thr_cf_data] = [];
	@{$tp->[thr_in_loop]} = ();
    } else {
	$tp->[thr_running] = 0 unless $tp->[thr_quantum];
	$int->{gave_up} = $$cp;
    }
}

sub _s_NXT {
    my ($int, $tp, $cp, $ep) = @_;
    my $lab = _get_spot($int, $tp, $cp, $ep);
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	     [_deep_copy($tp->[thr_next_stack]), thr_next_stack],
	     [$tp->[thr_current_unit], thr_current_unit],
	     [$tp->[thr_current_pos], thr_current_pos],
	     [$tp->[thr_special], thr_special],
	     [_deep_copy($tp->[thr_loop_code]), thr_loop_code],
	     [_deep_copy($tp->[thr_in_loop]), thr_in_loop],
	     [$tp->[thr_cf_data], thr_cf_data];
    }
    @{$tp->[thr_next_stack]} >= MAX_NEXT and faint(SP_NEXTING, MAX_NEXT);
    push @{$tp->[thr_next_stack]}, [
	$tp->[thr_current_unit],
	$tp->[thr_current_pos],
	$tp->[thr_special],
	[@{$tp->[thr_loop_code]}],
	[@{$tp->[thr_in_loop]}],
	$tp->[thr_cf_data],
    ];
    @{$tp->[thr_loop_code]} = ();
    $tp->[thr_cf_data] = [];
    @{$tp->[thr_in_loop]} = ();
    ($tp->[thr_current_unit], $tp->[thr_current_pos]) = _find_label($int, $tp, $lab);
    $tp->[thr_bytecode] = ($int->{runobject}->unit_code($tp->[thr_current_unit]))[2];
    $tp->[thr_special] = undef;
}

sub _s_STU {
    my ($int, $tp, $cp, $ep) = @_;
    my $subject = _get_number($int, $tp, $cp, $ep);
    my $lecture = _get_spot($int, $tp, $cp, $ep);
    my ($ctype, $class) = _run_r($int, $tp, $cp, $ep);
    $ctype == REG_whp or faint(SP_NOTCLASS);
    _create_register($int, $tp, REG_whp, $class);
    $lecture < 1000 and faint(SP_EARLY, $lecture);
    $lecture > 0xffff and faint(SP_SPOTS, $lecture, 'label');
    $tp->[thr_registers][REG_whp][$class][reg_value]{$subject} = $lecture;
    $tp->[thr_registers][REG_whp][$class][reg_default] = 0;
}

sub _s_ENR {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    my @subjects = ();
    while (@subjects < $num) {
	push @subjects, _get_number($int, $tp, $cp, $ep);
    }
    $tp->[thr_trace_item]('>', 1);
    # now look for a class teaching them all
    my @classes = ();
    my $rp = $tp->[thr_registers][REG_whp];
TRY_CLASS:
    for (my $class = 0; $class < @$rp; $class++) {
	$rp->[$class] or next;
	for my $S (@subjects) {
	    $rp->[$class][reg_value] or next TRY_CLASS;
	    $rp->[$class][reg_value]{$S} or next TRY_CLASS;
	}
	push @classes, $class;
    }
    @classes or faint(SP_HOLIDAY, join(' + ', map { "#$_" } @subjects ));
    @classes == 1 or faint(SP_CLASSWAR, (map { "\@$_" } sort @classes)[0, 1]);
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _create_register($int, $tp, $type, $number);
    grep { $_ eq $classes[0] } @{$tp->[thr_registers][$type][$number][reg_enrol]}
	or push @{$tp->[thr_registers][$type][$number][reg_enrol]}, $classes[0];
}

sub _s_LEA {
    my ($int, $tp, $cp, $ep) = @_;
    my $subject = _get_number($int, $tp, $cp, $ep);
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _create_register($int, $tp, $type, $number);
    $tp->[thr_registers][$type][$number][reg_enrol]
	or faint(SP_NOSTUDENT, reg_decode($type, $number));
    my @classes = ();
    my $rp = $tp->[thr_registers][REG_whp];
    for my $class (@{$tp->[thr_registers][$type][$number][reg_enrol]}) {
	$rp->[$class] && $rp->[$class][reg_value]{$subject} or next;
	push @classes, [$class, $rp->[$class][reg_value]{$subject}];
    }
    faint(SP_NOCURRICULUM, '#' . $subject, reg_decode($type, $number)) unless @classes;
    faint(SP_CLASSWAR, map { "\@$_->[0]" }
			   (sort { $a->[0] cmp $b->[0] } @classes)[0, 1])
	if @classes > 1;
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	     [_deep_copy($tp->[thr_lecture_stack]), thr_lecture_stack],
	     [$tp->[thr_current_unit], thr_current_unit],
	     [$tp->[thr_current_pos], thr_current_pos],
	     [$tp->[thr_special], thr_special],
	     [_deep_copy($tp->[thr_loop_code]), thr_loop_code],
	     [_deep_copy($tp->[thr_in_loop]), thr_in_loop],
	     [$tp->[thr_cf_data], thr_cf_data];
    }
    push @{$tp->[thr_lecture_stack]}, [
	$tp->[thr_current_unit],
	$tp->[thr_current_pos],
	$tp->[thr_special],
	$classes[0][0],
	$type, $number,
	[@{$tp->[thr_loop_code]}],
	[@{$tp->[thr_in_loop]}],
	$tp->[thr_cf_data],
    ];
    @{$tp->[thr_loop_code]} = ();
    $tp->[thr_cf_data] = [];
    @{$tp->[thr_in_loop]} = ();
    my ($un, $sc) = _find_label($int, $tp, $classes[0][1]);
    _make_register_belong($int, $tp, REG_whp, $classes[0][0], $type, $number);
    $tp->[thr_current_unit] = $un;
    $tp->[thr_current_pos] = $sc;
    $tp->[thr_bytecode] = ($int->{runobject}->unit_code($tp->[thr_current_unit]))[2];
    $tp->[thr_special] = undef;
}

sub _s_GRA {
    my ($int, $tp, $cp, $ep) = @_;
    my ($type, $number) = _run_r($int, $tp, $cp, $ep);
    _create_register($int, $tp, $type, $number);
    $tp->[thr_registers][$type][$number][reg_enrol]
	or faint(SP_NOSTUDENT, reg_decode($type, $number));
    $tp->[thr_registers][$type][$number][reg_enrol] = undef;
}

sub _s_FIN {
    my ($int, $tp, $cp, $ep) = @_;
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	     [_deep_copy($tp->[thr_lecture_stack]), thr_lecture_stack],
	     [$tp->[thr_current_unit], thr_current_unit],
	     [$tp->[thr_current_pos], thr_current_pos],
	     [$tp->[thr_special], thr_special],
	     [_deep_copy($tp->[thr_loop_code]), thr_loop_code],
	     [_deep_copy($tp->[thr_in_loop]), thr_in_loop],
	     [$tp->[thr_cf_data], thr_cf_data];
    }
    @{$tp->[thr_lecture_stack]} or faint(SP_LECTURE);
    delete $tp->[thr_loop_id]{$_} for @{$tp->[thr_in_loop]};
    my ($class, $stype, $snumber, $lc, $il);
    ($tp->[thr_current_unit], $tp->[thr_current_pos], $tp->[thr_special],
	$class, $stype, $snumber, $lc, $il, $tp->[thr_cf_data]) =
	    @{pop @{$tp->[thr_lecture_stack]}};
    $tp->[thr_bytecode] =
	$tp->[thr_special] || ($int->{runobject}->unit_code($tp->[thr_current_unit]))[2];
    @{$tp->[thr_loop_code]} = @$lc;
    @{$tp->[thr_in_loop]} = @$il;
    _no_longer_belong($int, $tp, REG_whp, $class, $stype, $snumber);
}

sub _s_MKB {
    my ($int, $tp, $cp, $ep) = @_;
    my ($btype, $bnumber) = _run_r($int, $tp, $cp, $ep);
    my ($otype, $onumber) = _run_r($int, $tp, $cp, $ep);
    _make_register_belong($int, $tp, $btype, $bnumber, $otype, $onumber);
    undef;
}

sub _s_NLB {
    my ($int, $tp, $cp, $ep) = @_;
    my ($btype, $bnumber) = _run_r($int, $tp, $cp, $ep);
    my ($otype, $onumber) = _run_r($int, $tp, $cp, $ep);
    _no_longer_belong($int, $tp, $btype, $bnumber, $otype, $onumber);
    undef;
}

sub _find_label {
    my ($int, $tp, $lab) = @_;
    faint(SP_INVLABEL, $lab) if $lab < 1 || $lab > 0xffff;
    my @lab;
    local $tp->[thr_bytecode];
    my $num_units = $int->{runobject}->num_units;
    for (my $unit = 0; $unit < $num_units; $unit++) {
	$tp->[thr_label_cache][$unit] or _cache_statements($int, $tp, $unit);
	$tp->[thr_bytecode] = undef;
	for my $lp (@{$tp->[thr_label_cache][$unit]}) {
	    my ($stmt, $ls, $ll) = @$lp;
	    if ($ll > 0) {
		# computed label, see if we need to get the code
		$tp->[thr_bytecode] ||= ($int->{runobject}->unit_code($unit))[2];
		my $p = $ls;
		$lab == _get_spot($int, $tp, \$p, $ls + $ll)
		    and push @lab, [$unit, $stmt];
	    } elsif (exists $tp->[thr_assign]{$ls}) {
		# constant label - but it has actually changed
		$lab == ${$tp->[thr_assign]{$ls}}
		    and push @lab, [$unit, $stmt];
	    } elsif ($ls == $lab) {
		# constant label, and unchanged too!
		push @lab, [$unit, $stmt];
	    }
	}
    }
    @lab or faint(SP_NOSUCHLABEL, $lab);
    @lab == 1 or faint(SP_TOOMANYLABS, scalar @lab, $lab);
    @{$lab[0]};
}

sub _s_RES {
    my ($int, $tp, $cp, $ep) = @_;
    my $size = _get_spot($int, $tp, $cp, $ep);
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	     [_deep_copy($tp->[thr_next_stack]), thr_next_stack],
	     [$tp->[thr_current_unit], thr_current_unit],
	     [$tp->[thr_current_pos], thr_current_pos],
	     [$tp->[thr_special], thr_special],
	     [_deep_copy($tp->[thr_loop_code]), thr_loop_code],
	     [_deep_copy($tp->[thr_in_loop]), thr_in_loop],
	     [$tp->[thr_cf_data], thr_cf_data];
    }
    $size > 0 or faint(SP_NORESUME);
    if (@{$tp->[thr_next_stack]} < $size) {
	@{$tp->[thr_next_stack]} = ();
	faint(SP_RESUME);
    }
    if ($size > 1) {
	splice(@{$tp->[thr_next_stack]}, 1 - $size);
    }
    delete $tp->[thr_loop_id]{$_} for @{$tp->[thr_in_loop]};
    my ($lc, $il);
    ($tp->[thr_current_unit], $tp->[thr_current_pos], $tp->[thr_special], $lc, $il, $tp->[thr_cf_data]) =
	@{pop @{$tp->[thr_next_stack]}};
    $tp->[thr_bytecode] =
	$tp->[thr_special] || ($int->{runobject}->unit_code($tp->[thr_current_unit]))[2];
    @{$tp->[thr_loop_code]} = @$lc;
    @{$tp->[thr_in_loop]} = @$il;
}

sub _s_FOR {
    my ($int, $tp, $cp, $ep) = @_;
    my $size = _get_spot($int, $tp, $cp, $ep);
    if ($tp->[thr_quantum]) {
	push @{$tp->[thr_quantum]},
	     [_deep_copy($tp->[thr_next_stack]), thr_next_stack];
    }
    $size > 0 or return;
    if (@{$tp->[thr_next_stack]} < $size) {
	@{$tp->[thr_next_stack]} = ();
    } else {
	splice(@{$tp->[thr_next_stack]}, -$size);
    }
}

sub _s_TRD {
    my ($int, $tp, $cp, $ep) = @_;
    my ($utype, $unumber) = _run_r($int, $tp, $cp, $ep);
    my $delay = _get_number($int, $tp, $cp, $ep);
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    _create_register($int, $tp, $utype, $unumber, sub { _y_TRD($num, @_) });
    while ($num-- > 0) {
	my ($dtype, $dnumber) = _run_r($int, $tp, $cp, $ep);
        _create_register($int, $tp, $dtype, $dnumber);
	push @{$tp->[thr_registers][$utype][$unumber][reg_trickle]},
	    [$dtype, $dnumber, $delay];
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _y_TRD {
    my ($num, $reg) = @_;
    $reg = _deep_copy($reg);
    if ($reg->[reg_trickle] && @{$reg->[reg_trickle]} > $num) {
	splice(@{$reg->[reg_trickle]}, -$num);
    } else {
	@{$reg->[reg_trickle]} = ();
    }
    $reg;
}

sub _s_TRU {
    my ($int, $tp, $cp, $ep) = @_;
    my $num = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    while ($num-- > 0) {
	my ($type, $number) = _run_r($int, $tp, $cp, $ep);
	$tp->[thr_registers][$type][$number][reg_trickle] or next;
	@{$tp->[thr_registers][$type][$number][reg_trickle]} or next;
	my @undo = @{$tp->[thr_registers][$type][$number][reg_trickle]};
	_create_register($int, $tp, $type, $number, sub { _y_TRU(\@undo, @_) });
	@{$tp->[thr_registers][$type][$number][reg_trickle]} = ();
    }
    $tp->[thr_trace_item]('>', 1);
}

sub _y_TRU {
    my ($undo, $reg) = @_;
    $reg = _deep_copy($reg);
    $reg->[reg_trickle] = $undo;
    $reg;
}

sub _ref_to_type {
    my ($ref) = @_;
    ref $ref eq 'ARRAY' and return REG_tail;
    eval { $ref->isa('Language::INTERCAL::GenericIO') } and return REG_whp;
    # XXX any other references we may know what to do with?
    faint(SP_NOTCLASS);
}

sub _x_UNx {
    my ($int, $tp, $cp, $ep) = @_;
    my $byte = $tp->[thr_opcode];
    if ($tp->[thr_quantum]) {
	$byte == BC_UNA and faint(SP_QUANTUM, "UNdocumented Assignment");
	$byte == BC_UNE and faint(SP_QUANTUM, "UNdocumented Expression");
	$byte == BC_UNS and faint(SP_QUANTUM, "UNdocumented Statement");
	faint(SP_QUANTUM, bytename($byte));
    }
    $byte == BC_UNE or $tp->[thr_trace_getnum]($cp, $ep); # skip gerund
    my $m = _get_str_or_fh($int, $tp, $cp, $ep) || '';
    my $f = _get_string($int, $tp, $cp, $ep);
    my $count = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    my @args = ();
    while (@args < $count) {
	my $arg = _get_str_or_fh($int, $tp, $cp, $ep);
	if (! ref $arg && substr($arg, 0, 1) eq '[') {
	    if ($arg eq '[[INT]]') {
		$arg = $int;
	    } elsif ($arg eq '[[TP]]') {
		$arg = $tp;
	    } elsif ($arg eq '[[CLASS]]') {
		$arg = "Language::INTERCAL::" . ($m || 'Interpreter');
	    } elsif ($arg =~ /^\[\[INT_(\w+)\]\]/) {
		# we used to have [[THEFT]] and [[SERVER]] but they were
		# never documented; in future these will be [[INT_server]]
		# and [[INT_theft_server]] respectively and we don't need
		# to know about which extensions added what
		$arg = $int->{$1};
	    }
	}
	push @args, $arg;
    }
    $tp->[thr_trace_item]('>', 1);
    my @res;
    if (ref $m) {
	# filehandle or other object, make this a method call
	no strict 'subs';
	@res = map {
	    ($_, ref $_ ? _ref_to_type($_) : $_ > 0xffff ? REG_twospot : REG_spot)
	} $m->$f(@args);
    } else {
	# if the module is specified, and not yet loaded, load it now
	if ($m && ! exists $unx_cache{$m}) {
	    my $c = "require Language::INTERCAL::${m}";
	    eval $c;
	    $@ and faint(SP_UNDOCUMENTED, 'module', $m);
	    $unx_cache{$m} = {};
	}
	# cache the coderef to the function
	if (! exists $unx_cache{$m}{$f}) {
	    my $c = $m ? "\\&Language::INTERCAL::${m}::${f}" : "\\&$f";
	    my $p = eval $c;
	    $@ and faint(SP_UNDOCUMENTED, 'function', $m ? "$m\::$f" : $f);
	    $unx_cache{$m}{$f} = $p;
	}
	@res = $unx_cache{$m}{$f}->(@args);
	if (@res == 1) {
	    my ($v) = @res;
	    if (ref $v) {
		if (eval { $v->isa('Language::INTERCAL::GenericIO') }) {
		    push @res, REG_whp;
		} else {
		    push @res, REG_tail;
		}
	    } elsif ($v =~ /^\d+$/) {
		push @res, $v < 0x10000 ? REG_spot : REG_twospot;
	    } else {
		push @res, REG_tail;
	    }
	}
	@res % 2
	    and faint(SP_INVUNDOC, $m ? "${m}::$f" : $f, "Odd number of values provided");
    }
    if ($byte == BC_UNA) {
	$count = $tp->[thr_trace_getnum]($cp, $ep);
	$tp->[thr_trace_item]('<', 1);
	2 * $count == @res
	    or faint(SP_INVUNDOC, $m ? "${m}::$f" : $f,
		     "Wrong number of values " . ((scalar @res) / 2) .  " provided, $count expected");
	while (@res) {
	    my $assign = shift @res;
	    my $atype = shift @res;
	    _run_a($int, $tp, $cp, $ep, $assign, $atype);
	}
	$tp->[thr_trace_item]('>', 1);
    } elsif ($byte == BC_UNE) {
	2 == @res
	    or faint(SP_INVUNDOC, $m ? "${m}::$f" : $f,
		     "Wrong number of values " . ((scalar @res) / 2) . " provided, 1 expected");
	return @res;
    }
}

*_s_UNA = \&_x_UNx;
*_e_UNE = \&_x_UNx;
*_s_UNS = \&_x_UNx;

sub _get_left {
    my ($int, $tp, $cp, $ep) = @_;
    my $lcount = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    my @left = ();
    while (@left < $lcount) {
	my $count = _get_spot($int, $tp, $cp, $ep);
	my $tn = $tp->[thr_trace_getnum]($cp, $ep);
	if ($tn == 0) {
	    # symbol
	    my $s = _get_symbol($int, $tp, $cp, $ep);
	    push @left, ['s', $s, $count];
	    next;
	}
	if ($tn == 1) {
	    # constant
	    my $d = _get_string($int, $tp, $cp, $ep);
	    push @left, ['c', $d, $count];
	    next;
	}
	faint(SP_CREATION, "Invalid left type $tn");
    }
    $tp->[thr_trace_item]('>', 1);
    \@left;
}

sub _get_right {
    my ($int, $tp, $cp, $ep) = @_;
    my $rcount = $tp->[thr_trace_getnum]($cp, $ep);
    $tp->[thr_trace_item]('<', 1);
    my @right = ();
    while (@right < $rcount) {
	my $tn = $tp->[thr_trace_getnum]($cp, $ep);
	if ($tn == 0 || $tn == 6) {
	    # tn == 0 ? symbol : count(symbol)
	    my $n = _get_spot($int, $tp, $cp, $ep);
	    my $s = _get_symbol($int, $tp, $cp, $ep);
	    push @right, [$tn == 0 ? 's' : 'n', $n, $s];
	    next;
	}
	if ($tn == 1) {
	    # constant
	    my $n = _get_spot($int, $tp, $cp, $ep);
	    my $d = _get_string($int, $tp, $cp, $ep);
	    push @right, ['c', $n, $d];
	    next;
	}
	if ($tn == 4) {
	    # block of bytecode
	    my $len = $tp->[thr_trace_getnum]($cp, $ep);
	    $len + $$cp <= $ep
		or faint(SP_CREATION, "Block extends after end of code");
	    my $block = substr($tp->[thr_bytecode], $$cp, $len);
	    if ($tp->[thr_tracing]) {
		$tp->[thr_trace_item]->('<', 1);
		$tp->[thr_trace_item]->($_, 0) for unpack('C*', $block);
		$tp->[thr_trace_item]->('>', 1);
	    }
	    $$cp += $len;
	    push @right, ['b', $block];
	    next;
	}
	if ($tn == 15) {
	    # "*"
	    push @right, ['*'];
	    next;
	}
	faint(SP_CREATION, "Invalid right type $tn");
    }
    $tp->[thr_trace_item]('>', 1);
    \@right;
}

# alternative call to _run_e to make sure the result is a number, and return
# just that number, without its size
sub _get_number {
    my ($int, $tp, $cp, $ep) = @_;
    my ($value, $type) = _run_e($int, $tp, $cp, $ep);
    $type == REG_spot || $type == REG_twospot and return $value;
    $type == REG_whp and faint(SP_ISCLASS);
    $type == REG_tail || $type == REG_hybrid and faint(SP_ISARRAY);
    faint(SP_ISSPECIAL);
}

# alternative call to _run_e to make sure the result is a number and it fits
# in one spot; return just that number, without its size
sub _get_spot {
    my ($int, $tp, $cp, $ep) = @_;
    my ($value, $type) = _run_e($int, $tp, $cp, $ep);
    $type == REG_spot and return $value;
    if ($type == REG_twospot) {
	$value > 0xffff and faint(SP_SPOTS, $value, "one spot");
	return $value;
    }
    $type == REG_whp and faint(SP_ISCLASS);
    $type == REG_tail || $type == REG_hybrid and faint(SP_ISARRAY);
    faint(SP_ISSPECIAL);
}

# alternative call to _run_e to make sure the result is a number, then return
# the number and its size
sub _get_numsize {
    my ($int, $tp, $cp, $ep) = @_;
    my ($value, $type) = _run_e($int, $tp, $cp, $ep);
    $type == REG_spot || $type == REG_twospot and return ($value, $type);
    $type == REG_whp and faint(SP_ISCLASS);
    $type == REG_tail || $type == REG_hybrid and faint(SP_ISARRAY);
    faint(SP_ISSPECIAL);
}

# given a type, make sure it identifies a number
sub _check_number {
    my ($type) = @_;
    $type == REG_spot || $type == REG_twospot and return;
    $type == REG_whp and faint(SP_ISCLASS);
    $type == REG_tail || $type == REG_hybrid and faint(SP_ISARRAY);
    faint(SP_ISSPECIAL);
}

sub _get_symbol {
    my ($int, $tp, $cp, $ep) = @_;
    # special optimisation for STR
    if ($$cp < $ep && vec($tp->[thr_bytecode], $$cp, 8) == BC_STR) {
	$tp->[thr_trace_item]->(BC_STR, 0);
	$$cp++;
	my $l = $tp->[thr_trace_getnum]($cp, $ep);
	$$cp + $l <= $ep
	    or faint(SP_INVALID, "Not enough constants", 'symbol');
	my $num = substr($tp->[thr_bytecode], $$cp, $l);
	$$cp += $l;
	if ($tp->[thr_tracing]) {
	    my $s = $num;
	    $s =~ s/([%\[\]\P{IsPrint}])/sprintf("%%%02X", ord($1))/ge;
	    $tp->[thr_trace_item]->("[$s]", 1);
	}
	return $int->{object}->symboltable->find($num);
    } else {
	my ($num, $type) = _run_e($int, $tp, $cp, $ep);
	# just validate it as if assigning to '%PS'
	return $tp->[thr_registers][REG_dos][DOS_PS][reg_assign]->($int->{object}, $num, $type);
    }
}

sub _get_string {
    my ($int, $tp, $cp, $ep) = @_;
    my $string;
    # special optimisation for STR
    if ($$cp < $ep && vec($tp->[thr_bytecode], $$cp, 8) == BC_STR) {
	$tp->[thr_trace_item]->(BC_STR, 0);
	$$cp++;
	my $l = $tp->[thr_trace_getnum]($cp, $ep);
	$$cp + $l <= $ep
	    or faint(SP_INVALID, "Not enough constants", 'string');
	$string = substr($tp->[thr_bytecode], $$cp, $l);
	$$cp += $l;
    } else {
	my $type;
	($string, $type) = _run_e($int, $tp, $cp, $ep);
	if ($type == REG_spot || $type == REG_twospot) {
	    # nothing to do here
	} elsif ($type == REG_tail || $type == REG_hybrid) {
	    $string = pack('C*', make_list($string));
	    $string =~ s/\0+$//;
	} else {
	    faint(SP_NOARRAY);
	}
    }
    my $s = $string;
    $s =~ s/([%\[\]\P{IsPrint}])/sprintf("%%%02X", ord($1))/ge;
    $tp->[thr_trace_item]->("[$s]", 1);
    $string;
}

sub _get_str_or_fh {
    my ($int, $tp, $cp, $ep) = @_;
    my $string;
    my $s;
    # special optimisation for STR
    if ($$cp < $ep && vec($tp->[thr_bytecode], $$cp, 8) == BC_STR) {
	$tp->[thr_trace_item]->(BC_STR, 0);
	$$cp++;
	my $l = $tp->[thr_trace_getnum]($cp, $ep);
	$$cp + $l <= $ep
	    or faint(SP_INVALID, "Not enough constants", 'symbol or filehandle');
	$string = substr($tp->[thr_bytecode], $$cp, $l);
	$$cp += $l;
    } else {
	my $type;
	($string, $type) = _run_e($int, $tp, $cp, $ep);
	if ($type == REG_spot || $type == REG_twospot) {
	    # nothing to do here
	} elsif ($type == REG_tail || $type == REG_hybrid) {
	    $string = baudot2ascii(pack('C*', make_list($string)));
	    $string =~ s/\0+$//;
	} elsif ($type == REG_whp) {
	    $string && $string->{filehandle} or faint(SP_NOTCLASS);
	    $string = $string->{filehandle};
	    $s = $string->describe;
	} else {
	    faint(SP_NOARRAY);
	}
    }
    $s = $string if ! defined $s;
    $s =~ s/([%\[\]\P{IsPrint}])/sprintf("%%%02X", ord($1))/ge;
    $tp->[thr_trace_item]->("[$s]", 1);
    $string;
}

sub _set_read_charset {
    my ($tp, $fh) = @_;
    my $cs = $tp->[thr_registers][REG_dos][DOS_CR][reg_value];
    $fh->read_charset($cs);
}

sub _set_write_charset {
    my ($tp, $fh) = @_;
    my $cs = $tp->[thr_registers][REG_dos][DOS_CW][reg_value];
    $fh->write_charset($cs);
}

sub _set_thread_tracing {
    my ($int, $tp) = @_;
    my $rp = $tp->[thr_registers];
    if ($rp->[REG_dos][DOS_TM][reg_value] && $rp->[REG_whp][WHP_TRFH][reg_value]{filehandle}) {
	my $trace_fh = $rp->[REG_whp][WHP_TRFH][reg_value]{filehandle};
	my $trace_exit = sub {
	    my ($tp) = @_;
	    _set_read_charset($tp, $trace_fh);
	    my $hex = '';
	    my $asc = '';
	    for my $trace (@{$int->{trace}}) {
		my ($byte, $special, @etc) = @$trace;
		my ($h, $a);
		if ($special) {
		    $hex .= join('', map { sprintf(" %02X", $_) } @etc);
		    $asc .= ' ' . $byte;
		} else {
		    $hex .= defined $byte ? sprintf(" %02X", $byte) : '';
		    $asc .= ' ' . (bytename($byte) || '???');
		}
	    }
	    $hex =~ s/^\s+//;
	    $asc =~ s/^\s+//;
	    while ($hex ne '' || $asc ne '') {
		my $prh = substr($hex, 0, 30, '');
		my $pra = substr($asc, 0, 41);
		if (length $pra > 40) {
		    $pra =~ s/\s+\S*$//;
		    length($pra) > 40 and $pra = substr($pra, 0, 40);
		}
		$asc = substr($asc, length $pra);
		$asc =~ s/^\s+//;
		$trace_fh->read_text(sprintf("%-33s| %s\n", $prh, $pra));
	    }
	    $int->{trace} = [];
	};
	$tp->[thr_tracing] = 1;
	$tp->[thr_trace_init] = sub { $int->{trace} = [] };
	$tp->[thr_trace_item] = sub { push @{$int->{trace}}, [@_] };
	$tp->[thr_trace_getnum] = sub {
	    my ($cp, $ep) = @_;
	    my $ocp = $$cp;
	    my $val = BCget($tp->[thr_bytecode], $cp, $ep);
	    push @{$int->{trace}}, ["#" . $val, 1,
				    unpack('C*', substr($tp->[thr_bytecode],
							$ocp, $$cp - $ocp))];
	    return $val;
	};
	$tp->[thr_trace_mark] = sub {
	    my ($tp, @data) = @_;
	    $trace_exit->($tp);
	    $trace_fh->read_text("[$tp->[thr_tid]] \@" . join(' ', @data) . "\n");
	    $trace_exit->($tp);
	};
	$tp->[thr_trace_exit] = $trace_exit;
    } else {
	$tp->[thr_tracing] = 0;
	$tp->[thr_trace_init] = sub { };
	$tp->[thr_trace_getnum] = sub {
	    BCget($tp->[thr_bytecode], $_[0], $_[1]);
	};
	$tp->[thr_trace_item] = sub { };
	$tp->[thr_trace_mark] = sub { };
	$tp->[thr_trace_exit] = sub { };
    }
}

sub _set_tracing {
    my ($int) = @_;
    for my $tp ($int->{default}, @{$int->{threads}}) {
	_set_thread_tracing($int, $tp);
    }
}

# used by the system call interface
sub _newline {
    my ($tp) = @_;
    $tp->[thr_newline] = ! $tp->[thr_newline];
    ();
}

1;
