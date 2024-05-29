MLCOMP ?= mlkit

.PHONY: all
all: mlkit-bench smlloc
	$(MAKE) -C press all
	$(MAKE) -C mem all
	$(MAKE) -C speedup all
	$(MAKE) -C abstime all

mlkit-bench: Bench.mlb Makefile *.sml
	$(MLCOMP) -output $@ $<

smlloc: smlloc.mlb smlloc.sml FileUtil.sml Makefile
	$(MLCOMP) -output $@ $<

.PHONY: clean
clean:
	rm -rf MLB *~ mlkit-bench smlloc
	$(MAKE) -C press clean
	$(MAKE) -C mem clean
	$(MAKE) -C speedup clean
	$(MAKE) -C abstime clean
	$(MAKE) -C charting clean
