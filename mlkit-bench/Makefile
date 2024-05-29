SMLPKG=smlpkg

.PHONY: all
all: lib
	$(MAKE) -C src all

lib:
	$(SMLPKG) sync

.PHONY: clean
clean:
	$(MAKE) -C src clean
	find lib -name 'MLB' | xargs rm -rf
	rm -rf *~

.PHONY: realclean
realclean: clean
	rm -rf lib
