package Language::INTERCAL::DynamicRegTypes::RegAddable;

require Language::INTERCAL::DynamicRegTypes::Extend;
use Language::INTERCAL::Interpreter '1.-94.-2.3',
  qw(thr_registers reg_value);
use Language::INTERCAL::Registers '1.-94.-2.2',
  qw(REG_spot REG_twospot REG_cho);

use vars qw($VERSION $PERVERSION @EXPORT_OK);
($VERSION) = ($PERVERSION = "CLC-INTERCAL/RegAddable INTERCAL/RegAddable/Extend.pm 1.-94.-2.4")
  =~ /\s(\S+)$/;
@EXPORT_OK = qw(REG_add);

use constant REG_add => 10;

sub setup {
 # print "setting up\n";
  my ($class, $assignment_callbacks, $type_defaults, $check_types) = @_;
  $$check_types = 0;
  $type_defaults->[REG_add] = [0];
  $assignment_callbacks->[REG_add] = [];
  $assignment_callbacks->[REG_add][REG_spot] = sub {
      my ($int, $tp, $type, $number, $assign, $atype) = @_;
     # print "spot is being assigned to add.\n";
      $atype != REG_spot and die "Somehow the \$atype in assigning spot to add ended up being $atype instead of 1.\n";
      $type != REG_add and die ("Somehow the \$type in assigning spot to add ended up being $type instead of " . REG_add . "\n");
      $tp->[thr_registers][$type][$number][reg_value] = 
        ($tp->[thr_registers][$type][$number][reg_value] + $assign) 
    };
  $assignment_callbacks->[REG_add][REG_twospot] = sub {
      my ($int, $tp, $type, $number, $assign, $atype) = @_;
     # print "twospot is being assigned to add.\n";
      $atype != REG_twospot and die "Somehow the \$atype in assigning twospot to add ended up being $atype instead of 2.\n";
      $type != REG_add and die ("Somehow the \$type in assigning spot to add ended up being $type instead of " . REG_add . "\n");
      $tp->[thr_registers][$type][$number][reg_value] = 
        ($tp->[thr_registers][$type][$number][reg_value] + $assign) 
    };
  $assignment_callbacks->[REG_add][REG_cho] = sub {
      my ($int, $tp, $type, $number, $assign, $atype) = @_;
     # print "whp is being assigned to add.\n";
      $atype != REG_cho and die "Somehow the \$atype in assigning crawling horror to add ended up being $atype instead of 6.\n";
      $type != REG_add and die ("Somehow the \$type in assigning crawling horror to add ended up being $type instead of " . REG_add . "\n");
      $tp->[thr_registers][$type][$number][reg_value] = 
        $type_defaults->[REG_add][0];
    };
  !$assignment_callbacks->[REG_spot] and $assignment_callbacks->[REG_spot] = [];
  $assignment_callbacks->[REG_spot][REG_add] = sub {
      my ($int, $tp, $type, $number, $assign, $atype) = @_;
     # print "add is being assigned to spot.\n";
      $atype != REG_add and die ("Somehow the \$atype in assigning add to spot ended up being $atype instead of " . REG_add . "\n");
      $type != REG_spot and die ("Somehow the \$type in assigning add to spot ended up being $type instead of 1\n");
      $tp->[thr_registers][$type][$number][reg_value] = $assign & 65535;
    };
  !$assignment_callbacks->[REG_twospot] and $Language::INTERCAL::DynamicRegTypes::Extend::assignment_callbacks->[REG_twospot] = [];
  $assignment_callbacks->[REG_twospot][REG_add] = sub {
      my ($int, $tp, $type, $number, $assign, $atype) = @_;
     # print "add is being assigned to twospot.\n";
      $atype != REG_add and die ("Somehow the \$atype in assigning add to twospot ended up being $atype instead of " . REG_add . "\n");
      $type != REG_twospot and die ("Somehow the \$type in assigning add to twospot ended up being $type instead of 2\n");
      $tp->[thr_registers][$type][$number][reg_value] = $assign;
    };
}
