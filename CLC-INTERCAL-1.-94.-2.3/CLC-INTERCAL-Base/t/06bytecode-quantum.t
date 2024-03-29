# test bytecode interpreter - quantum statements

# Copyright (c) 2006-2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION CLC-INTERCAL/Base t/06bytecode-quantum.t 1.-94.-2.3

use Language::INTERCAL::ByteCode '1.-94.-2.2', qw(:BC BC);
use Language::INTERCAL::Registers '1.-94.-2.2', qw(reg_code);
use Language::INTERCAL::TestBC '1.-94.-2', qw(test_bc test_str);

my @all_tests = (
    ['Comment 1', undef, '', "*000 ERROR\nV\n", undef, 0,
     'ERROR WHILE NOT COMMENTING', [BC_QUA], [BC_MSP, BC(0), BC(1), test_str('ERROR')],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)]],
    ['Comment 2', undef, '', "*578 Invalid bytecode pattern in NAME: PROBLEM\nV\n", undef, 578,
     '(Invalid code) WHILE NOT COMMENTING', [BC_QUA],
     [BC_MSP, BC(578), BC(2), test_str('NAME'), test_str('PROBLEM')],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)]],
    ['Compiler BUG 1', undef, '', "*774 Compiler error\nV\n", undef, 774,
     'BUG WHILE NOT BUG', [BC_QUA], [BC_BUG, BC(0)],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)]],
    ['Compiler BUG 2', undef, '', "*775 Unexplainable compiler error\nV\n", undef, 775,
     'BUG WHILE NOT BUG', [BC_QUA], [BC_BUG, BC(1)],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)]],
    ['WRITE IN 1', undef, 'TWO SIX', [1, "XXVI\n", "I\n"], undef, undef,
     'DO .2 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(2)],
     'DO WRITE IN .2 WHILE NOT WRITING IN', [BC_QUA], [BC_WIN, BC(1), BC_SPO, BC(2)],
     'DO READ OUT .2', [], [BC_ROU, BC(1), BC_SPO, BC(2)]],
    ['WRITE IN 2', undef, 'ABCD', [1, "ABCD\n", "EFGH\n"], undef, undef,
     'DO ,2 <- #7', [], [BC_STO, BC(7), BC_TAI, BC(2)],
     'DO ,2 SUB #1 <- #91', [], [BC_STO, BC(91), BC_SUB, BC(1), BC_TAI, BC(2)],
     'DO ,2 SUB #2 <- #95', [], [BC_STO, BC(95), BC_SUB, BC(2), BC_TAI, BC(2)],
     'DO ,2 SUB #3 <- #65', [], [BC_STO, BC(65), BC_SUB, BC(3), BC_TAI, BC(2)],
     'DO ,2 SUB #3 <- #77', [], [BC_STO, BC(77), BC_SUB, BC(4), BC_TAI, BC(2)],
     'DO ,2 SUB #4 <- #90', [], [BC_STO, BC(90), BC_SUB, BC(5), BC_TAI, BC(2)],
     'DO ,2 SUB #5 <- #84', [], [BC_STO, BC(84), BC_SUB, BC(6), BC_TAI, BC(2)],
     'DO WRITE IN ,2 WHILE NOT WRITING IN', [BC_QUA], [BC_WIN, BC(1), BC_TAI, BC(2)],
     'DO READ OUT ,2', [], [BC_ROU, BC(1), BC_TAI, BC(2)]],
    ['REINSTATE LABEL', undef, '', "II\nIV\nIV\n", undef, undef,
     'DO REINSTATE (1) WHILE ABSTAINING FROM IT', [BC_QUA], [BC_REL, BC(1)],
     '(1) DO NOT READ OUT #2', [BC_LAB, BC(1), BC_NOT], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['REINSTATE GERUND', undef, '', "II\nIV\n", undef, undef,
     'DO REINSTATE READING OUT WHILE ABSTAINING FROM IT', [BC_QUA], [BC_REG, BC(1), BC_ROU],
     'DO NOT READ OUT #2', [BC_NOT], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN FROM LABEL', undef, '', "II\nIV\nIV\n", undef, undef,
     'DO ABSTAIN FROM (1) WHILE REINSTATING IT', [BC_QUA], [BC_ABL, BC(1)],
     '(1) DO READ OUT #2', [BC_LAB, BC(1)], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN FROM GERUND', undef, '', "II\nIV\n", undef, undef,
     'DO ABSTAIN FROM READING OUT WHILE REINSTATING IT', [BC_QUA], [BC_ABG, BC(1), BC_ROU],
     '(1) DO READ OUT #2', [BC_LAB, BC(1)], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN + REINSTATE 1', undef, '', "II\n", undef, undef,
     'DO ABSTAIN FROM READING OUT', [], [BC_ABG, BC(1), BC_ROU],
     'DO REINSTATE (1) WHILE ABSTAINING FROM IT', [BC_QUA], [BC_REL, BC(1)],
     '(1) DO READ OUT #2', [BC_LAB, BC(1)], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN + REINSTATE 2', undef, '', "II\nII\nIV\n", undef, undef,
     'DO ABSTAIN FROM READING OUT WHILE REINSTATING IT', [BC_QUA], [BC_ABG, BC(1), BC_ROU],
     'DO REINSTATE (1)', [], [BC_REL, BC(1)],
     '(1) DO READ OUT #2', [BC_LAB, BC(1)], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN FROM QUANTUM COMPUTING 1', undef, '', "II\n", undef, undef,
     'DO ABSTAIN FROM QUANTUM COMPUTING', [], [BC_ABG, BC(1), BC_QUA],
     'DO ABSTAIN FROM READING OUT WHILE REINSTATING IT', [BC_QUA], [BC_ABG, BC(1), BC_ROU],
     'DO REINSTATE (1) WHILE ABSTAINING FROM IT', [BC_QUA], [BC_REL, BC(1)],
     '(1) DO READ OUT #2', [BC_LAB, BC(1)], [BC_ROU, BC(1), BC(2)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN FROM QUANTUM COMPUTING 2', undef, '', "IV\n", undef, undef,
     '(1) DO ABSTAIN FROM QUANTUM COMPUTING', [BC_LAB, BC(1)], [BC_ABG, BC(1), BC_QUA],
     'DO READ OUT #2', [], [BC_ROU, BC(1), BC(2)],
     'DO GIVE UP', [], [BC_GUP],
     'DO COME FROM (1) WHILE NOT COMING FROM THERE', [BC_QUA], [BC_CFL, BC(1)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['ABSTAIN FROM QUANTUM COMPUTING 3', undef, '', "II\nIV\nIV\n", undef, undef,
     '(1) DO ABSTAIN FROM QUANTUM COMPUTING WHILE REINSTATING IT',
      [BC_LAB, BC(1), BC_QUA], [BC_ABG, BC(1), BC_QUA],
     'DO READ OUT #2', [], [BC_ROU, BC(1), BC(2)],
     'DO GIVE UP', [], [BC_GUP],
     'DO COME FROM (1) WHILE NOT COMING FROM THERE', [BC_QUA], [BC_CFL, BC(1)],
     'DO READ OUT #4', [], [BC_ROU, BC(1), BC(4)]],
    ['STASH/RETRIEVE 1', undef, '', [1, "II\n", "*436 Register .1 stashed away too well\n"], undef, 436,
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO STASH .1 WHILE NOT STASHING IT', [BC_QUA], [BC_STA, BC(1), BC_SPO, BC(1)],
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO RETRIEVE .1', [], [BC_RET, BC(1), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['STASH/RETRIEVE 2', undef, '', [1, "A\n", "S\n"], undef, undef,
     'DO ,1 <- #3', [], [BC_STO, BC(3), BC_TAI, BC(1)],
     'DO ,1 SUB #1 <- #91', [], [BC_STO, BC(91), BC_SUB, BC(1), BC_TAI, BC(1)],
     'DO ,1 SUB #2 <- #95', [], [BC_STO, BC(95), BC_SUB, BC(2), BC_TAI, BC(1)],
     'DO ,1 SUB #3 <- #67', [], [BC_STO, BC(67), BC_SUB, BC(3), BC_TAI, BC(1)],
     'DO STASH ,1', [], [BC_STA, BC(1), BC_TAI, BC(1)],
     'DO ,1 SUB #3 <- #69', [], [BC_STO, BC(69), BC_SUB, BC(3), BC_TAI, BC(1)],
     'DO STASH ,1 WHILE NOT STASHING IT', [BC_QUA], [BC_STA, BC(1), BC_TAI, BC(1)],
     'DO ,1 SUB #3 <- #70', [], [BC_STO, BC(70), BC_SUB, BC(3), BC_TAI, BC(1)],
     'DO RETRIEVE ,1', [], [BC_RET, BC(1), BC_TAI, BC(1)],
     'DO READ OUT ,1', [], [BC_ROU, BC(1), BC_TAI, BC(1)]],
    ['IGNORE', undef, '', [1, "II\n", "IV\n"], undef, undef,
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO IGNORE .1 WHILE REMEMBERING IT', [BC_QUA], [BC_IGN, BC(1), BC_SPO, BC(1)],
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['REMEMBER', undef, '', [1, "IV\n", "II\n"], undef, undef,
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO REMEMBER .1 WHILE IGNORING IT', [BC_QUA], [BC_REM, BC(1), BC_SPO, BC(1)],
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['GIVE UP', undef, '', "II\nIV\n", undef, undef,
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO GIVE UP WHILE CONTINUING TO RUN', [BC_QUA], [BC_GUP],
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['MAKE BELONG', undef, '', [1, "IV\n", "*511 Register .2 does not belong to anything\n"], undef, 511,
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO MAKE .2 BELONG TO .1 WHILE LEAVING IT NOT BELONGING', [BC_QUA], [BC_MKB, BC_SPO, BC(2), BC_SPO, BC(1)],
     'DO $.2 <- #4', [], [BC_STO, BC(4), BC_BLM, BC(1), BC_SPO, BC(2)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['NO LONGER BELONG', undef, '', [1, "IV\n", "*511 Register .2 does not belong to anything\n"], undef, 511,
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO MAKE .2 BELONG TO .1', [], [BC_MKB, BC_SPO, BC(2), BC_SPO, BC(1)],
     'DO MSKE .2 NO LONGER BELONG TO .1 WHILE LETTING IT BELONG', [BC_QUA], [BC_NLB, BC_SPO, BC(2), BC_SPO, BC(1)],
     'DO $.2 <- #4', [], [BC_STO, BC(4), BC_BLM, BC(1), BC_SPO, BC(2)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['COME FROM LABEL', undef, '', "X\nI\nV\n", undef, undef,
     '(69) DO .1 <- #1', [BC_LAB, BC(69)], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO COME FROM (70)', [], [BC_CFL, BC(70)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO GIVE UP', [], [BC_GUP],
     'DO COME FROM (69) WHILE NOT COMING FROM THERE', [BC_QUA], [BC_CFL, BC(69)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     '(70) DO .1 <- #5', [BC_LAB, BC(70)], [BC_STO, BC(5), BC_SPO, BC(1)]],
    ['COME FROM GERUND', undef, '', "X\nI\nV\n", undef, undef,
     'DO %CF <- #2', [], [BC_STO, BC(2), reg_code('%CF')],
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO ABSTAIN FROM (99)', [], [BC_ABL, BC(99)],
     'DO COME FROM (70)', [], [BC_CFL, BC(70)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO GIVE UP', [], [BC_GUP],
     'DO COME FROM ABSTAINING WHILE NOT COMING FROM THERE', [BC_QUA], [BC_CFG, BC(2), BC_ABL, BC_ABG],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     '(70) DO .1 <- #5', [BC_LAB, BC(70)], [BC_STO, BC(5), BC_SPO, BC(1)]],
    ['NEXT', undef, '', "X\nI\n", undef, undef,
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO (69) NEXT WHILE NOT NEXTING', [BC_QUA], [BC_NXT, BC(69)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO GIVE UP', [], [BC_GUP],
     '(60) DO READ OUT .1', [BC_LAB, BC(69)], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['RESUME', undef, '', "I\nX\nV\n", undef, undef,
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO (69) NEXT', [], [BC_NXT, BC(69)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO GIVE UP', [], [BC_GUP],
     '(69) DO READ OUT .1', [BC_LAB, BC(69)], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO RESUME #1 WHILE NOT RESUMING', [BC_QUA], [BC_RES, BC(1)],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)]],
    ['FORGET', undef, '', "XX\nX\nXXX\n", undef, undef,
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO (69) NEXT', [], [BC_NXT, BC(69)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO GIVE UP', [], [BC_GUP],
     '(69) DO (70) NEXT', [BC_LAB, BC(69)], [BC_NXT, BC(70)],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO READ OUT #30', [], [BC_ROU, BC(1), BC(30)],
     'DO GIVE UP', [], [BC_GUP],
     '(70) DO READ OUT #20', [BC_LAB, BC(70)], [BC_ROU, BC(1), BC(20)],
     'DO FORGET #1 WHILE NOT FORGETTING', [BC_QUA], [BC_FOR, BC(1)],
     'DO RESUME #1', [], [BC_RES, BC(1)]],
    ['NEXT FROM LABEL', undef, '', "X\nII\nII\n", undef, undef,
     '(69) DO .1 <- #1', [BC_LAB, BC(69)], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO .1 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO GIVE UP', [], [BC_GUP],
     'DO NEXT FROM (69) WHILE NOT NEXTING FROM THERE', [BC_QUA], [BC_NXL, BC(69)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO RESUME #1', [], [BC_RES, BC(1)]],
    ['NEXT FROM GERUND', undef, '', [1, "X\n", "III\n", "V\n"], undef, undef,
     'DO %CF <- #2', [], [BC_STO, BC(2), reg_code('%CF')],
     'DO .1 <- #3', [], [BC_STO, BC(3), BC_SPO, BC(1)],
     'DO ABSTAIN FROM (99)', [], [BC_ABL, BC(99)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO GIVE UP', [], [BC_GUP],
     'DO NEXT FROM ABSTAINING WHILE NOT NEXTING FROM THERE', [BC_QUA], [BC_NXG, BC(2), BC_ABL, BC_ABG],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO .1 <- #5', [], [BC_STO, BC(5), BC_SPO, BC(1)],
     'DO RESUME #1', [], [BC_RES, BC(1)]],
    ['STUDY', undef, '', [1, "M\n", "MM\n"], undef, undef,
     'DO STUDY #1 AT (1000) IN CLASS @2', [], [BC_STU, BC(1), BC(1000), BC_WHP, BC(2)],
     'DO STUDY #1 AT (2000) IN CLASS @2 WHILE NOT STUDYING IT', [BC_QUA], [BC_STU, BC(1), BC(2000), BC_WHP, BC(2)],
     'DO READ OUT @2 SUB #1', [], [BC_ROU, BC(1), BC_SUB, BC(1), BC_WHP, BC(2)]],
    ['ENROL', undef, '', "*603 Class war between \@1 and \@2\nM\n", undef, 603,
     'DO STUDY #1 AT (1000) IN CLASS @1', [], [BC_STU, BC(1), BC(1000), BC_WHP, BC(1)],
     'DO STUDY #2 AT (1000) IN CLASS @1', [], [BC_STU, BC(2), BC(1000), BC_WHP, BC(1)],
     'DO STUDY #1 AT (2000) IN CLASS @2', [], [BC_STU, BC(1), BC(2000), BC_WHP, BC(2)],
     'DO STUDY #3 AT (2000) IN CLASS @2', [], [BC_STU, BC(3), BC(2000), BC_WHP, BC(2)],
     'DO ENROL .1 TO LEARN #1 + #2', [], [BC_ENR, BC(2), BC(1), BC(2), BC_SPO, BC(1)],
     'DO ENROL .1 TO LEARN #1 + #3 WHILE NOT ENROLLING', [BC_QUA], [BC_ENR, BC(2), BC(1), BC(3), BC_SPO, BC(1)],
     'DO .1 LEARNS #1', [], [BC_LEA, BC(1), BC_SPO, BC(1)],
     'DO READ OUT @2 SUB #3', [], [BC_ROU, BC(1), BC_SUB, BC(3), BC_WHP, BC(2)],
     '(1000) DO READ OUT @1 SUB #1', [BC_LAB, BC(1000)], [BC_ROU, BC(1), BC_SUB, BC(1), BC_WHP, BC(1)]],
    ['LEARNS', undef, '', "M\nII\n", undef, undef,
     'DO STUDY #1 AT (1000) IN CLASS @1', [], [BC_STU, BC(1), BC(1000), BC_WHP, BC(1)],
     'DO ENROL .1 TO LEARN #1', [], [BC_ENR, BC(1), BC(1), BC_SPO, BC(1)],
     'DO .1 LEARNS #1 WHILE NOT LEARNING IT', [BC_QUA], [BC_LEA, BC(1), BC_SPO, BC(1)],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO READ OUT #2', [], [BC_ROU, BC(1), BC(2)],
     'DO GIVE UP', [], [BC_GUP],
     '(1000) DO READ OUT @1 SUB #1', [BC_LAB, BC(1000)], [BC_ROU, BC(1), BC_SUB, BC(1), BC_WHP, BC(1)]],
    ['FINISH LECTURE', undef, '', "M\nV\nII\n", undef, undef,
     'DO STUDY #1 AT (1000) IN CLASS @1', [], [BC_STU, BC(1), BC(1000), BC_WHP, BC(1)],
     'DO ENROL .1 TO LEARN #1', [], [BC_ENR, BC(1), BC(1), BC_SPO, BC(1)],
     'DO .1 LEARNS #1', [], [BC_LEA, BC(1), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO GIVE UP', [], [BC_GUP],
     '(1000) DO READ OUT @1 SUB #1', [BC_LAB, BC(1000)], [BC_ROU, BC(1), BC_SUB, BC(1), BC_WHP, BC(1)],
     'DO $@1 <- #5', [], [BC_STO, BC(5), BC_BLM, BC(1), BC_WHP, BC(1)],
     'DO FINISH LECTURE WHILE CONTINUING IT', [BC_QUA], [BC_FIN],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO READ OUT #2', [], [BC_ROU, BC(1), BC(2)]],
    ['GRADUATES', undef, '', "*822 Register .1 is not a student\nM\n", undef, 822,
     'DO STUDY #1 AT (1000) IN CLASS @1', [], [BC_STU, BC(1), BC(1000), BC_WHP, BC(1)],
     'DO ENROL .1 TO LEARN #1', [], [BC_ENR, BC(1), BC(1), BC_SPO, BC(1)],
     'DO .1 GRADUATES WHILE REMAINING A STUDENT', [BC_QUA], [BC_GRA, BC_SPO, BC(1)],
     'DO .1 LEARNS #4', [], [BC_LEA, BC(1), BC_SPO, BC(1)],
     '(1000) DO READ OUT @1 SUB #1', [BC_LAB, BC(1000)], [BC_ROU, BC(1), BC_SUB, BC(1), BC_WHP, BC(1)]],
    ['SWAP', undef, '', "XX\nXX\nV\nX\n", undef, undef,
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO SWAP RESUME EXPRESSION AND FORGET EXPRESSION WHILE LEAVING THEM UNCHANGED',
      [BC_QUA], [BC_SWA, BC_RES, BC_FOR],
     'DO (69) NEXT', [], [BC_NXT, BC(69)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO GIVE UP', [], [BC_GUP],
     '(69) DO (70) NEXT', [BC_LAB, BC(69)], [BC_NXT, BC(70)],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)],
     'DO GIVE UP', [], [BC_GUP],
     '(70) DO READ OUT #20', [BC_LAB, BC(70)], [BC_ROU, BC(1), BC(20)],
     'DO RESUME #1', [], [BC_RES, BC(1)],
     'DO FORGET #1', [], [BC_FOR, BC(1)]],
    ['CONVERT', undef, '', "XX\nXX\nX\nV\n", undef, undef,
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO CONVERT FORGET EXPRESSION TO RESUME EXPRESSION WHILE LEAVING IT UNCHANGED',
      [BC_QUA], [BC_CON, BC_FOR, BC_RES],
     'DO (69) NEXT', [], [BC_NXT, BC(69)],
     'DO GIVE UP', [], [BC_GUP],
     '(69) DO (70) NEXT', [BC_LAB, BC(69)], [BC_NXT, BC(70)],
     'DO READ OUT #10', [], [BC_ROU, BC(1), BC(10)],
     'DO GIVE UP', [], [BC_GUP],
     '(70) DO READ OUT #20', [BC_LAB, BC(70)], [BC_ROU, BC(1), BC(20)],
     'DO FORGET #1', [], [BC_FOR, BC(1)],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO NOT GIVE UP', [BC_NOT], [BC_GUP],
     'DO READ OUT #5', [], [BC_ROU, BC(1), BC(5)]],
    ['DESTROY', 'sick', '', "II\nII\n*000 DO .1 <- #-8\nII\n", undef, 0,
     # extend sick to have another name for unary division, then destroy original
     'DO CREATE ?UNARY ,D, AS [UDV]', [],
     [BC_CRE, BC(1), test_str('UNARY'), BC(1), BC(0), BC(1), test_str('D'),
      BC(1), BC(4), BC(1), BC_UDV],
     'DO DESTROY ?UNARY ,#45, WHILE NOT DESTROYING IT', [BC_QUA],
     [BC_DES, BC(1), test_str('UNARY'), BC(1), BC(0), BC(1), test_str('-')],
     'DO .1 <- #D8', [], [BC_STO, BC_UDV, BC(8), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)],
     'DO .1 <- #-8', [], [BC_STO, BC_UDV, BC(8), BC_SPO, BC(1)],
     'DO READ OUT .1', [], [BC_ROU, BC(1), BC_SPO, BC(1)]],
    ['CREATE', '1972', '', [1, "\nII\n", "*000 DO .2 <- #D2\n"], undef, 0,
     # extend the 1972 compiler with Unary Division and call it D
     'DO CREATE ?UNARY ,D, AS [UDV] +  WHILE NOT CREATING IT', [BC_QUA],
     [BC_CRE, BC(1), test_str('UNARY'), BC(1), BC(0), BC(1), test_str('D'),
      BC(1), BC(4), BC(1), BC_UDV],
     'DO .2 <- #D2', [], [BC_MSP, BC(0), BC(1), test_str('DO .1 <- #D3')],
     'DO READ OUT .2', [], [BC_ROU, BC(1), BC_SPO, BC(2)]],
    ['DIVERSION', undef, '', [1, "X\nXI\nXII\n", "V\nVI\nVII\n"], undef, undef,
     'DO CLOSE OFF BETWEEN (1) AND (2) AND DIVERT VIA (3) TO (4) WHILE KEEPING IT OPEN',
     [BC_QUA], [BC_DIV, BC(1), BC(2), BC(3), BC(4)],
     '(1) DO .1 <- #5', [BC_LAB, BC(1)], [BC_STO, BC(5), BC_SPO, BC(1)],
     'DO .2 <- #6', [], [BC_STO, BC(6), BC_SPO, BC(2)],
     'DO .3 <- #7', [], [BC_STO, BC(7), BC_SPO, BC(3)],
     '(2) DO READ OUT .1 + .2 + .3', [BC_LAB, BC(2)], [BC_ROU, BC(3), BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)],
     'PLEASE GIVE UP', [], [BC_GUP],
     '(3) DO .4 <- #10', [BC_LAB, BC(3)], [BC_STO, BC(10), BC_SPO, BC(4)],
     'DO .5 <- #11', [], [BC_STO, BC(11), BC_SPO, BC(5)],
     'DO .6 <- #12', [], [BC_STO, BC(12), BC_SPO, BC(6)],
     '(4) DO READ OUT .4 + .5 + .6', [BC_LAB, BC(4)], [BC_ROU, BC(3), BC_SPO, BC(4), BC_SPO, BC(5), BC_SPO, BC(6)]],
    ['REOPENING', undef, '', [1, "X\nXI\nXII\n", "V\nVI\nVII\n"], undef, undef,
     'DO CLOSE OFF BETWEEN (1) AND (2) AND DIVERT VIA (3) TO (4)', [], [BC_DIV, BC(1), BC(2), BC(3), BC(4)],
     'DO REOPEN BETWEEN (1) AND (2) WHILE KEEPING IT CLOSED', [BC_QUA], [BC_REO, BC(1), BC(2)],
     '(1) DO .1 <- #5', [BC_LAB, BC(1)], [BC_STO, BC(5), BC_SPO, BC(1)],
     'DO .2 <- #6', [], [BC_STO, BC(6), BC_SPO, BC(2)],
     'DO .3 <- #7', [], [BC_STO, BC(7), BC_SPO, BC(3)],
     '(2) DO READ OUT .1 + .2 + .3', [BC_LAB, BC(2)], [BC_ROU, BC(3), BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)],
     'PLEASE GIVE UP', [], [BC_GUP],
     '(3) DO .4 <- #10', [BC_LAB, BC(3)], [BC_STO, BC(10), BC_SPO, BC(4)],
     'DO .5 <- #11', [], [BC_STO, BC(11), BC_SPO, BC(5)],
     'DO .6 <- #12', [], [BC_STO, BC(12), BC_SPO, BC(6)],
     '(4) DO READ OUT .4 + .5 + .6', [BC_LAB, BC(4)], [BC_ROU, BC(3), BC_SPO, BC(4), BC_SPO, BC(5), BC_SPO, BC(6)]],
    ['TRICKLE DOWN 1', undef, '', [1, "I\nI\nI\n", "IV\nI\nIII\n"], undef, undef,
     # check that a quantum assignment to a register which will trickle down
     # is an all-or-nothing thing; however, it's complicated
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO .3 <- #3', [], [BC_STO, BC(3), BC_SPO, BC(3)],
     'DO TRICKLE .1 DOWN TO .3 AFTER #5', [],
	[BC_TRD, BC_SPO, BC(1), BC(5), BC(1), BC_SPO, BC(3)],
     'DO TRICKLE .3 DOWN TO .2 AFTER #5', [],
	[BC_TRD, BC_SPO, BC(3), BC(5), BC(1), BC_SPO, BC(2)],
     'DO .1 <- #1 WHILE NOT ASSIGNING TO IT', [BC_QUA], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO .2 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(2)],
     # The trickling down during a quantum assignment also makes .3 unshared
     # But .2 remains shared (the new Quantum emulator will behave differently here)
     '(2) PLEASE COME FROM .2', [BC_LAB, BC(2)], [BC_CFL, BC_SPO, BC(2)],
     'DO READ OUT .1 + .2 + .3', [], [BC_ROU, BC(3), BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)]],
    ['TRICKLE DOWN 2', undef, '', [1, "I\nI\nI\n", "I\nI\nIII\n"], undef, undef,
     # now check an actual quantum trickle down
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO .3 <- #3', [], [BC_STO, BC(3), BC_SPO, BC(3)],
     'DO TRICKLE .1 DOWN TO .3 AFTER #5 WHILE LEAVING IT TRUSSED UP', [BC_QUA],
	[BC_TRD, BC_SPO, BC(1), BC(5), BC(1), BC_SPO, BC(3)],
     'DO TRICKLE .3 DOWN TO .2 AFTER #5', [],
	[BC_TRD, BC_SPO, BC(3), BC(5), BC(1), BC_SPO, BC(2)],
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO .2 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(2)],
     # The quantum trickling down during also makes .3 unshared
     # But .2 remains shared (the new Quantum emulator will behave differently here)
     '(2) PLEASE COME FROM .2', [BC_LAB, BC(2)], [BC_CFL, BC_SPO, BC(2)],
     'DO READ OUT .1 + .2 + .3', [], [BC_ROU, BC(3), BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)]],
    ['TRUSS UP', undef, '', [1, "I\nI\nI\n", "I\nI\nIII\n"], undef, undef,
     # same as previous test, but instead of a Quantum TRICKE DOWN
     # we do a classical one followed by a Quantum TRUSS UP
     'DO .1 <- #4', [], [BC_STO, BC(4), BC_SPO, BC(1)],
     'DO .3 <- #3', [], [BC_STO, BC(3), BC_SPO, BC(3)],
     'DO TRICKLE .1 DOWN TO .3 AFTER #5', [],
	[BC_TRD, BC_SPO, BC(1), BC(5), BC(1), BC_SPO, BC(3)],
     'DO TRICKLE .3 DOWN TO .2 AFTER #5', [],
	[BC_TRD, BC_SPO, BC(3), BC(5), BC(1), BC_SPO, BC(2)],
     'DO TRUSS .1 + .3 UP WHILE LEAVING THEM TRICKING DOWN', [BC_QUA],
	[BC_TRU, BC(2), BC_SPO, BC(1), BC_SPO, BC(3)],
     'DO .1 <- #1', [], [BC_STO, BC(1), BC_SPO, BC(1)],
     'DO .2 <- #2', [], [BC_STO, BC(2), BC_SPO, BC(2)],
     # now to figure out what happens... all registers are still shared with
     # the exception of the trickling down structure of .1 and .3; so
     # both threads see .1 trickle down to .3 and then .2 because one thread
     # does the assignment but the other sees the same values
     # Obviously the new quantum emulator will do things differently here
     '(2) PLEASE COME FROM .2', [BC_LAB, BC(2)], [BC_CFL, BC_SPO, BC(2)],
     'DO READ OUT .1 + .2 + .3', [], [BC_ROU, BC(3), BC_SPO, BC(1), BC_SPO, BC(2), BC_SPO, BC(3)]],
);

test_bc(@all_tests);

