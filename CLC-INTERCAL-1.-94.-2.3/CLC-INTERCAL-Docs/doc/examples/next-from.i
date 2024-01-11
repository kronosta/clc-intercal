PLEASE NOTE: This program demonstrates the use of "NEXT FROM"

Copyright (c) 2023 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

        DO .1 <- #1
(1)     DO .2 <- #2
        PLEASE READ OUT .1 + .2
        DO GIVE UP

        PLEASE NEXT FROM (1)
        DO .2 <- #42
        DO RESUME .1

PLEASE NOTE: What happens here is that after the second calculation the
"NEXT FROM (1)" triggers so register .2 gets a new value; after that, the
program resumes so that it READs OUT "I" and "XLII"

