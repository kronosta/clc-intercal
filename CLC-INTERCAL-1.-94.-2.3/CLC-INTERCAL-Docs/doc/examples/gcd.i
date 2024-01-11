	PLEASE NOTE: This program computes the GCD of two numbers. It is
		     the example used in the operational semantics article.

Copyright (c) 2006 Claudio Calvelli, all rights reserved.

CLC-INTERCAL is copyrighted software. However, permission to use, modify,
and distribute it is granted provided that the conditions set out in the
licence agreement are met. See files README and COPYING in the distribution.

	PLEASE WRITE IN .1 + .2
	DO COME FROM (3)
(1)	DO .3 <- '¥.1¢.2'~'¥.1¢.2'~#1
	DO READ OUT .1
	PLEASE GIVE UP
	PLEASE COME FROM .3
	DO .3 <- #0
	DO .4 <- #32768
	DO COME FROM .6
	DO .6 <- #0
	DO .5 <- '¥!1~.4'¢!2~.4''
(2)	PLEASE .5 <- .5¢#0
	DO .4 <- .4~#65534
(8)	DO .6 <- !4~.4~#1'¢#0¢#0
	PLEASE COME FROM .7
	DO .7 <- #0
(3)	bit left as an exercise to the reader - subtracts .2 from .1 and
	leaves the result in .1 without modifying .2; the last statement
	executed must have label (three). Do not cheat by looking it up
	DO COME FROM .5
	PLEASE .5 <- #0
(128)	DO .7 <- "!1~.4'~!1~.4'"¢#0¢#0¢#0
	DO .3 <- .2
	DO .2 <- .1
	DO .1 <- .3
	DO .3 <- #0
(7)	PLEASE .7 <- #7
