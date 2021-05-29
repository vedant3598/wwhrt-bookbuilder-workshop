################################################################################
################################ CONFIGURATION  ################################
################################################################################
# We build your code twice. Once  with and once without optimizations. We will #
# use the optimized version to measure the performance and correctness of your #
# implementation. We additionally compile an  unoptimized version that you can #
# use to debug your code in gdb.                                               #
#                                                                              #
# You may change  the flags below. CXXFLAGS will be  used when compiling every #
# C++  file for  both  variants. Below  that  you can  add  to the  EXTRAFLAGS #
# variable that applies only for either the optimized or unoptimized variants. #
################################################################################
CXXFLAGS += -g --std=c++17 -Werror -Wextra -Wall -fno-strict-aliasing
bookbuilder.unoptimized: EXTRAFLAGS += -O0
bookbuilder.optimized:   EXTRAFLAGS += -O3

################################################################################
######################## YOU CAN IGNORE BELOW THIS LINE ########################
################################################################################
CXXFLAGS += -Iabseil-cpp/
CXXFILES := $(shell find -maxdepth 1 -name "*.cc" -o -name "*.cpp" | cut -c3-)
HEADERS := $(shell find -maxdepth 1 -name "*.h" -o -name "*.hh" | cut -c3-)
CXXFILES := $(foreach f,$(CXXFILES),$(basename $(f)))
OBJS_OPTIMIZED := $(patsubst %,./build/optimized/%.o,$(CXXFILES))
OBJS_UNOPTIMIZED := $(patsubst %,./build/unoptimized/%.o,$(CXXFILES))
SHELL := /bin/bash
CXX=g++-8
LIBS := -L. -labsl

DATA ?= data/btcusd.medium.data
CHECK_DATA := data/btcusd.short.data
CHECK_PREFIX := $(patsubst %.data,%,$(CHECK_DATA))
PROF_OUT = ./prof.out

SOURCE_DEPS := ./build abseil-cpp
LINK_DEPS := ./build libabsl.a libprofiler.so

all: bookbuilder.optimized bookbuilder.unoptimized

check: all | $(CHECK_DATA)
	rm -f $(CHECK_PREFIX).candidate.out
	./bookbuilder.optimized $(CHECK_DATA) --check > $(CHECK_PREFIX).candidate.out
	diff -U1 $(CHECK_PREFIX).golden.out $(CHECK_PREFIX).candidate.out | head -10000 > output.diff || exit 0
	@echo
	@if [[ -s output.diff ]]  ; then \
		echo "Incorrect"; \
		echo; \
		head -7 output.diff; \
		echo; \
		echo "See the output.diff file for more"; \
	else \
		echo "Correct"; \
	fi

measure: all | $(DATA)
	./bookbuilder.optimized $(DATA) --measure

profile: profile_functions
profile_functions: $(PROF_OUT)
	./gperftools-2.9.1/src/pprof --text ./bookbuilder.optimized $(PROF_OUT)
profile_lines: $(PROF_OUT)
	./gperftools-2.9.1/src/pprof --text --lines ./bookbuilder.optimized $(PROF_OUT)
$(PROF_OUT): bookbuilder.unoptimized bookbuilder.optimized | $(DATA)
	LD_PRELOAD="./libprofiler.so ./libunwind.so.8" CPUPROFILE=$@ CPUPROFILE_FREQUENCY=1000 ./bookbuilder.optimized --measure $(DATA)

SEQNUM ?= 0
GDB_TARGET := unoptimized
gdb: all | $(DATA)
	gdb -ex run --args ./bookbuilder.$(GDB_TARGET) --breakpoint $(SEQNUM) $(DATA)

gdb_optimized: GDB_TARGET := optimized
gdb_optimized: gdb
gdb_unoptimized: gdb

bookbuilder.optimized: $(OBJS_OPTIMIZED)
bookbuilder.unoptimized: $(OBJS_UNOPTIMIZED)
bookbuilder.optimized bookbuilder.unoptimized: | $(LINK_DEPS)
	$(CXX) -o $@ $^ $(LIBS)
	@rm -f prof.out

$(OBJS_OPTIMIZED) $(OBJS_UNOPTIMIZED): $(HEADERS) | $(SOURCE_DEPS)
./build/optimized/%.o: %.cc
	$(CXX) $(CXXFLAGS) $(EXTRAFLAGS) -c -o $@ $<
./build/unoptimized/%.o: %.cc
	$(CXX) $(CXXFLAGS) $(EXTRAFLAGS) -c -o $@ $<

clean:
	rm -rf ./build/
	rm -f bookbuilder.optimized
	rm -f bookbuilder.unoptimized
	rm -f prof.out
	rm -f $(CHECK_PREFIX).candidate.out

./build:
	mkdir -p ./build/optimized ./build/unoptimized

.PHONY: all clean measure check profile profile_functions profile_lines gdb
.PHONY: gdb_optimized gdb_unoptimized
.DELETE_ON_ERROR:
