	PLEASE NOTE: This program demonstrates quantum GIVE UP, which is
		     available to all versions of CLC-INTERCAL since 1.-94

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO .1 <- #1234
	DO GIVE UP WHILE CONTINUING TO RUN
	DO READ OUT .1
	DO GIVE UP WHILE CONTINUING TO RUN
	DO .1 <- #5678
	DO READ OUT .1
	PLEASE GIVE UP DON'T KEEP RUNNING THIS PROGRAM

	Just one word of explanation: if the program has (like this one)
	a single compilation unit, quantum GIVE UP is just a no-op.
	However, if there are multiple compilation units, this is not
	the case, because GIVE UP will go the the next main program
	in sequence, and only exits from the last one (this is a somewhat
	nonlinear sequence, if previous programs have COME FROMs and the
	corresponding label is in later programs). Quantum GIVE UP will
	continue running the current program while, at the same time,
	starting the next.

