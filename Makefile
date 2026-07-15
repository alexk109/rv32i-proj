# Build flow for the single-cycle RV32I core.
# Run from the repo root. Everything is driven off lint/cpu_rtl.f.

VERILATOR      ?= verilator
VERIBLE_LINT   ?= verible-verilog-lint
VERIBLE_FORMAT ?= verible-verilog-format

# The toolchain lives under $HOME/tools and is not on PATH for non-interactive
# shells, so name it explicitly. Override on the command line if it moves.
RISCV_PREFIX   ?= $(HOME)/tools/riscv/bin/riscv32-unknown-elf-
RVCC           := $(RISCV_PREFIX)gcc
RVOBJCOPY      := $(RISCV_PREFIX)objcopy
RVOBJDUMP      := $(RISCV_PREFIX)objdump

RTL_F     := lint/cpu_rtl.f
WAIVERS   := lint/waivers.vlt
TOP       ?= cpu_single_cycle_top

# Branch predictor scheme. Every scheme lives in design/src/predictor_<name>.sv
# and defines a module named `predictor`, so exactly ONE is in the build at a
# time — appended to the verilator command, not the shared filelist. The wildcard
# keeps the build working before any predictor_*.sv exists.
PREDICTOR ?= none
PRED_SRC  := $(wildcard design/src/predictors/predictor_$(PREDICTOR).sv)

VERIF     := verif
PROGRAMS  := $(VERIF)/sim/programs
RUNS      := $(VERIF)/sim/runs
OBJ_DIR   := $(VERIF)/sim/obj_dir_$(TOP)_$(PREDICTOR)
TB_SRC    := $(VERIF)/tb_cpu.cpp
SIM_BIN   := $(OBJ_DIR)/V$(TOP)

# Which program to run, and which run directory its output lands in:
#   make run PROG=smoke RUN=phase1_smoke
PROG      ?= smoke
RUN       ?= phase1_smoke
RUN_DIR   := $(RUNS)/$(RUN)

# Verible takes a plain file list, so pull the .sv lines back out of the filelist.
RTL_SRCS  := $(shell grep -E '\.sv$$' $(RTL_F))

# -Wall is the project gate: no warnings, not just no errors.
VFLAGS    := -Wall

# RVFI is verification-only. Defining it exposes the retirement interface on the
# top; leaving it undefined is what Phase 3C synthesis will build.
RVFI      ?= 1
ifeq ($(RVFI),1)
  VFLAGS += +define+RVFI
endif

# -Ttext=0 matters: RESET_PC is 0 and instr_mem indexes from 0, so the program must
# link to start there. -nostdlib keeps out a C runtime the core cannot run.
RVCFLAGS  := -march=rv32i -mabi=ilp32 -nostdlib -Ttext=0

# Verilator is 2-state, so an undriven signal reads as 0 rather than X. Randomizing
# what would have been X turns "accidentally correct because it was 0" into a loud
# nondeterministic failure, which is where reset bugs hide.
SIMFLAGS  := --x-assign unique --x-initial unique

.PHONY: all lint lint-verilator lint-verible lint-synth fmt fmt-check sim run dump diff diffall verify regress rv32ui-fetch clean help

all: lint

## lint: both linters, which is the bar RTL has to clear before it counts as done
lint: lint-verilator lint-verible

## lint-verilator: elaborate the whole core and check it (with RVFI)
lint-verilator:
	$(VERILATOR) --lint-only $(VFLAGS) $(WAIVERS) -f $(RTL_F) $(PRED_SRC) --top-module $(TOP)

## lint-synth: elaborate WITHOUT RVFI — the config Phase 3C will actually synthesize
lint-synth:
	$(VERILATOR) --lint-only -Wall $(WAIVERS) -f $(RTL_F) $(PRED_SRC) --top-module $(TOP)

## lint-verible: style and naming rules, per-file
lint-verible:
	$(VERIBLE_LINT) $(RTL_SRCS)

## fmt: rewrite sources in canonical format, in place
fmt:
	$(VERIBLE_FORMAT) --inplace $(RTL_SRCS)

## fmt-check: fail if anything is unformatted, without touching the files
fmt-check:
	$(VERIBLE_FORMAT) --verify $(RTL_SRCS)

#-----------------------------------------------------------------------------
# Software: assembly -> ELF -> flat binary -> $readmemh image
#
# $readmemh wants one 32-bit word per line as bare hex. objcopy gives a flat
# little-endian binary; od regroups it into words and tr puts one per line.
# Sources live in verif/sim/programs; every artifact lands in the run directory.
#-----------------------------------------------------------------------------

$(RUN_DIR)/%.elf: $(PROGRAMS)/%.S
	@mkdir -p $(RUN_DIR)
	$(RVCC) $(RVCFLAGS) -o $@ $<

# C programs need crt0 (stack pointer, .bss zeroing, the call to main) and a link
# script that packs .data right after .text -- the default one page-aligns it,
# which would push it past the end of both memories.
CLINK     := $(PROGRAMS)/link.ld
CRT0      := $(PROGRAMS)/crt0.S
RVCFLAGS_C := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -O2 -T $(CLINK)

$(RUN_DIR)/%.elf: $(PROGRAMS)/%.c $(CRT0) $(CLINK)
	@mkdir -p $(RUN_DIR)
	$(RVCC) $(RVCFLAGS_C) -o $@ $(CRT0) $<

$(RUN_DIR)/%.bin: $(RUN_DIR)/%.elf
	$(RVOBJCOPY) -O binary $< $@

$(RUN_DIR)/%.hex: $(RUN_DIR)/%.bin
	od -An -tx4 -v $< | tr -s ' ' '\n' | grep . > $@

## dump: disassemble a program, e.g. make dump PROG=smoke — read this when a test fails
dump: $(RUN_DIR)/$(PROG).elf
	$(RVOBJDUMP) -d $<

.PRECIOUS: $(RUN_DIR)/%.elf $(RUN_DIR)/%.bin $(RUN_DIR)/%.hex

#-----------------------------------------------------------------------------
# Simulation
#
# Verilator compiles the RTL into a C++ class; verif/tb_cpu.cpp is the main() that
# drives it. So `sim` is a real compile (slow), and `run` is just an executable.
#-----------------------------------------------------------------------------

## sim: verilate + compile the testbench into an executable
sim: $(SIM_BIN)

# The TB includes a header named after the top module, so it must be told which
# core it is being linked against.
ifeq ($(TOP),cpu_pipeline_top)
  TBFLAGS := -CFLAGS -DPIPELINE
endif

$(SIM_BIN): $(RTL_SRCS) $(PRED_SRC) $(TB_SRC) $(WAIVERS)
	$(VERILATOR) $(VFLAGS) $(SIMFLAGS) $(WAIVERS) $(TBFLAGS) \
	  --cc --exe --build --trace \
	  -f $(RTL_F) $(PRED_SRC) --top-module $(TOP) \
	  --Mdir $(OBJ_DIR) $(abspath $(TB_SRC))

## run: run a program on the core, e.g. make run PROG=smoke RUN=phase1_smoke
#
# instr_mem and data_mem both $readmemh unconditionally at time 0, so BOTH images
# must exist or the sim dies before executing anything. The data image is zeroed
# rather than absent, so a run is reproducible.
run: $(SIM_BIN) $(RUN_DIR)/$(PROG).hex
	@cp $(RUN_DIR)/$(PROG).hex $(RUN_DIR)/instr_mem.hex
	@{ cat $(RUN_DIR)/$(PROG).hex; yes 00000000 | head -1024; } | head -1024 \
	  > $(RUN_DIR)/data_mem_init.hex
	cd $(RUN_DIR) && $(abspath $(SIM_BIN))

#-----------------------------------------------------------------------------
# Golden-model equivalence: run a program on BOTH cores and diff their
# retirement streams. The single-cycle core is the reference. Identical streams
# mean the pipeline commits the same architectural effects in the same order,
# regardless of stalls/flushes. This catches pipeline-only bugs (a bad forward, a
# missed flush) that a self-checking test can miss. It is also the exact shape
# Spike co-simulation will take — swap single-cycle's log for Spike's.
#-----------------------------------------------------------------------------

DIFF_PROGS ?= smoke alu branch lui_auipc mem jump x0 hazards arraysum bubblesort search statemachine

# Every predictor scheme must keep the equivalence green — prediction changes
# timing, never architectural results. The JAL-link forwarding bug was invisible
# with PREDICTOR=none and only appeared under btfn, which is exactly why `verify`
# sweeps all of them.
PREDICTORS ?= none btfn 2bit

## diff: run PROG on both cores and diff retirement streams (pipeline uses PREDICTOR)
#
# The `|| true` matters: a failing run (wrong result -> exit 1, or a timeout) must
# NOT abort the recipe before the comparison, or the failure is silently dropped.
# A non-zero run still leaves a partial retire.log, and the length/content diff
# then reports it as a mismatch — which is exactly the failure we want to see.
diff:
	@$(MAKE) -s run TOP=cpu_single_cycle_top PROG=$(PROG) RUN=diff_$(PROG)_sc   >/dev/null 2>&1 || true
	@$(MAKE) -s run TOP=cpu_pipeline_top PREDICTOR=$(PREDICTOR) PROG=$(PROG) RUN=diff_$(PROG)_pipe >/dev/null 2>&1 || true
	@if diff -q $(RUNS)/diff_$(PROG)_sc/retire.log $(RUNS)/diff_$(PROG)_pipe/retire.log >/dev/null 2>&1; then \
	  echo "  DIFF OK    $(PROG)"; \
	else \
	  echo "  DIFF FAIL  $(PROG)  (single-cycle vs pipeline[$(PREDICTOR)] mismatch or run error):"; \
	  diff $(RUNS)/diff_$(PROG)_sc/retire.log $(RUNS)/diff_$(PROG)_pipe/retire.log 2>&1 | head -6; \
	fi

## diffall: equivalence-check every DIFF_PROGS on the pipeline (PREDICTOR) vs golden
diffall:
	@$(MAKE) -s sim TOP=cpu_single_cycle_top >/dev/null 2>&1
	@$(MAKE) -s sim TOP=cpu_pipeline_top PREDICTOR=$(PREDICTOR) >/dev/null 2>&1
	@echo "pipeline[$(PREDICTOR)] vs single-cycle (golden) — retirement equivalence:"
	@for p in $(DIFF_PROGS); do $(MAKE) -s diff PROG=$$p PREDICTOR=$(PREDICTOR); done

## verify: full functional check — diffall + rv32ui for EVERY predictor scheme
verify:
	@for pred in $(PREDICTORS); do \
	  echo "==================== PREDICTOR=$$pred ===================="; \
	  $(MAKE) -s diffall PREDICTOR=$$pred; \
	  $(MAKE) -s regress TOP=cpu_pipeline_top PREDICTOR=$$pred | grep '^rv32ui'; \
	done

#-----------------------------------------------------------------------------
# riscv-tests (rv32ui)
#
# The stock "p" environment sets up trap vectors and touches mtvec/mstatus, which
# this core has no CSRs for. verif/sim/riscv-tests/env/riscv_test.h is a CSR-free
# replacement; link.ld packs .data right after .text so the flat image stays small.
#
# This is a Harvard core: instr_mem and data_mem are separate arrays that both
# start at address 0. The tests keep their data (tdat, etc.) in the SAME image as
# their code, so the same flat image is loaded into BOTH memories. That is what
# makes `lw a0, tdat` find the right bytes.
#
# ma_data is excluded: it tests misaligned access, which requires traps (Phase 3E).
#-----------------------------------------------------------------------------

RVT_DIR    := verif/sim/riscv-tests
RVT_SRC    := $(RVT_DIR)/upstream
RVT_ENV    := $(RVT_DIR)/env
RVT_LD     := $(RVT_DIR)/link.ld
RVT_RUN    := $(RUNS)/rv32ui
# ma_data: misaligned access needs traps (Phase 3E).
# fence_i: self-modifying code — impossible on a Harvard core with separate
#          instr_mem/data_mem. Also Zifencei, not base RV32I.
RVT_EXCL   := ma_data fence_i

RVT_CFLAGS := -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
              -I $(RVT_ENV) -I $(RVT_SRC)/isa/macros/scalar -T $(RVT_LD)

## rv32ui-fetch: clone the official riscv-tests suite (once)
rv32ui-fetch:
	@test -d $(RVT_SRC) || git clone -q --depth 1 \
	  https://github.com/riscv-software-src/riscv-tests.git $(RVT_SRC)
	@echo "riscv-tests at $(RVT_SRC)"

## regress: build and run the whole rv32ui suite; prints a pass/fail table
regress: $(SIM_BIN) rv32ui-fetch
	@pass=0; fail=0; failed=""; \
	for t in $(RVT_SRC)/isa/rv32ui/*.S; do \
	  n=$$(basename $$t .S); \
	  case " $(RVT_EXCL) " in *" $$n "*) continue ;; esac; \
	  d=$(RVT_RUN)/$$n; mkdir -p $$d; \
	  $(RVCC) $(RVT_CFLAGS) -o $$d/$$n.elf $$t 2>/dev/null || \
	    { echo "  BUILD-FAIL $$n"; fail=$$((fail+1)); continue; }; \
	  $(RVOBJCOPY) -O binary $$d/$$n.elf $$d/$$n.bin; \
	  od -An -tx4 -v $$d/$$n.bin | tr -s ' ' '\n' | grep . > $$d/instr_mem.hex; \
	  { cat $$d/instr_mem.hex; yes 00000000 | head -1024; } | head -1024 > $$d/data_mem_init.hex; \
	  out=$$( (cd $$d && timeout 30 $(abspath $(SIM_BIN))) 2>&1 | grep -E '^(PASS|FAIL|ERROR)' | head -1); \
	  case "$$out" in \
	    PASS*) pass=$$((pass+1)) ;; \
	    *) fail=$$((fail+1)); failed="$$failed\n  $$n: $$out" ;; \
	  esac; \
	done; \
	echo "rv32ui: $$pass passed, $$fail failed  (excluded: $(RVT_EXCL))"; \
	if [ $$fail -ne 0 ]; then printf "$$failed\n"; exit 1; fi

clean:
	rm -rf $(VERIF)/sim/obj_dir_*
	find $(RUNS) -mindepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
	find $(RUNS) -type f ! -name '.gitkeep' -delete

help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
