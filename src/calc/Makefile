
FLAGS_BOX= --no_high_pointer_tagging -report_boxities
FLAGS_UB= -report_boxities

MLLEX=mllex
MLYACC=mlyacc
MLKIT=mlkit -no_gc

.PHONY: all
all: calc-ub.exe calc-box.exe

calc.lex.sml: calc.lex
	$(MLLEX) $<

calc.grm.sml: calc.grm
	$(MLYACC) $<

calc-ub.exe: calc.mlb calc.lex.sml calc.grm.sml calc.sml
	rm -rf MLB
	$(MLKIT) $(FLAGS_UB) -o $@ $<

calc-box.exe: calc.mlb calc.lex.sml calc.grm.sml calc.sml
	rm -rf MLB
	$(MLKIT) $(FLAGS_BOX) -o $@ $<

.PHONY: clean
clean:
	rm -rf MLB run *~ *.exe *.grm.sml *.grm.sig *.lex.sml *.desc calc

.PHONY: prepare
prepare: calc.lex.sml calc.grm.sml
