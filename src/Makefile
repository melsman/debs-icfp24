BENCHFILES = uf/uf.mlb calc/calc.mlb patricia/patricia.sml kbc/kbc.sml \
             dlx/DLX.sml logic/logic.mlb vliw/vliw.sml nucleic/nucleic.mlb ray/ray.mlb

MLKIT_BENCH = ../mlkit-bench/src/mlkit-bench
MLKIT_PRESS = ..//mlkit-bench/src/press/mlkit-bench-press

.PHONY: all
all: prepare report.json

report.json:
	$(MLKIT_BENCH) -r 5 -o $@ \
          -mlton:-mlb-path-var \'MLCOMP mlton\': \
          -mlkit:-cr: \
          -mlkit:-no_high_pointer_tagging -mlb-subdir C1 -cr: \
          $(BENCHFILES)

#          -mlkit:-no_gc: \
#          -mlkit:-no_gc -no_high_pointer_tagging -mlb-subdir C1: \


.PHONY: press
press: report.json
	$(MLKIT_PRESS) -sn -d real -d rss -skip1 \
           -merge_rows cname -c pname \
           -c 'real # mlton' \
           -c 'real # rg-cr' \
           -c 'real # rg-nhpt-cr' \
           -c 'rss # mlton' \
           -c 'rss # rg-cr' \
           -c 'rss # rg-nhpt-cr' \
           -c plen \
           -latex \
        $<

mini.json:
	$(MLKIT_BENCH) -r 10 -o $@ \
          -smlnj \
          -mlton:-mlb-path-var \'MLCOMP mlton\': \
          -mlkit:-cr: \
          -mlkit:-no_high_pointer_tagging -mlb-subdir C1 -cr: \
          patricia/patricia.sml

#          calc/calc.mlb ray/ray.mlb nucleic/nucleic.mlb logic/logic.mlb vliw/vliw.sml lexgen/lexgen.sml patricia/patricia.sml dlx/DLX.sml kbc/kbc.sml uf/uf.mlb

.PHONY: minipress
minipress: mini.json
	$(MLKIT_PRESS) -latex -M -sn -d real -d rss -skip1 \
           -merge_rows cname -c pname \
           -c 'real # mlton' \
           -c 'real # smlnj' \
           -c 'real # rg-cr' \
           -c 'real # rg-nhpt-cr' \
           -c 'rss # mlton' \
           -c 'rss # smlnj' \
           -c 'rss # rg-cr' \
           -c 'rss # rg-nhpt-cr' \
           -c plen \
        $<

.PHONY: clean
clean:
	rm -rf *~ report.json MLB */MLB */*/MLB */*~ */*/*~
	rm -rf */*.exe *.exe */*.exe.* */*.auto.mlb */run mini.json */*.amd64-darwin* */.cm
	$(MAKE) -C calc clean

.PHONY: prepare
prepare:
	$(MAKE) -C calc prepare
