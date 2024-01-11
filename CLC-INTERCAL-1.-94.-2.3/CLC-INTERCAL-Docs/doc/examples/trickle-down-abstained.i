PLEASE NOTE: This program demonstrates ABSTAINing FROM trickling of values

    DO ABSTAIN FROM TRICKLING DOWN
    DO TRICKLE .1 DOWN TO .2 AFTER #1000
    DO .1 <- #1
    PLEASE REINSTATE TRICKLING DOWN
    DO .1 <- #2
    DO .2 <- #1
    DO READ OUT .2
(1) DO COME FROM .2
    DO READ OUT .2
    PLEASE GIVE UP

Please note: the program produces "I", then waits 2 seconds and produces "II".
The ABSTAIN FROM controls the triggering of trickling down by assignments, not
the execution of TRICKLE DOWN statements.  As a result, the statement does run
and sets up a trickle down structure; the first assignment does not trigger a
trickle down, because it's ABSTAINed FROM; the second assgnemt triggers it
because it has been REINSTATEd.

