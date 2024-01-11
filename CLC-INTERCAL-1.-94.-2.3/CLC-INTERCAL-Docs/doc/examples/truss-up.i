PLEASE NOTE: This program demonstrates trickling and trussing

        DO TRICKLE .1 DOWN TO .2 + .3 AFTER #1000
        DO .2 <- #2
        PLEASE .1 <- #1
        DO TRUSS .1 UP
        DO .1 <- #3
        DO READ OUT #1
(2)     DO COME FROM .2
        PLEASE READ OUT #2
(3)     DO COME FROM .3
        DO GIVE UP

PLEASE NOTE: The program starts by reading out "I" then waits one second
(#1000 milliseconds) and then reads out "II".  This is because the COME
FROM will keep the thing blocked while .2 contains #2 but unblocks when
the assignment of #1 to .1 trickles down to .2. The second assignment
to .1 does not trickle down, so that the second "loop" does not execute.

(Note that the COME FROM actually triggers a suspend and not an actual
loop due to internal optimisations, as can be seen by running the program
with tracing)

