MLKIT = mlkit --no_messages --report_boxities

.PHONY: all
all:
	@echo '** Example exp [unboxing expectations: bop:enum, e:hub]'
	$(MLKIT) exp.sml
	@echo '** Example single [unboxing expectations: s:lub, t:single box, u:hub]'
	$(MLKIT) single.sml
	@echo '** Example patricia [unboxing expectations: map:hub]'
	$(MLKIT) patricia.sml
	@echo '** Example uf [unboxing expectations: t0:hub]'
	$(MLKIT) uf.sml
	@echo '** Example stream [unboxing expectations: str:hub]'
	$(MLKIT) stream.sml
	@echo '** Example opt [unboxing expectations: option_orig:box, option:lub]'
	$(MLKIT) opt.sml

.PHONY: clean
clean:
	rm -rf *~ MLB run
