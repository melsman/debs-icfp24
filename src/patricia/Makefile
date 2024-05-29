
FLAGS_BOX= --no_high_pointer_tagging -report_boxities
FLAGS_UB= -report_boxities

.PHONY: all
all: patricia-box.exe patricia-ub.exe

patricia-box.exe: patricia.sml
	rm -rf MLB
	mlkit $(FLAGS_BOX) -o $@ $<

patricia-ub.exe: patricia.sml
	rm -rf MLB
	mlkit $(FLAGS_UB) -o $@ $<

.PHONY: clean
clean:
	rm -rf MLB run *~ *.exe
