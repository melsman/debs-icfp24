BENCHFILES = calc/calc.mlb ray/ray.mlb nucleic/nucleic.mlb logic/logic.mlb vliw/vliw.sml \
             lexgen/lexgen.sml patricia/patricia.sml dlx/dlx.mlb kbc/kbc.sml uf/uf.mlb

MLKIT_BENCH = ../mlkit-bench/src/mlkit-bench
MLKIT_PRESS = ../mlkit-bench/src/press/mlkit-bench-press

.PHONY: all
all: prepare
	$(MAKE) mini.json

report.json:
	$(MLKIT_BENCH) -r 10 -o $@ \
          -mlton:-mlb-path-var \'MLCOMP mlton\': \
          -mlkit:-cr: \
          -mlkit:-no_high_pointer_tagging -mlb-subdir C1 -cr: \
          $(BENCHFILES)

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
        $<

mini.json:
	$(MLKIT_BENCH) -r 10 -o $@ \
          -smlnj \
          -mlton:-mlb-path-var \'MLCOMP mlton\': \
          -mlkit:-cr: \
          -mlkit:-no_high_pointer_tagging -mlb-subdir C1 -cr: \
          -mlkit:-no_gc -aopt -cr: \
          $(BENCHFILES)

.PHONY: minipress
minipress: mini.json
	$(MLKIT_PRESS) -sn -d real -d rss -skip1 \
           -merge_rows cname -c pname \
           -c plen \
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
        $<

.PHONY: minitpress
minitpress: mini.json
	$(MLKIT_PRESS) -M -sn -d real -d rss -skip1 \
           -no_mem_dev -merge_rows cname -c pname \
           -c plen \
           -c 'real # mlton' \
           -c 'real # smlnj' \
           -c 'real # rg-nhpt-cr' \
           -c 'real # rg-cr' \
           -c 'real # r-cr' \
        $<

.PHONY: minimpress
minimpress: mini.json
	$(MLKIT_PRESS) -sn -d real -d rss -skip1 \
           -merge_rows cname -c pname \
           -c plen \
           -c 'rss # mlton' \
           -c 'rss # smlnj' \
           -c 'rss # rg-nhpt-cr' \
           -c 'rss # rg-cr' \
           -c 'rss # r-cr' \
        $<

.PHONY: clean
clean:
	rm -rf *~ report.json MLB */MLB */*/MLB */*~ */*/*~ time.out
	rm -rf */*.exe *.exe */*.exe.* */*.auto.mlb */run mini.json */*.amd64-darwin* */*.amd64-linux* */.cm
	$(MAKE) -C calc clean

.PHONY: prepare
prepare:
	$(MAKE) -C calc prepare
