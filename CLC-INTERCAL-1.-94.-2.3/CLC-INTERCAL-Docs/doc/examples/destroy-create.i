PLEASE NOTE: an example of using DESTROY and CREATE to modify some statements

      DO DESTROY ?E_LIST ?EXPRESSION=1 ,#43, ?E_LIST=*
      DO .1 <- #1
      DO .2 <- #2
      DO COME FROM (3)
  (1) DO READ OUT .1 + .2
      PLEASE GIVE UP
  (2) DO COME FROM (1)
      DO .1 <- #3
      DO .2 <- #4
      DO CREATE ?E_LIST ?EXPRESSION=1 ,#43, ?E_LIST=* AS ?EXPRESSION #1 + ?E_LIST #1
  (3) PLEASE ABSTAIN FROM (2)

PLEASE NOTE: E_LIST is a list of expressions separated by intersections;
the DESTROY removes the production which accepts "expression intersection
list" so the only remaining possibility is a single expression rather
than a list: therefore the READ OUT only takes one register, .1, and
that produces "I", Before the extra "+ .2" can cause an error, the COME
FROM makes execution proceed from (2) instead, where the CREATE statement
puts the missing rule back in place, so the second time the READ OUT
is executed it has a list or two registers and produces "III" and "IV";
since the NEXT FROM is now ABSTAINed FROM, execution continues to the
GIVE UP.

In summary: this produces I III IV because the two times the READ OUT
statment is executed it takes a different number of registers. Neat eh?

