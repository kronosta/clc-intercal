	PLEASE NOTE: This program demonstrates how to study while not
	studying, whatever that means.

	Requires CLC-INTERCAL 1.-94 or newer.

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	DO .1 <- #1
	DO STUDY #1 AT (1000) IN CLASS @1
	DO STUDY #1 AT (2000) IN CLASS @1 WHILE NOT STUDYING IT
	PLEASE ENROL .1 TO LEARN #1
	DO .1 LEARNS #1
	PLEASE GIVE UP

(1000)	DO .2 <- $@1 ¢ #0
	DO READ OUT .2
	DO FINISH LECTURE

(2000)	DO .3 <- $@1 ¢ $@1
	DO READ OUT .3
	DO FINISH LECTURE

	PLEASE NOTE: In this program a lecture teaching subject #1 (in class
	@1) is (symultaneously) at labels 1000 and 2000; as a result, when
	the lecture is taught, it reads out both II and III (at the same time).

