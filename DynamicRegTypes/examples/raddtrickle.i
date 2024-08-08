DO NOTE: 
   This will not work with custom register types.
   This program in its current state never exits the come from loop,
   while if you change a7 to .7 the program will run, print "CVII" 
   and then throw an error because you can't assign a crawling horror
   register to a spot.

DO a7 <- #0
DO .1 <- #5
DO TRICKLE a7 DOWN TO .1 AFTER #1
DO a7 <- #107
(5) DO COME FROM .1
DO ABSTAIN FROM (5)
DO REINSTATE (107)
DO READ OUT .1
DO a7 <- _1
(107) DO NOT COME FROM .1
DO READ OUT .1
DO GIVE UP 