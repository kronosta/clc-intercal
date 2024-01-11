        PLEASE NOTE: A class to teach how to increment and decrement a spot number

        This is the example program at the end of lectures.html

        Subject #1 increments the student by 1; subject #2 decrements it

        In this example, .1 learns #1 once and then #2 twice, so it starts from
        #1001 and ends up at #1000; .2 learns #1 a total of 6 times, and #2 twice,
        so it goes from #1234 to #1238; therefore the program reads out
        MCCXXXVIII and M.

        PLEASE STUDY #1 AT (1000) IN CLASS @1
        PLEASE STUDY #2 AT (2000) IN CLASS @1

        PLEASE ENROL .1 TO LEARN #1
        PLEASE ENROL .2 TO LEARN #1 + #2

        DO .1 <- #1001
        DO .2 <- #1234
        PLEASE .2 LEARNS #1
        DO .2 LEARNS #1
        DO .1 LEARNS #1
        DO .2 LEARNS #1
        DO .2 LEARNS #2
        DO .2 LEARNS #1
        PLEASE .2 LEARNS #1
        DO .1 LEARNS #2
        DO .1 LEARNS #2
        DO .2 LEARNS #1
        DO .2 LEARNS #2
        DO READ OUT .2
        PLEASE READ OUT .1
        DO GIVE UP

(1000)  PLEASE STASH .65530 + .65531 + .65532
        DO .65530 <- $@1 ~ #65535
        DO .65531 <- #1
        PLEASE COME FROM (1001)
        DO .65532 <- .65530 ~ #1
        DO .65532 <- '.65532 ¢ .65532' ~ #3
        DO .65532 <- '.65532 ¢ .65532' ~ #15
        DO .65532 <- '.65532 ¢ .65532' ~ #255
        DO .65532 <- '.65532 ¢ .65532' ~ #65535
(1002)  DO .65532 <- #1002 ~ .65532
        DO $@1 <- "¥ '.65531 ¢ "$@1 ~ #65535"'" ~ '#0 ¢ #65535'
        PLEASE RETRIEVE .65530 + .65531 + .65532
        PLEASE FINISH LECTURE
        PLEASE COME FROM .65532
        DO .65532 <- #0
        DO .65530 <- .65530 ~ #65534
(1001)  DO .65531 <- '.65531 ¢ #1' ~ '#65535 ¢ #1'

(2000)  PLEASE STASH .65530 + .65531 + .65533
        DO .65530 <- $@1 ~ #65535
        DO .65531 <- #1
        PLEASE COME FROM (2001)
        DO .65533 <- .65530 ~ #1
        DO .65533 <- '.65533 ¢ .65533' ~ #3
        DO .65533 <- '.65533 ¢ .65533' ~ #15
        DO .65533 <- '.65533 ¢ .65533' ~ #255
        DO .65533 <- '.65533 ¢ .65533' ~ #65535
(2002)  DO .65533 <- #2002 ~ .65533
        DO .65533 <- #0
        DO .65530 <- .65530 ~ #65534
(2001)  DO .65531 <- '.65531 ¢ #1' ~ '#65535 ¢ #1'
        PLEASE COME FROM .65533
        DO $@1 <- "¥ '.65531 ¢ "$@1 ~ #65535"'" ~ '#0 ¢ #65535'
        PLEASE RETRIEVE .65530 + .65531 + .65533
        PLEASE FINISH LECTURE

