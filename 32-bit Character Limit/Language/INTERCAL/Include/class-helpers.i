	PLEASE NOTE: THIS LIBRARY ADDS A NUMBER OF "CLASS HELPERS" TO A PROGRAM

Copyright (c) 2023 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

PERVERSION "CLC-INTERCAL/Base INTERCAL/Include/class-helpers.i 1.-94.-2.2"

After loading this object, a program will be able to enrol a register to
study a number of subjects; all these subjects are taught in class @65535,
with subject numbers 64512 and above, so if any other class teaches them you
may get a runtime error. Registers with number 65520 or higher are reserved
for use by the class; it may be possible to use them, but there is no
guarantee.

        PLEASE NOTE: Subject 64512: Increment a spot value
        DO STUDY #64512 AT (61440) IN CLASS @65535

        PLEASE NOTE: Subject 64513: Increment a two-spot value
        DO STUDY #64513 AT (61446) IN CLASS @65535

        PLEASE NOTE: Subject 64528: Decrement a spot value
        DO STUDY #64528 AT (61443) IN CLASS @65535

        PLEASE NOTE: Subject 64529: Decrement a teo-spot value
        DO STUDY #64529 AT (61449) IN CLASS @65535

	DO GIVE UP

        PLEASE NOTE: Subject 64512: Increment a spot value
(61440) PLEASE STASH .65530 + .65531 + .65532
        DO .65530 <- $@65535 ~ #65535
        DO .65531 <- #1
        PLEASE COME FROM (61441)
        DO .65532 <- .65530 ~ #1
        DO .65532 <- '.65532 ¢ .65532' ~ #3
        DO .65532 <- '.65532 ¢ .65532' ~ #15
        DO .65532 <- '.65532 ¢ .65532' ~ #255
        DO .65532 <- '.65532 ¢ .65532' ~ #65535
(61442) DO .65532 <- #61442 ~ .65532
        DO $@65535 <- "¥ '.65531 ¢ "$@65535 ~ #65535"'" ~ '#0 ¢ #65535'
        PLEASE RETRIEVE .65530 + .65531 + .65532
        PLEASE FINISH LECTURE
        PLEASE COME FROM .65532
        DO .65532 <- #0
        DO .65530 <- .65530 ~ #65534
(61441) DO .65531 <- '.65531 ¢ #1' ~ '#65535 ¢ #1'

        PLEASE NOTE: Subject 64528: Decrement a spot value
(61443) PLEASE STASH .65530 + .65531 + .65533
        DO .65530 <- $@65535 ~ #65535
        DO .65531 <- #1
        PLEASE COME FROM (61444)
        DO .65533 <- .65530 ~ #1
        DO .65533 <- '.65533 ¢ .65533' ~ #3
        DO .65533 <- '.65533 ¢ .65533' ~ #15
        DO .65533 <- '.65533 ¢ .65533' ~ #255
        DO .65533 <- '.65533 ¢ .65533' ~ #65535
(61445) DO .65533 <- #61445 ~ .65533
        DO .65533 <- #0
        DO .65530 <- .65530 ~ #65534
(61444) DO .65531 <- '.65531 ¢ #1' ~ '#65535 ¢ #1'
        PLEASE COME FROM .65533
        DO $@65535 <- "¥ '.65531 ¢ "$@65535 ~ #65535"'" ~ '#0 ¢ #65535'
        PLEASE RETRIEVE .65530 + .65531 + .65533
        PLEASE FINISH LECTURE

        PLEASE NOTE: Subject 64513: Increment a two-spot value
(61446) PLEASE STASH .65528 + .65529 + .65534
        DO .65528 <- $@65535 ~ #65535
        DO .65529 <- $@65535 ~ '#65280¢#65280'
(61447) DO .65534 <- #61447 ~ .&&&&&&&&&&&&&&&&65528
(61448) PLEASE MAKE .65534 BELONG TO .65528
        PLEASE COME FROM .65534
        PLEASE MAKE .65534 BELONG TO .65529
        DO .65528 <- #0
        PLEASE COME FROM (61448)
        DO ENROL $.65534 TO LEARN #64512
        DO $.65534 LEARNS #64512
        DO $.65534 GRADUATES
        PLEASE MAKE .65534 NO LONGER BELONG TO $.65534
        PLEASE NOTE: the next line is self-explanatory
        DO $@65535 <- '"'"'.65529 ~ #32768' ¢ '.65528 ~ #32768'" ¢ "'.65529 ~ #128' ¢ '.65528 ~ #128'"' ¢ '"'.65529 ~ #2048' ¢ '.65528 ~ #2048'" ¢ "'.65529 ~ #8' ¢ '.65528 ~ #8'"'" ¢ "'"'.65529 ~ #8192' ¢ '.65528 ~ #8192'" ¢ "'.65529 ~ #32' ¢ '.65528 ~ #32'"' ¢ '"'.65529 ~ #512' ¢ '.65528 ~ #512'" ¢ "'.65529 ~ #2' ¢ '.65528 ~ #2'"'"' ¢ '"'"'.65529 ~ #32768' ¢ '.65528 ~ #32768'" ¢ "'.65529 ~ #64' ¢ '.65528 ~ #64'"' ¢ '"'.65529 ~ #1024' ¢ '.65528 ~ #1024'" ¢ "'.65529 ~ #4' ¢ '.65528 ~ #4'"'" ¢ "'"'.65529 ~ #4096' ¢ '.65528 ~ #4096'" ¢ "'.65529 ~ #16' ¢ '.65528 ~ #16'"' ¢ '"'.65529 ~ #256' ¢ '.65528 ~ #256'" ¢ "'.65529 ~ #1' ¢ '.65528 ~ #1'"'"'
        PLEASE RETRIEVE .65528 + .65529 + .65534
        PLEASE FINISH LECTURE

        PLEASE NOTE: Subject 64514: Decrement a two-spot value
(61449) PLEASE STASH .65528 + .65529 + .65535
        DO .65528 <- $@65535 ~ #65535
        DO .65529 <- $@65535 ~ '#65280¢#65280'
        DO .65535 <- '.65528 ~ .65528' ~ #1
(61450) DO .65535 <- #61450 ~ .VVVVVVVVVVVVVVVV65535
        DO .65528 <- #65535
(61451) PLEASE MAKE .65535 BELONG TO .65529
        PLEASE COME FROM .65535
        PLEASE MAKE .65535 BELONG TO .65528
        PLEASE COME FROM (61451)
        DO ENROL $.65535 TO LEARN #64528
        DO $.65535 LEARNS #64528
        DO $.65535 GRADUATES
        PLEASE MAKE .65535 NO LONGER BELONG TO $.65535
        PLEASE NOTE: the next line is self-explanatory
        DO $@65535 <- '"'"'.65529 ~ #32768' ¢ '.65528 ~ #32768'" ¢ "'.65529 ~ #128' ¢ '.65528 ~ #128'"' ¢ '"'.65529 ~ #2048' ¢ '.65528 ~ #2048'" ¢ "'.65529 ~ #8' ¢ '.65528 ~ #8'"'" ¢ "'"'.65529 ~ #8192' ¢ '.65528 ~ #8192'" ¢ "'.65529 ~ #32' ¢ '.65528 ~ #32'"' ¢ '"'.65529 ~ #512' ¢ '.65528 ~ #512'" ¢ "'.65529 ~ #2' ¢ '.65528 ~ #2'"'"' ¢ '"'"'.65529 ~ #32768' ¢ '.65528 ~ #32768'" ¢ "'.65529 ~ #64' ¢ '.65528 ~ #64'"' ¢ '"'.65529 ~ #1024' ¢ '.65528 ~ #1024'" ¢ "'.65529 ~ #4' ¢ '.65528 ~ #4'"'" ¢ "'"'.65529 ~ #4096' ¢ '.65528 ~ #4096'" ¢ "'.65529 ~ #16' ¢ '.65528 ~ #16'"' ¢ '"'.65529 ~ #256' ¢ '.65528 ~ #256'" ¢ "'.65529 ~ #1' ¢ '.65528 ~ #1'"'"'
        PLEASE RETRIEVE .65528 + .65529 + .65535
        PLEASE FINISH LECTURE

