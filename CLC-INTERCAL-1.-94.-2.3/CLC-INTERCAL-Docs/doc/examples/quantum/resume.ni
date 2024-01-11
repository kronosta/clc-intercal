	PLEASE NOTE: This program demonstrates the use of quantum resuming.

	Requires CLC-INTERCAL 1.-94 with the "NEXT" extension.

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO (1) NEXT
	DO .1 <- #1
	DO READ OUT .1
	DO GIVE UP

(1)	DO .2 <- #2
	DO READ OUT .2
	DO (2) NEXT
	PLEASE GIVE UP

(2)	PLEASE RESUME #2 WHILE NOT RESUMING
	DO .3 <- #3
	DO READ OUT .3
	PLEASE FORGET #1
	PLEASE RESUME #1

