PLEASE NOTE: an example of using DESTROY and CREATE to modify some statements

      DO DESTROY ?E_LIST ?EXPRESSION=1 ,#43, ?E_LIST=*
      DO CREATE ?E_LIST ?EXPRESSION=1 ,#43, ?E_LIST=0 AS ?EXPRESSION #1
      DO .1 <- #1
      DO .2 <- #2
  (3) DO .3 <- #3
      PLEASE NEXT FROM (3)
  (1) DO READ OUT .1 + .2 + .3
      PLEASE GIVE UP
  (2) DO NEXT FROM (1)
      DO .1 <- #4
      DO .2 <- #5
      DO .3 <- #6
      DO DESTROY ?E_LIST ?EXPRESSION=1 ,#43, ?E_LIST=0
      DO CREATE ?E_LIST ?EXPRESSION=1 ,#43, ?E_LIST=* AS ?EXPRESSION #1 + ?E_LIST #1
      DO ABSTAIN FROM (2)
      DO RESUME #2

PLEASE NOTE: E_LIST is a list of expressions separated by intersections;
the DESTROY removes the production which accepts "expression intersection
list" however the CREATE introduces a new version which parses it but
discards all but the first expression: therefore by the time the READ
OUT gets to execute, it produces just one value: "I". It then immediately
triggers the NEXT FROM which puts the grammar back the way it found it,
then RESUMES to repeat the READ OUT - except that this time it has all
three registers and produces "IV V VI". So the same statement has one
registers once and three registers the next time.

In summary: this produces I IV V VI because the two times the READ OUT
statment is executed it takes a different number of registers. Neat eh?

