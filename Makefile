.PHONY: all
all:
	@echo Options:
	@echo    make prepare
	@echo    make clean

.PHONY: prepare
prepare:
	make -C mlkit-bench all

.PHONY: clean
clean:
	rm -rf *~ debs-icfp24.tar.gz
	make -C src clean
	make -C mlkit-bench clean
	make -C demo clean


