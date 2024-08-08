package Language::INTERCAL::DynamicRegTypes::Extend;

use strict;
use Language::INTERCAL::Registers '1.-94.-2.2', qw(REG_spot REG_whp);
use Language::INTERCAL::Interpreter '1.-94.-2.3', 
  qw(thr_registers thr_bytecode thr_special reg_value 
     reg_overload reg_belongs reg_assign
     reg_print reg_type reg_ignore reg_default thr_stash);
use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(BCget bc_skip);
use Language::INTERCAL::Splats '1.-94.-2.1', qw(faint);
require Data::Dumper;

use vars qw($VERSION $PERVERSION);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/DynamicRegTypes INTERCAL/DynamicRegTypes/Extend.pm 1.-94.-2.4")
  =~ /\s(\S+)$/;

BEGIN {
  *_get_number = \&Language::INTERCAL::Interpreter::_get_number;
  *_run_s = \&Language::INTERCAL::Interpreter::_run_s;
  *_run_e = \&Language::INTERCAL::Interpreter::_run_e;
  *_stash_register = \&Language::INTERCAL::Interpreter::_stash_register;
  *_retrieve_register = \&Language::INTERCAL::Interpreter::_retrieve_register;
  *_get_spot = \&Language::INTERCAL::Interpreter::_get_spot;
}

my $assignment_callbacks = [];
my $type_defaults = [];
my $check_types = 1;

my @imports = ("RegAddable");
for (@imports) {
#  print "importing $_\n";
  my $evalstr = "require Language::INTERCAL::DynamicRegTypes::$_; Language::INTERCAL::DynamicRegTypes::$_->setup(\$assignment_callbacks, \$type_defaults, \\\$check_types);";
#  print "$evalstr\n";
  eval $evalstr;
  $@ and die $@;
#  print Data::Dumper->Dump([$assignment_callbacks], ['$assignment_callbacks']);
}

sub add_callback {
  my ($code, $ext, $module) = @_;
  $code->('start', \&_cb_start);
}

my $_create_register_ref = 
  \&Language::INTERCAL::Interpreter::_create_register;
my $_set_register_3_ref = 
  \&Language::INTERCAL::Interpreter::_set_register_3;
my $_check_number_ref = 
  \&Language::INTERCAL::Interpreter::_check_number;
my $_get_register_2_ref = 
  \&Language::INTERCAL::Interpreter::_get_register_2;

# no warnings;
sub _cb_start {
  
  *Language::INTERCAL::Interpreter::_create_register = 
    sub {
      my ($int, $tp, $type, $number) = @_;
      if ($type >= 1 && $type <= 8) {
        $_create_register_ref->($int, $tp, $type, $number);
        return;
      }
    # print "$tp\n";
      if (!($tp->[thr_registers][$type][$number])) {
        my @newreg;
        $newreg[reg_value] = $type_defaults->[$type][0];
        $newreg[reg_assign] = undef;
        $newreg[reg_print] = undef;
        $newreg[reg_type] = undef;
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
    };
  *Language::INTERCAL::Interpreter::_set_register_3 =
    sub {
      my ($int, $tp, $type, $number, $assign, $atype) = @_;
      if (!$assignment_callbacks->[$type][$atype]) {
      # print "No assignment callback found for $type <- $atype\n";
      # print Data::Dumper->Dump([$assignment_callbacks], ['$assignment_callbacks']);
        $_set_register_3_ref->($int, $tp, $type, $number, $assign, $atype);
        return;
      }
    # print "Assignment callback found!\n";
      $assignment_callbacks->[$type][$atype]->(
        $int, $tp, $type, $number, $assign, $atype);
    };
  *Language::INTERCAL::Interpreter::_check_number = 
    sub {my ($type) = @_; if ($check_types) { $_check_number_ref->($type); }};
  *Language::INTERCAL::Interpreter::_get_register_2 =
    sub {
      my ($int, $tp, $type, $number) = @_;
      my $value;
      if ($check_types) {
        ($value, $type) = $_get_register_2_ref->($int, $tp, $type, $number);
      }
      else {
        eval { ($value, $type) = $_get_register_2_ref->($int, $tp, $type, $number); };
      }
      return ($value, $type);
    }
}
# use warnings;

sub add_opcode {
  my ($code, $ext, $module) = @_;
  $code->(
    $module, 78, 'DRT', 'R', 'C(EE)C(S)',
    'Dynamic Register Type', \&_e_DRT, \&_a_DRT, \&_r_DRT, "");
}

sub get_regname {
  my ($int, $tp, $cp, $ep) = @_;
  my $type = 1;
  my $num = 1;
=begin comment
  my $constantCount = BCget($int, $tp, $cp);
  if ($constantCount == 1) {
    $type = BCget($int, $tp, $cp);
    $num = BCget($int, $tp, $cp);
  }
  else {
    $constantCount == 0 or 
      faint(0, "Constant count cannot be more than 1 in the DRT opcode\n")
  }
=cut
  my $expressionCount = BCget($tp->[thr_bytecode], $cp, $ep);
  if ($expressionCount == 1) {
    $type = _get_spot($int, $tp, $cp, $ep);# BCget($tp->[thr_bytecode], $cp, $ep);
    $num = _get_spot($int, $tp, $cp, $ep);
  }
  else {
    $expressionCount == 0 or
      faint(0, 
        "Expression pair count cannot be more than 1 in the DRT opcode\n");
  }
  my $statementCount = BCget($tp->[thr_bytecode], $cp, $ep);
  $statementCount == 0 and return ($type, $num);
  _stash_register($int, $tp, REG_spot, 1);
  _stash_register($int, $tp, REG_spot, 2);
  for (1..$statementCount) {
    _run_s($int, $tp, $cp, $ep);
  }
  $type = $tp->[thr_registers][REG_spot][1][reg_value];
  $num = $tp->[thr_registers][REG_spot][2][reg_value];
#  print Data::Dumper->Dump([$tp->[thr_registers][REG_spot]], ['SPOTLIST']);
#  print "in get_regname - Type: $type, Num: $num\n";
  _retrieve_register($int, $tp, REG_spot, 1);
  _retrieve_register($int, $tp, REG_spot, 2);
  return ($type, $num);
}

sub _e_DRT {
  my ($int, $tp, $cp, $ep) = @_;
  my ($type, $num) = get_regname($int, $tp, $cp, $ep);
  return ($tp->[thr_registers][$type][$num][reg_value], $type);
}

sub _a_DRT {
  my ($int, $tp, $cp, $ep, $assign, $atype) = @_;
  my ($type, $num) = get_regname($int, $tp, $cp, $ep);
#  print "Type: $type, Num: $num\n";
  $int->_create_register($tp, $type, $num);
  $int->_set_register_2($tp, $type, $num, $assign, $atype);
}

sub _r_DRT {
  my ($int, $tp, $cp, $ep, $no_overload) = @_;
  my ($type, $num) = get_regname($int, $tp, $cp, $ep);
  $tp->[thr_registers][$type][$num] &&
    $tp->[thr_registers][$type][$num][reg_overload]{''}
    or return ($type, $num);
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
