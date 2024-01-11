	PLEASE NOTE: This program demonstrates how to be a student while
	at the same time being not.

	Requires CLC-INTERCAL 1.-94 or newer.

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO .1 <- #1
	DO * WHILE READ OUT *
	DO STUDY #1 AT (1000) IN CLASS @1
	PLEASE ENROL .1 TO LEARN #1
	DO .1 GRADUATES WHILE REMAINING A STUDENT
	DO .1 LEARNS #1
	PLEASE GIVE UP

(1000)	DO .2 <- $@1 ¢ #0
	DO READ OUT .2
	DO FINISH LECTURE

	PLEASE NOTE: register .1 is (at the same time) a student of class @1
	and not a student; when he attempts to learn #1, he will go to the
	lecture (reading out II) but at the same time not go to the lecture
	(with *822, causing output of "DCCCXXII")

