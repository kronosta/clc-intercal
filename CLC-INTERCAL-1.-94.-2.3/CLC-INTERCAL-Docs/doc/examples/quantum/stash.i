	PLEASE NOTE: this program demonstrates quantum stash.

	Requires CLC-INTERCAL 1.-94 or newer.

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO .1 <- #1
	DO STASH .1
	DO .1 <- #2
	DO STASH .1 WHILE NOT STASHING IT
	DO .1 <- #3
	DO RETRIEVE .1
	DO READ OUT .1

	PLEASE NOTE: There is (apparently) a race condition in which two
	superposed states attempt to retrieve .1 at the same time, but
	the stash depth at the time of retrieving is not uniquely determined
	(it can be one or two). We don't quite know what happens until we
	force the two states to collapse by looking at it (with the READ OUT).

	DO GIVE UP

