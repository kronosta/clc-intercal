FILES = $(shell sed -e 's,\.tex$$,.pdf,' .filelist)
DEPS = $(shell ls *.tex | grep -v -f .filelist)

all : $(FILES)

clean :
	rm -f *.pdf *.ps *.dvi *.aux *.toc *.log .rules.make

%.ps : %.dvi
	dvips -D 300 -q -f < $< > $@

%.dvi : %.tex $(DEPS)
	@echo latex $*
	@-rm -f $*.aux $*.log
	@latex $* > /dev/null
	@if grep -qi 'may have changed' $*.log; then latex $* > /dev/null; fi
	@if grep -qi 'may have changed' $*.log; then latex $* > /dev/null; fi
	@if grep -qi 'may have changed' $*.log; then latex $* > /dev/null; fi

%.pdf : %.tex $(DEPS)
	@echo pdflatex $*
	@-rm -f $*.aux $*.log
	@pdflatex $* > /dev/null
	@if grep -qi 'may have changed' $*.log; then pdflatex $* > /dev/null; fi
	@if grep -qi 'may have changed' $*.log; then pdflatex $* > /dev/null; fi
	@if grep -qi 'may have changed' $*.log; then pdflatex $* > /dev/null; fi

