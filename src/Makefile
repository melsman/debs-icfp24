BENCHFILES = uf/uf.mlb calc/calc.mlb patricia/patricia.sml kbc/kbc.sml \
             dlx/DLX.mlb logic/logic.mlb vliw/vliw.sml nucleic/nucleic.mlb ray/ray.mlb

MLKIT_ROOT ?= ~/gits/mlkit
MLKIT_BENCH = ~/gits/mlkit-bench/src/mlkit-bench
MLKIT_PRESS = ~/gits/mlkit-bench/src/press/mlkit-bench-press

.PHONY: all
all: prepare report.json

report.json:
	MLKIT_ROOT=$(MLKIT_ROOT) $(MLKIT_BENCH) -r 5 -o $@ \
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
	MLKIT_ROOT=$(MLKIT_ROOT) $(MLKIT_BENCH) -r 10 -o $@ \
          -smlnj \
          -mlton:-mlb-path-var \'MLCOMP mlton\': \
          -mlkit:-cr: \
          -mlkit:-no_high_pointer_tagging -mlb-subdir C1 -cr: \
          -mlkit:-no_gc -cr: \
          dlx/DLX.mlb nucleic/nucleic.mlb

#calc/calc.mlb ray/ray.mlb nucleic/nucleic.mlb logic/logic.mlb vliw/vliw.sml lexgen/lexgen.sml patricia/patricia.sml dlx/DLX.mlb kbc/kbc.sml uf/uf.mlb

#uf/uf.mlb
#logic/logic.mlb
#patricia/patricia.sml

.PHONY: minipress
minipress: mini.json
	$(MLKIT_PRESS) -latex -M -sn -d real -d rss -skip1 \
           -no_mem_dev -merge_rows cname -c pname \
           -c 'real # mlton' \
           -c 'real # smlnj' \
           -c 'real # r-cr' \
           -c 'real # rg-cr' \
           -c 'real # rg-nhpt-cr' \
           -c 'rss # mlton' \
           -c 'rss # smlnj' \
           -c 'rss # r-cr' \
           -c 'rss # rg-cr' \
           -c 'rss # rg-nhpt-cr' \
           -c plen \
        $<

.PHONY: minitpress
minitpress: mini.json
	$(MLKIT_PRESS) -latex -M -sn -d real -d rss -skip1 \
           -no_mem_dev -merge_rows cname -c pname \
           -c plen \
           -c 'real # mlton' \
           -c 'real # smlnj' \
           -c 'real # rg-cr' \
           -c 'real # rg-nhpt-cr' \
           -c 'real # r-cr' \
        $<

.PHONY: minimpress
minimpress: mini.json
	$(MLKIT_PRESS) -latex -M -no_mem_dev -sn -d real -d rss -skip1 \
           -merge_rows cname -c pname \
           -c plen \
           -c 'rss # mlton' \
           -c 'rss # smlnj' \
           -c 'rss # rg-cr' \
           -c 'rss # rg-nhpt-cr' \
           -c 'rss # r-cr' \
        $<


.PHONY: clean
clean:
	rm -rf *~ report.json MLB */MLB */*/MLB */*~ */*/*~
	rm -rf */*.exe *.exe */*.exe.* */*.auto.mlb */run mini.json */*.amd64-darwin* */.cm
	$(MAKE) -C calc clean

.PHONY: prepare
prepare:
	$(MAKE) -C calc prepare
