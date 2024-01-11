	PLEASE NOTE: This program demonstrates that reinstating and not
	reinstating can happen in the same state

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO REINSTATE (1) WHILE ABSTAINING FROM IT
(2)	DO .1 <- #1
	DO .1 <- #2
(1)	PLEASE DON'T COME FROM (2)
	DO READ OUT .1
	DO REINSTATE (3) WHILE ABSTAINING FROM IT
(3)	PLEASE DON'T .1 <- .1 ¢ .1
	DO READ OUT .1
	DO GIVE UP

	PLEASE NOTE: we aren't going to tell you what this program produces;
	there's a race condition and we don't actually know.

