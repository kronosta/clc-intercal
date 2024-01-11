	PLEASE NOTE: THIS PROGRAM DEMONSTRATES THE USE OF QUANTUM ASSIGNMENT.
		     REQUIRES CLC-INTERCAL 1.-94 OR NEWER

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO .1 <- #1
	DO .1 <- #2 WHILE NOT ASSIGNING TO IT
	DO READ OUT .1           DO NOTE: THIS READS "I" OR "II"
	DO .1 <- .1 ¢ .1
	DO READ OUT .1           DO NOTE: THIS READS "III" OR "XII"
	PLEASE GIVE UP

	PLEASE NOTE: THE OUTPUT WILL BE "I", "III" INTERLEAVED WITH "II", "XII"

