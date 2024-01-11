# Makefile to produce bootstrap objects (iacc.io and postpre.io) so the compiler-compiler
# can compile itself; also can produce .iacc files from a different (undocumented) language

# This file is part of CLC-INTERCAL

# Copyright (c) 2008, 2023 Claudio Calvelli, all rights reserved.

# CLC-INTERCAL is copyrighted software. However, permission to use, modify,
# and distribute it is granted provided that the conditions set out in the
# licence agreement are met. See files README and COPYING in the distribution.

# PERVERSION: CLC-INTERCAL/Base aux/Makefile 1.-94.-2.3

#OBJECTS = 1972 asm computed-labels iacc ick internet next sick
OBJECTS = 1972 asm computed-labels iacc ick next sick
SRC = $(shell echo $(OBJECTS)|tr ' ' '\012'|awk '{print "../INTERCAL/Include/" $$0 ".iacc"}')
IODIR = ../blib/iofiles
PERL = perl

all : empty $(SRC) generate $(IODIR)/iacc.io $(IODIR)/postpre.io

empty :
	@ rm -f filelist

iacc.src : asm.bc Makefile joinfiles iacc.prefix ../INTERCAL/Generate/Splats.Data
	$(PERL) joinfiles iacc.src iacc.prefix asm.bc

asm.bc : mkasm Makefile ../INTERCAL/Generate/ByteCode.Data
	$(PERL) mkasm asm.bc

asm.src : asm.bc Makefile joinfiles asm.prefix
	$(PERL) joinfiles asm.src asm.prefix asm.bc

sick.src : sick.prefix Makefile joinfiles asm.bc ../INTERCAL/Generate/Splats.Data
	$(PERL) joinfiles sick.src sick.prefix asm.bc

../INTERCAL/Include/%.iacc : %.src mkfiles Makefile
	@ echo $< | sed -e 's,\.src$$,,' >> filelist

$(IODIR)/iacc.io : iacc.src mkfiles Makefile
	$(PERL) mkfiles object iacc

iacc : $(IODIR)/iacc.io

$(IODIR)/postpre.io : Makefile mkpostpre
	$(PERL) mkpostpre postpre

postpre : $(IODIR)/postpre.io

generate :
	@ if [ -f filelist ] ; then echo ./mkfiles compiler `cat filelist` ; else true; fi
	@ if [ -f filelist ] ; then ./mkfiles compiler `cat filelist` ; else true; fi

manicheck :
	@ cd .. && find . -type f | cut -c3- | egrep -v '^old/|^blib/' | sort | diff - <(awk '{print $$1}' MANIFEST | sort) | grep '^[<>]' || echo "No differences"

clean :
	rm -f $(SRC) asm.src asm.bc iacc.src sick.src ../iacc.io ../postpre.io filelist

times :
	@ clear
	@ cd .. && /usr/bin/time -a -o times bin/sick -o/dev/null -v \
		1972.iacc ick.iacc sick.iacc iacc.iacc


