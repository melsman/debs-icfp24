## Copyright (C) 2010,2013,2016,2018-2022 Matthew Fluet.
 # Copyright (C) 1999-2009 Henry Cejtin, Matthew Fluet, Suresh
 #    Jagannathan, and Stephen Weeks.
 # Copyright (C) 1997-2000 NEC Research Institute.
 #
 # MLton is released under a HPND-style license.
 # See the file MLton-LICENSE for details.
 ##

ROOT := ..
include $(ROOT)/Makefile.config

######################################################################

RUN_MLTON_RUNTIME_XARGS := ram-slop 0.7
RUN_MLTON_COMPILE_XARGS :=

MLTON_DEBUG := false

ifeq (true, $(SELF_COMPILE))
# Older versions of `mlton` may not support `sequenceNonUnit` or `warnUnused`.
RUN_MLTON_COMPILE_XARGS += -default-ann 'sequenceNonUnit warn'
RUN_MLTON_COMPILE_XARGS += -default-ann 'warnUnused true'
# RUN_MLTON_COMPILE_XARGS += -type-check true
RUN_MLTON_COMPILE_XARGS += -const 'MLton.debug $(MLTON_DEBUG)'
# We're self-compiling, so don't use any stubs.
MLTON_MLB := mlton.mlb
else
# We're bootstrapping, so use stubs.
MLTON_MLB := mlton-stubs.mlb
endif

## When self-compiling the current MLton sources with `Zone` enabled,
## the resulting compiler exhibits a space leak; see MLton/mlton#334
ifeq ($(RUN_MLTON_VERSION), $(firstword $(sort $(RUN_MLTON_VERSION) 20170629)))
RUN_MLTON_COMPILE_XARGS += -drop-pass zone
else ifeq ($(RUN_MLTON_VERSION), $(firstword $(sort $(RUN_MLTON_VERSION) 20191003)))
RUN_MLTON_COMPILE_XARGS += -disable-pass zone
endif

MLTON_FRONT_END_GEN_SOURCES :=		\
	front-end/ml.lex.sml 		\
	front-end/ml.grm.sig 		\
	front-end/ml.grm.sml 		\
	front-end/mlb.lex.sml 		\
	front-end/mlb.grm.sig 		\
	front-end/mlb.grm.sml

MLTON_GEN_SOURCES := 			\
	$(MLTON_FRONT_END_GEN_SOURCES)	\
	control/version.sml

ifneq (,$(or						\
	$(findstring mlton-stubs.mlb,$(MLTON_MLB)),	\
	$(findstring smlnj-mlton,$(MAKECMDGOALS)),	\
	$(findstring polyml-mlton,$(MAKECMDGOALS),	\
	$(findstring mlkit-mlton,$(MAKECMDGOALS)),	\
	)))
MLTON_GEN_SOURCES += 			\
	../lib/stubs/mlton-stubs/pre-mlton.sml
endif

MLTON_SOURCES :=			\
	$(shell $(MLBDEPS) $(MLTON_MLB))\
	$(MLTON_GEN_SOURCES)

.PHONY: all
all: $(MLTON_OUTPUT)

SHOW_VARS += MLTON_MLB

$(eval $(MK_COMMON_GOALS))

######################################################################

$(MLTON_OUTPUT): $(MLTON_SOURCES)
	@echo 'Compiling mlton'
	"$(RUN_MLTON)" \
		@MLton $(RUN_MLTON_RUNTIME_XARGS) $(RUN_MLTON_RUNTIME_ARGS) gc-summary -- \
		$(RUN_MLTON_COMPILE_XARGS) -verbose 2 $(RUN_MLTON_COMPILE_ARGS)	\
		-target $(TARGET) -output $(MLTON_OUTPUT)			\
		$(MLTON_MLB)

define GEN_TEMPLATE
ifeq ($$(shell ($$(CAT) $$(subst .sml,_sml.src,$(1)) ; echo $$(foreach VAR,$(2),'$$($$(VAR))'); if [ -e $(1) ]; then $$(CAT) $(1); fi) | $$(SHA1DGST)),$$(shell if [ -e $$(subst .sml,_sml.chk,$(1)) ]; then $$(CAT) $$(subst .sml,_sml.chk,$(1)); fi))
$(1): $$(subst .sml,_sml.src,$(1))
	touch $$@
else
$$(shell $$(RM) $(1))
$(1): $$(subst .sml,_sml.src,$(1))
	$$(SED) \
		$$(foreach VAR,$(2),-e "s/$$(VAR)/$$($$(VAR))/") \
		< $$< \
		> $$@
	($$(CAT) $$<; echo $$(foreach VAR,$(2),'$$($$(VAR))'); $$(CAT) $$@) | $$(SHA1DGST) > $$(subst .sml,_sml.chk,$(1))
endif
endef

$(eval $(call GEN_TEMPLATE,control/version.sml,MLTON_NAME MLTON_VERSION))
$(eval $(call GEN_TEMPLATE,../lib/stubs/mlton-stubs/pre-mlton.sml,MLTON_DEBUG HOST_ARCH HOST_OS))

ifeq (true,$(call HAVE_CMD,$(RUN_MLLEX)))
front-end/%.lex.sml: front-end/%.lex
	$(RM) $<.*
	$(RUN_MLLEX) $<
	$(MV) $<.sml $<.sml.in
	$(SED) -e 's/val s = List.map f (List.rev (tl (List.rev s)))/val s = Pervasive.List.map f (Pervasive.List.rev (tl (Pervasive.List.rev s)))/' $<.sml.in > $<.sml
	$(MV) $<.sml $<.sml.in
	$(SED) -e 's/in Vector.fromList(List.map g/in Vector.fromList(Pervasive.List.map g/' $<.sml.in > $<.sml
	$(RM) $<.sml.in
	$(CHMOD) -w $<.*
	$(CP) $<.sml $<.sml.boot
else
front-end/%.lex.sml: front-end/%.lex.sml.boot
	$(RM) $@
	$(CP) $< $@
	$(CHMOD) -w $@
endif

ifeq (true,$(call HAVE_CMD,$(RUN_MLYACC)))
front-end/%.grm.sig front-end/%.grm.sml: front-end/%.grm
	$(RM) $<.*
	$(RUN_MLYACC) $<
	$(MV) $<.sml $<.sml.in
	$(SED) -e 's/in f 0 handle General.Subscript => ()/in f 0 handle Pervasive.General.Subscript => ()/' $<.sml.in > $<.sml
	$(MV) $<.sml $<.sml.in
	$(SED) -e 's/in Array.fromList(List.map actionRowLookUp actionRowNumbers)/in Array.fromList(Pervasive.List.map actionRowLookUp actionRowNumbers)/' $<.sml.in > $<.sml
	$(RM) $<.sml.in
	$(CHMOD) -w $<.*
	$(CP) $<.sig $<.sig.boot
	$(CP) $<.sml $<.sml.boot
else
front-end/%.grm.sig: front-end/%.grm.sig.boot
	$(RM) $@
	$(CP) $< $@
	$(CHMOD) -w $@
front-end/%.grm.sml: front-end/%.grm.sml.boot
	$(RM) $@
	$(CP) $< $@
	$(CHMOD) -w $@
endif

mlton-stubs.mlb: $(shell $(MLBDEPS) ../lib/stubs/mlton-stubs/sources.mlb | $(GREP) 'mlb$$' | $(GREP) -v '$$(SML_LIB)') $(shell $(MLBDEPS) mlton.mlb | $(GREP) 'mlb$$' | $(GREP) -v '$$(SML_LIB)')
	(									\
		echo '$$(SML_LIB)/basis/unsafe.mlb';				\
		echo '$$(SML_LIB)/basis/sml-nj.mlb';				\
		echo '$$(SML_LIB)/basis/mlton.mlb';				\
		echo '$$(SML_LIB)/basis/basis.mlb';				\
		$(MLBDEPS) mlton.mlb |						\
			$(GREP) -v 'mlb$$' |					\
			$(GREP) 'mlyacc';					\
		$(MLBDEPS) ../lib/stubs/mlton-stubs/sources.mlb |		\
			$(GREP) -v 'mlb$$' |					\
			$(GREP) 'mlton-stubs';					\
		$(MLBDEPS) mlton.mlb |						\
			$(GREP) -v 'mlb$$' |					\
			$(GREP) -v 'sml/basis' |				\
			$(GREP) -v 'targets' |					\
			$(GREP) -v 'mlyacc';					\
	) > mlton-stubs.mlb

######################################################################

.PHONY: def-use
def-use: mlton.def-use

mlton.def-use: $(MLTON_SOURCES)
	"$(RUN_MLTON)" \
		@MLton $(RUN_MLTON_RUNTIME_XARGS) $(RUN_MLTON_RUNTIME_ARGS) --	\
		$(RUN_MLTON_COMPILE_XARGS) -verbose 0 $(RUN_MLTON_COMPILE_ARGS)	\
		-stop tc -prefer-abs-paths true -show-def-use mlton.def-use	\
		$(MLTON_MLB)

######################################################################

ifneq (,$(REMOTE_TARGET))
mlton-bootstrap-$(REMOTE_TARGET).tgz: $(MLTON_SOURCES)
	"$(RUN_MLTON)" \
		@MLton $(RUN_MLTON_RUNTIME_XARGS) $(RUN_MLTON_RUNTIME_ARGS) gc-summary -- \
		$(RUN_MLTON_COMPILE_XARGS) -verbose 2 $(RUN_MLTON_COMPILE_ARGS)	\
		-target $(REMOTE_TARGET) -output $(MLTON_OUTPUT) \
		-codegen c -stop g \
		$(MLTON_MLB)
	$(TAR) czf $@ $(MLTON_OUTPUT).*.c
	$(RM) $(MLTON_OUTPUT).*.c
endif

######################################################################

#
# The following rebuilds the heap file for the SML/NJ compiled version of MLton.
#
ifneq (,$(findstring smlnj-mlton,$(MAKECMDGOALS)))
.PHONY: smlnj-mlton
smlnj-mlton: $(MLTON_OUTPUT_SMLNJ_HEAP)

SMLNJ_CM_SERVERS_NUM := 0

$(MLTON_OUTPUT_SMLNJ_HEAP):
	(									\
		echo 'local';							\
		echo 'fun loop 0 = () | loop n = (CM.Server.start {cmd = (CommandLine.name (), ["@CMslave"]), name = "server" ^ (Int.toString n), pathtrans = NONE, pref = 0}; loop (n - 1));'; \
		echo 'in';							\
		echo 'val _ = loop $(SMLNJ_CM_SERVERS_NUM);';			\
		echo 'end;';							\
		echo 'if (CM.make "mlton-smlnj.cm") handle _ => false';		\
		echo '   then ()';						\
		echo '   else OS.Process.exit OS.Process.failure;'; 		\
		echo 'SMLofNJ.exportFn("$@",Main.main);'			\
	) | CM_VERBOSE=false CONTROL_POLY_EQ_WARN=false "$(SMLNJ)"

$(MLTON_OUTPUT_SMLNJ_HEAP).d: $(MLTON_GEN_SOURCES)
	@$(RM) $@
	@touch $@
	CM_VERBOSE=false $(SMLNJ_MAKEDEPEND) -n -f $@ mlton-smlnj.cm $(MLTON_OUTPUT_SMLNJ_HEAP) || ($(RM) $@ ; exit 1)
	CM_VERBOSE=false $(SMLNJ_MAKEDEPEND) -n -f $@ mlton-smlnj.cm $@ || ($(RM) $@ ; exit 1)
-include $(MLTON_OUTPUT_SMLNJ_HEAP).d
endif

######################################################################

#
# The following rebuilds the executable file for the Poly/ML compiled version of
# MLton.
#
ifneq (,$(findstring polyml-mlton,$(MAKECMDGOALS)))
.PHONY: polyml-mlton
polyml-mlton: $(MLTON_OUTPUT)-polyml

$(MLTON_OUTPUT)-polyml: mlton-polyml.sml $(shell [ -e mlton-polyml.sml ] && $(CAT) mlton-polyml.sml | $(SED) -n 's/use "\(.*\)";/\1/p') $(MLTON_GEN_SOURCES)
	$(POLYML_POLYC) -o $@ mlton-polyml.sml

mlton-polyml.sml: ../lib/stubs/polyml/basis/sources.use ../lib/stubs/polyml/mlton/sources.use $(shell $(MLBDEPS) ../lib/stubs/mlton-stubs/sources.mlb | $(GREP) 'mlb$$' | $(GREP) -v '$$(SML_LIB)') $(shell $(MLBDEPS) mlton.mlb | $(GREP) 'mlb$$' | $(GREP) -v '$$(SML_LIB)')
	(									\
		$(CAT) ../lib/stubs/polyml/basis/sources.use |			\
			$(SED) 's|use "\(.*\)";|../lib/stubs/polyml/basis/\1|'; \
		$(MLBDEPS) mlton.mlb | $(GREP) -v 'mlb$$' | $(GREP) 'mlyacc'; 	\
		$(CAT) ../lib/stubs/polyml/mlton/sources.use |			\
			$(SED) 's|use "\(.*\)";|../lib/stubs/polyml/mlton/\1|'; \
		$(MLBDEPS) ../lib/stubs/mlton-stubs/sources.mlb |		\
			$(GREP) -v 'mlb$$' |					\
			$(GREP) 'mlton-stubs';					\
		$(MLBDEPS) mlton.mlb |						\
			$(GREP) -v 'mlb$$' |					\
			$(GREP) -v 'sml/basis' |				\
			$(GREP) -v 'targets' |					\
			$(GREP) -v 'mlton-stubs' |				\
			$(GREP) -v 'mlyacc' |					\
			$(GREP) -v 'call-main.sml';				\
	) | $(SED) 's|\(.*\)|use "\1";|' > $@
	echo "val main = Main.mainWrapped;" >> $@
endif

######################################################################

#
# The following rebuilds the executable file for the MLKit compiled version of
# MLton.
#
ifneq (,$(findstring mlkit,$(MAKECMDGOALS)))
.PHONY: mlkit-mlton
mlkit-mlton: $(MLTON_OUTPUT)-mlkit

ifeq ($(shell uname),Darwin)
TIMECMD=/usr/bin/time -l
else
TIMECMD=/usr/bin/time -f 'Command being timed: "%C"\nUser time (seconds): %U\nSystem time (seconds): %S\nElabsed (wall clock) time (seconds): %e\nMaximum resident set size (Kbytes): %M'
endif

MLKIT_ROOT ?= ~/gits/bitstealing/boot/bootstrap0/mlkit-v3
MLKIT_COMP_LOG ?= mlton-mlkit-comp.log
MLKIT_FLAGS ?= -heap_to_live_ratio 5 --report_boxities

$(MLTON_OUTPUT)-mlkit: $(shell $(MLBDEPS) mlton-mlkit.mlb | $(GREP) -v '$$(SML_LIB)') $(MLTON_GEN_SOURCES)
	echo '** COMPILING MLTON WITH MLKIT **' > $(MLKIT_COMP_LOG)
	echo "** MLKIT_ROOT: $(MLKIT_ROOT)" >> $(MLKIT_COMP_LOG)
	echo "** MLKIT_FLAGS: $(MLKIT_FLAGS)" >> $(MLKIT_COMP_LOG)
	SML_LIB=$(MLKIT_ROOT) $(TIMECMD) $(MLKIT_ROOT)/bin/mlkit $(MLKIT_FLAGS) -o $@ mlton-mlkit-mael.mlb 2>&1 | tee -a $(MLKIT_COMP_LOG)
#	$(MLKIT) -o $@ -print_effects -print_types mlton-mlkit-mael.mlb
#	$(MLKIT) -no_gc -o $@ -j 8 mlton-mlkit-mael.mlb

mlton-mlkit.mlb: ../lib/stubs/mlkit/basis/sources.mlb ../lib/stubs/mlkit/mlton/sources.mlb $(shell $(MLBDEPS) ../lib/stubs/mlton-stubs/sources.mlb | $(GREP) 'mlb$$' | $(GREP) -v '$$(SML_LIB)') $(shell $(MLBDEPS) mlton.mlb | $(GREP) 'mlb$$' | $(GREP) -v '$$(SML_LIB)')
	(									\
		echo 'local';							\
		echo '../lib/stubs/mlkit/basis/sources.mlb';			\
		$(MLBDEPS) mlton.mlb | $(GREP) -v 'mlb$$' | $(GREP) 'mlyacc'; 	\
		echo '../lib/stubs/mlkit/mlton/sources.mlb';			\
		$(MLBDEPS) ../lib/stubs/mlton-stubs/sources.mlb |		\
			$(GREP) -v 'mlb$$' | 					\
			$(GREP) 'mlton-stubs';					\
		$(MLBDEPS) mlton.mlb |						\
			$(GREP) -v 'mlb$$' |					\
			$(GREP) -v 'sml/basis' | 				\
			$(GREP) -v 'targets' |					\
			$(GREP) -v 'mlton-stubs' |				\
			$(GREP) -v 'mlyacc' |					\
			$(GREP) -v 'call-main.sml';				\
		echo 'in';							\
		echo 'call-main.sml';						\
		echo 'end';							\
	) > $@
endif

.PHONY: clean-mael
clean-mael:
	$(MAKE) clean
	find .. -name 'MLB' | xargs rm -rf
