
MLKIT_DIR=~/gits/mlkit

MKDIR=mkdir -p
INSTALL=/usr/bin/install -c
STRIP=strip
DIFF=diff
CLEAN=rm -rf MLB *~ .\#*
CWD=$(shell pwd)

MLKIT_FLAGS ?=
BOOTDIR ?= bootstrap
BUILD_COUNT ?= 0


.PHONY: all
all: bootstrap0 bootstrap1

.PHONY: bootstrap0
bootstrap0:
	$(MAKE) bootstrap BOOTDIR=bootstrap0 \
                          MLKIT_FLAGS="'-heap_to_live_ratio 5 --report_boxities --no_high_pointer_tagging'"  \
                          MLKIT_BUILD_LOG_NAME=bootstrap0

.PHONY: bootstrap1
bootstrap1:
	$(MAKE) bootstrap BOOTDIR=bootstrap1 \
                          MLKIT_FLAGS="'-heap_to_live_ratio 5 --report_boxities'" \
                          MLKIT_BUILD_LOG_NAME=bootstrap1

.PHONY: bootstrap_do
bootstrap_do:
	$(CLEAN) $(BOOTDIR)/$(BOOTNEXT)
	$(MAKE) -C $(BOOTDIR)/$(BOOTPREV) bootstrap_next INSTDIR=../$(BOOTNEXT) DATADIR=../$(BOOTNEXT) LIBDIR=../$(BOOTNEXT) \
	                        MANDIR=../$(BOOTNEXT)/man BINDIR=../$(BOOTNEXT)/bin \
                                MLKIT_FLAGS=$(MLKIT_FLAGS) \
                                MLKIT_BUILD_LOG=$(CWD)/$(MLKIT_BUILD_LOG_NAME)-$(BOOTNEXT).log
	$(STRIP) $(BOOTDIR)/$(BOOTNEXT)/bin/mlkit

.PHONY: bootstrap
bootstrap:
	$(MKDIR) $(BOOTDIR)
	$(CLEAN) $(BOOTDIR)/mlkit-v0
	$(MAKE) -C $(MLKIT_DIR) bootstrap_first INSTDIR=$(CWD)/$(BOOTDIR)/mlkit-v0 DATADIR=$(CWD)/$(BOOTDIR)/mlkit-v0 LIBDIR=$(CWD)/$(BOOTDIR)/mlkit-v0 \
	                        MANDIR=$(CWD)/$(BOOTDIR)/mlkit-v0/man BINDIR=$(CWD)/$(BOOTDIR)/mlkit-v0/bin
	$(MAKE) bootstrap_do BOOTPREV=mlkit-v0 BOOTNEXT=mlkit-v1 \
                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	$(MAKE) bootstrap_do BOOTPREV=mlkit-v1 BOOTNEXT=mlkit-v2 \
                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	$(MAKE) bootstrap_do BOOTPREV=mlkit-v2 BOOTNEXT=mlkit-v3 \
                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	$(MAKE) bootstrap_do BOOTPREV=mlkit-v3 BOOTNEXT=mlkit-v4 \
                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	$(MAKE) bootstrap_do BOOTPREV=mlkit-v4 BOOTNEXT=mlkit-v5 \
                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	$(MAKE) bootstrap_do BOOTPREV=mlkit-v5 BOOTNEXT=mlkit-v6 \
                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	if $(DIFF) -s $(BOOTDIR)/mlkit-v2/bin/mlkit $(BOOTDIR)/mlkit-v3/bin/mlkit ; then true; else false; fi

.PHONY: prepare
prepare:
	$(MAKE) -C $(MLKIT_DIR) mlkit_basislibs

.PHONY: clean
clean:
	rm -rf *~ bootstrap bootstrap0 bootstrap1 *.log

.PHONY: boxity_report0
boxity_report0:
	@/bin/echo -n "$(PROGNAME) / $(COMPNAME)" '&' `grep -o ':unb-all' $(INP) | wc -l` '&' `grep -o ':unb-low' $(INP) | wc -l`
	@/bin/echo -n ' &' `grep -o ':enum' $(INP) | wc -l` '&' `grep -o ':boxed' $(INP) | wc -l` '&' `grep -o ':single' $(INP) | wc -l`
	@echo ' &' `grep -o ':single unb-all' $(INP) | wc -l` '&' `grep -o ':single unb-low' $(INP) | wc -l` '&' `grep -o ':single boxed' $(INP) | wc -l`

.PHONY: boxity_report
boxity_report:
	@echo '-----------------------------------------------------------------------------------------------'
	@echo 'Program / Compiler & hub & lub & enum & boxed & single k & single hub & single lub & single box'
	@$(MAKE) boxity_report0 INP=bootstrap0-mlkit-v6.log PROGNAME=MLKit COMPNAME='MLKit Old'
	@$(MAKE) boxity_report0 INP=bootstrap1-mlkit-v6.log PROGNAME=MLKit COMPNAME='MLKit New'
	@$(MAKE) boxity_report0 INP=mlton-mlkit-comp-0-0.log PROGNAME=MLton COMPNAME='MLKit Old'
	@$(MAKE) boxity_report0 INP=mlton-mlkit-comp-1-1.log PROGNAME=MLton COMPNAME='MLKit New'
	@echo '-----------------------------------------------------------------------------------------------'

.PHONY: mlton-compile0
mlton-compile0:
	$(MAKE) -C ~/gits/mlton/mlton clean-mael
	$(MAKE) -C ~/gits/mlton mlkit-mlton MLKIT_ROOT=$(CWD)/bootstrap$(MLKIT_KIND)/mlkit-v3 \
                                            MLKIT_COMP_LOG=$(CWD)/mlton-mlkit-comp-$(MLKIT_KIND)-$(NUM).log

.PHONY: mlton-compile
mlton-compile:
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=1
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=2
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=3
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=4
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=5
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=1
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=2
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=3
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=4
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=5

.PHONY: mlton-compile-old
mlton-compile-old:
	$(MAKE) -C ~/gits/mlton/mlton clean-mael
	$(MAKE) -C ~/gits/mlton mlkit-mlton MLKIT_ROOT=$(CWD)/bootstrap0/mlkit-v3 \
                                            MLKIT_COMP_LOG=$(CWD)/mlton-mlkit-comp-0-0.log \
                                            MLKIT_FLAGS='-heap_to_live_ratio 5 --report_boxities --no_high_pointer_tagging'
