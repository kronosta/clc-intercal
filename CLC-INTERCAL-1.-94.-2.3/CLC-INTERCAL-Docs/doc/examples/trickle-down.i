PLEASE NOTE: This program demonstrates trickling of values to program a fixed delay

        DO TRICKLE .1 DOWN TO .2 AFTER #1000
        DO .2 <- #2
        DO READ OUT #1
        PLEASE .1 <- #1
(2)     DO COME FROM .2
        PLEASE READ OUT #2
        DO GIVE UP

PLEASE NOTE: The program starts by reading out "I" then waits one second
(#1000 milliseconds) and then reads out "II".  This is because the COME
FROM will keep the thing blocked while .2 contains #2 but unblocks when
the assignment of #1 to .1 trickles down to .2.  (Note that the COME FROM
actually triggers a suspend and not an actual loop due to internal
optimisations, as can be seen by running the program with tracing)

