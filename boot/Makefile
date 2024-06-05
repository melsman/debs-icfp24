
MLKIT_DIR=~/debs-icfp24/mlkit-src
MLTON_DIR=~/debs-icfp24/mlton-src

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
all: prepare
	$(MAKE) bootstrap0
	$(MAKE) bootstrap1
	$(MAKE) mlton-compile
	$(MAKE) mlton-compile-old

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
#	$(MAKE) bootstrap_do BOOTPREV=mlkit-v3 BOOTNEXT=mlkit-v4 \
#                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
#                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
#	$(MAKE) bootstrap_do BOOTPREV=mlkit-v4 BOOTNEXT=mlkit-v5 \
#                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
#                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
#	$(MAKE) bootstrap_do BOOTPREV=mlkit-v5 BOOTNEXT=mlkit-v6 \
#                             MLKIT_FLAGS="$(MLKIT_FLAGS)" \
#                             MLKIT_BUILD_LOG_NAME=$(MLKIT_BUILD_LOG_NAME)
	if $(DIFF) -s $(BOOTDIR)/mlkit-v2/bin/mlkit $(BOOTDIR)/mlkit-v3/bin/mlkit ; then true; else false; fi

.PHONY: prepare
prepare:
	(cd $(MLKIT_DIR) && ./autobuild)
	(cd $(MLKIT_DIR) && ./configure --with-compiler=mlkit)
	$(MAKE) -C $(MLKIT_DIR) mlkit
	$(MAKE) -C $(MLKIT_DIR) mlkit_basislibs

.PHONY: clean
clean:
	rm -rf *~ bootstrap bootstrap0 bootstrap1 *.log boxity_report.txt times_report.txt *.mem *.wallclock

.PHONY: boxity_report0
boxity_report0:
	@/bin/echo -n "$(PROGNAME) / $(COMPNAME)" '&' `grep -o ':hub' $(INP) | wc -l` '&' `grep -o ':lub' $(INP) | wc -l`
	@/bin/echo -n ' &' `grep -o ':enum' $(INP) | wc -l` '&' `grep -o ':box' $(INP) | wc -l` '&' `grep -o ':single' $(INP) | wc -l`
	@echo ' &' `grep -o ':single hub' $(INP) | wc -l` '&' `grep -o ':single lub' $(INP) | wc -l` '&' `grep -o ':single box' $(INP) | wc -l`

.PHONY: boxity_report
boxity_report:
	@echo 'Program / Compiler & hub & lub & enum & box & single k & single hub & single lub & single box' > boxity_report.txt
	@$(MAKE) -s boxity_report0 INP=bootstrap0-mlkit-v3.log PROGNAME=MLKit COMPNAME='MLKit Old' >> boxity_report.txt
	@$(MAKE) -s boxity_report0 INP=bootstrap1-mlkit-v3.log PROGNAME=MLKit COMPNAME='MLKit New' >> boxity_report.txt
	@$(MAKE) -s boxity_report0 INP=mlton-mlkit-comp-0-0.log PROGNAME=MLton COMPNAME='MLKit Old' >> boxity_report.txt
	@$(MAKE) -s boxity_report0 INP=mlton-mlkit-comp-1-1.log PROGNAME=MLton COMPNAME='MLKit New' >> boxity_report.txt
	@cat boxity_report.txt | column -t -s '&'

.PHONY: mlton-compile0
mlton-compile0:
	$(MAKE) -C $(MLTON_DIR)/mlton clean-mael
	$(MAKE) -C $(MLTON_DIR) mlkit-mlton MLKIT_ROOT=$(CWD)/bootstrap$(MLKIT_KIND)/mlkit-v2 \
                                            MLKIT_COMP_LOG=$(CWD)/mlton-mlkit-comp-$(MLKIT_KIND)-$(NUM).log

.PHONY: mlton-compile
mlton-compile:
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=1
	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=2
#	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=3
#	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=4
#	$(MAKE) mlton-compile0 MLKIT_KIND=0 NUM=5
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=1
	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=2
#	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=3
#	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=4
#	$(MAKE) mlton-compile0 MLKIT_KIND=1 NUM=5

.PHONY: mlton-compile-old
mlton-compile-old:
	$(MAKE) -C $(MLTON_DIR)/mlton clean-mael
	$(MAKE) -C $(MLTON_DIR) mlkit-mlton MLKIT_ROOT=$(CWD)/bootstrap0/mlkit-v2 \
                                            MLKIT_COMP_LOG=$(CWD)/mlton-mlkit-comp-0-0.log \
                                            MLKIT_FLAGS='-heap_to_live_ratio 5 --report_boxities --no_high_pointer_tagging'

bootstrap%.wallclock: bootstrap%.log
	grep '(wall clock) time (seconds)' $< | sed -r 's/.* ([0-9]+).[0-9]+.*/\1/' > $@

bootstrap%.mem: bootstrap%.log
	grep 'Maximum resident' $< | sed -r 's/.* ([0-9]+).*/\1/' | awk '{ printf("%.0f\n", $$1 / 1000) }' > $@

mlton-mlkit-comp-%.wallclock: mlton-mlkit-comp-%.log
	grep '(wall clock) time (seconds)' $< | sed -r 's/.* ([0-9]+).[0-9]+.*/\1/' > $@

mlton-mlkit-comp-%.mem: mlton-mlkit-comp-%.log
	grep 'Maximum resident' $< | sed -r 's/.* ([0-9]+).*/\1/' | awk '{ printf("%.0f\n", $$1 / 1000) }' > $@

AVGRSDV=awk '{ sum += $$1; sumsq += ($$1 * $$1) } END { printf("%.0f (±%.1f%%)", sum / NR, 100.0 * sqrt(((sumsq/NR) - ((sum/NR)*(sum/NR)))/NR) / (sum/NR)) }'

bootstrap%-mlkit.wallclock: bootstrap%-mlkit-v2.wallclock bootstrap%-mlkit-v3.wallclock
	cat $^ | $(AVGRSDV) > $@

bootstrap%-mlkit.mem: bootstrap%-mlkit-v2.mem bootstrap%-mlkit-v3.mem
	cat $^ | $(AVGRSDV) > $@

mlton-mlkit-comp%.wallclock: mlton-mlkit-comp-%-1.wallclock mlton-mlkit-comp-%-2.wallclock 
	cat $^ | $(AVGRSDV) > $@

mlton-mlkit-comp%.mem: mlton-mlkit-comp-%-1.mem mlton-mlkit-comp-%-2.mem
	cat $^ | $(AVGRSDV) > $@

times_report.txt: bootstrap0-mlkit.wallclock bootstrap1-mlkit.wallclock bootstrap0-mlkit.mem bootstrap1-mlkit.mem mlton-mlkit-comp0.wallclock mlton-mlkit-comp1.wallclock mlton-mlkit-comp0.mem mlton-mlkit-comp1.mem
	echo 'Program & Lines & MLKitOld (s) & MLKitNew (s) & MLKitOld (Mb) & MLKitNew (Mb)' > $@
	echo -n 'MLKit & ' >> $@
	echo -n "`../mlkit-bench/src/smlloc ../mlkit-src/src/Compiler/native64.mlb | grep -v ':'` & " >> $@
	echo -n "`cat bootstrap0-mlkit.wallclock` & `cat bootstrap1-mlkit.wallclock` & " >> $@ 
	echo "`cat bootstrap0-mlkit.mem` & `cat bootstrap1-mlkit.mem`" >> $@ 
	echo -n 'MLton & ' >> $@
	echo -n "`../mlkit-bench/src/smlloc ../mlton-src/mlton/mlton-mlkit-mael.mlb | grep -v ':'` & " >> $@
	echo -n "`cat mlton-mlkit-comp0.wallclock` & `cat mlton-mlkit-comp1.wallclock` & " >> $@ 
	echo "`cat mlton-mlkit-comp0.mem` & `cat mlton-mlkit-comp1.mem`" >> $@ 

.PHONY: times_report
times_report: times_report.txt
	@cat $< | column -t -s '&'

