	PLEASE NOTE: this program demonstrates quantum retrieve.

	Requires CLC-INTERCAL 1.-94 or newer.

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO .1 <- #1
	DO STASH .1
	DO .1 <- #2
	DO RETRIEVE .1 WHILE NOT RETRIEVING IT
	DO READ OUT .1

	PLEASE NOTE: The program enters a superposed state in which the
	stash stack has and has not been retrieved from; as a result,
	one state READs OUT #1 and the other #2.

	DO GIVE UP

