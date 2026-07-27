# cpu-project

A pipelined RV32I RISC-V core, verified three independent ways: golden-model
simulation, bounded model checking, and unbounded (all-time) formal proof.

- **Design**: 5-stage pipeline (IF/ID/EX/MEM/WB) with forwarding, load-use
  stall, and a choice of 4 branch predictors, plus a single-cycle reference
  core used as a golden model.
- **Simulation**: Verilator, self-checking directed tests + the official
  `riscv-tests` rv32ui suite, run against all 4 predictors.
- **Formal**: [riscv-formal](https://github.com/YosysHQ/riscv-formal) via an
  RVFI interface, checked with SymbiYosys. Every property passes bounded
  model checking; most are proved for all time via k-induction.

```
design/          RTL: pipeline top, single-cycle golden model, packages, units
verif/sim/       Verilator testbench, directed test programs, riscv-tests glue
verif/formal/    riscv-formal harness, invariants, check config, scripts
tools/           vendored + built dependencies for the formal flow (below)
results/         predictor performance writeup
lint/            Verilator/Verible config and waivers
```

## Building and running

```
make lint             # Verilator + Verible on both cores
make sim              # verilate + build the pipelined core (add TOP=cpu_single_cycle_top for the golden model)
make run PROG=smoke   # run one program, print its retirement trace
make dump PROG=smoke  # disassemble a program
make verify            # the full functional check -- see below
make stats             # CPI / flush-rate tables across predictors
```

`PREDICTOR` selects the branch predictor (`none btfn 2bit gshare`, default
`none`); `PROG`/`RUN` select which program and output directory `make run`
uses. `make help` lists every target with a one-line description.

## How correctness is checked

Three methods, in increasing order of strength. Each catches a class of bug
the others don't.

### 1. Golden-model equivalence + the official ISA test suite

```
make verify
```

For every predictor, this runs a set of directed programs (`alu`, `branch`,
`mem`, `hazards`, `bubblesort`, ...) on **both** cores and diffs their
retirement streams instruction-for-instruction, then runs the official
[riscv-tests](https://github.com/riscv-software-src/riscv-tests) `rv32ui`
suite. The single-cycle core is the reference: if the pipeline commits the
same architectural effects in the same order regardless of stalls/flushes,
the streams are identical. This is what caught a JAL-link forwarding bug that
was invisible with `PREDICTOR=none` and only appeared once branches were
actually mispredicted — which is why `verify` sweeps every predictor rather
than checking one.

```
==================== PREDICTOR=gshare ====================
pipeline[gshare] vs single-cycle (golden) — retirement equivalence:
  DIFF OK    smoke
  DIFF OK    alu
  DIFF OK    branch
  ...
  DIFF OK    statemachine
rv32ui: 40 passed, 0 failed  (excluded: ma_data fence_i)
```
(repeated for `none`, `btfn`, `2bit`, `gshare` — real output, `make verify`,
2026-07-26)

`ma_data` is excluded because it tests misaligned-access trapping, which is
implemented at the detection/suppression level (see Limitations) but has no
CSR/handler yet. `fence_i` needs self-modifying code, impossible on this
Harvard-memory core.

### 2. Formal: bounded model checking (BMC)

```
make formal-setup      # once
make formal-gen
make formal-run
make formal-status
```

riscv-formal generates one property per RV32I instruction (does its result
match a reference model?), plus cross-instruction properties (register
forwarding, PC chaining, retirement ordering, ...) — 43 checks in total. BMC
proves no violation exists within a bounded number of cycles (15–20,
covering pipeline fill, a load-use stall, and a misprediction flush).

```
=== riscv-formal: cpu_pipeline ===

  PASS 43
```
(real output, `make formal-run` in BMC mode, 43/43, 2026-07-26)

A `make formal-gen FORMAL_CFG=deep` variant doubles every depth (~30 cycles)
as a sanity check against depth-dependent artifacts; it also passes 43/43.

### 3. Formal: unbounded proof (k-induction)

```
make formal-gen FORMAL_MODE=prove
make formal-run
make formal-status
```

BMC only rules out counterexamples within N cycles. k-induction proves a
property for **all** N — a genuine "correct forever" result — but only if the
property is *inductive*: true not just in reachable states, but in every
state the transition relation doesn't explicitly forbid. Pipeline properties
usually aren't inductive as stated (see `verif/formal/invariants.sv`), so
induction alone leaves most checks `UNKNOWN` rather than proving them.

Adding a handful of hand-written strengthening invariants (`x0 reads as zero`
at every pipeline stage, asserted rather than assumed so they're proved
alongside everything else) converts most of those `UNKNOWN`s into proofs:

```
=== riscv-formal: cpu_pipeline ===

  PASS 39   UNKNOWN 4
```
(real output, `make formal-gen FORMAL_MODE=prove && make formal-run`, 2026-07-26)

Every instruction-correctness check is proved for all time. The remaining
`UNKNOWN`s are the checks that reason about *two* retirements at once
(register-forwarding consistency, causality, backward PC chaining) — they
need invariants relating pipeline state to the register file. A version of
that was tried (six dynamic selects out of the flattened register file, one
per source operand per pipeline stage) and dropped: it turned a ~10s BMC
check into one that didn't return in 15 minutes. They still pass BMC at both
depths, so there's strong bounded evidence and no known counterexample;
they're just not proved unbounded.

## The formal toolchain

Everything the formal flow needs beyond `yosys`/`verilator`/`z3` lives inside
this repo, either vendored or built by a setup script — nothing depends on
paths outside the project.

```
tools/riscv-formal/    vendored (checks/ + insns/ from upstream, committed)
tools/yosys-slang/     SystemVerilog frontend plugin, built by tools/setup.sh
tools/yices/           SMT solver, downloaded prebuilt by tools/setup.sh
tools/sby/             SymbiYosys, patched + built by tools/setup.sh
```

`make formal-setup` runs `tools/setup.sh`, which is idempotent — safe to
re-run, each step skips if already built. `yosys`, `verilator`, and
(optionally) `z3` are treated as system prerequisites, the same tier as a C
compiler, and are checked but not vendored.

**Why yosys-slang.** The core uses `module X import pkg::*;` headers and a
package (`pipe_pkg`) that references a type from another package
(`ctrl_pkg::ctrl_t`). Yosys's built-in SystemVerilog frontend rejects the
first and can't elaborate the second at all, so the design is read through
[yosys-slang](https://github.com/povik/yosys-slang) instead — configured in
`verif/formal/checks.cfg` under `[script-defines]`.

**Why a patched sby.** `abc pdr` (IC3), the strongest engine for unbounded
proofs, needs its design converted to an AIG first. sby's own AIG-generation
script runs `setundef` too early — a later pass (`aigmap`) can reintroduce
`x`/`z` bits that `write_aiger` then rejects. `tools/patches/` carries a
one-line fix (a second `setundef -anyseq` right before the write), applied
automatically by `tools/setup.sh`.

**Why `FORMAL_ENGINES` defaults to one engine.** `engines.py` can make sby
race several engines and take the first conclusive answer — useful in
principle, since smtbmc (k-induction) and abc pdr (IC3) have different
strengths. In practice, racing more than one engine under `FORMAL_MODE=prove`
reliably leaves sby's process alive after it has already written a correct
result (a reaping bug in how it tears down the losing engine, reproduced
consistently, not occasional). `tools/bin/sby` wraps every invocation in an
external `timeout` as a backstop, so a hung check is bounded rather than
infinite, but it still costs the full backstop duration even though the
result was ready in seconds — so racing is opt-in, not default:
```
make formal-run FORMAL_ENGINES="smtbmc yices;smtbmc z3"   # reliable under bmc
make formal-run FORMAL_ENGINES="smtbmc yices;abc pdr"      # needs the patch above
```

## Scripts in `verif/formal/`

| File | Purpose |
|---|---|
| `checks.cfg` | What `make formal-gen` generates: ISA, solver, per-check depths, defines, the trap/RVFI conventions this core uses. Read this first to understand *why* a given depth or define is set the way it is — every non-obvious choice has a comment. |
| `deep.cfg` | Same properties at ~2x depth, generated into a separate directory (`FORMAL_CFG=deep`) so it never clobbers the standard results. |
| `wrapper.sv` | Connects `cpu_pipeline_top` to riscv-formal's RVFI checker and declares the two free variables (fetched instruction, loaded word) the whole proof depends on. |
| `invariants.sv` | The strengthening invariants for k-induction, `bind`-attached so the core RTL stays untouched. |
| `engines.py` | `genchecks.py` hardcodes one engine and no timeout; this rewrites the generated `.sby` files to use `FORMAL_ENGINES` (one engine by default, can race several) under `FORMAL_TIMEOUT`. Run automatically by `make formal-gen`. |
| `status.py` | Reads every check's result and groups failures by the assertion that broke, resolving each back to its source line — what `make formal-status` runs. |
| `gtkw/rv32i_disasm.py` | GTKWave translate-filter-process: renders `rvfi_insn` (and any `_instr` signal) as an RV32I mnemonic instead of a raw hex word. |
| `gtkw/*.txt` | GTKWave translate-filter-files that turn the enum fields in `ctrl_pkg` (`alu_op`, `branch_op`, ...) back into names — yosys flattens SystemVerilog enums to plain bits, so without these a waveform just shows `01`. |

Viewing a counterexample trace (Windows GTKWave from WSL):

```
gtkwave.exe "$(wslpath -w tools/riscv-formal/cores/cpu_pipeline/checks/<check>/engine_0/trace.vcd)"
```

## Other Makefile targets

`formal-redo CHECK=<name>` re-runs one check; `formal-cover` runs just the
vacuity check (that the harness can retire instructions at all — everything
else is meaningless if this doesn't pass); `formal-status-all` adds
per-check runtimes; `formal-clean` drops the generated check tree.
`lint-synth` lints the core without the RVFI port block, the configuration
that will actually be synthesized.

## Known limitations

- **No CSRs, no Zicsr, no interrupts.** Misaligned data access and misaligned
  branch/jump targets are *detected* in EX and *suppressed* (no memory
  access, no register write, no redirect to a bad target) — enough to satisfy
  riscv-formal's trap properties — but there's no `mtvec`/`mepc`/`mcause` and
  no handler, so it isn't a real trap vector yet.
- **`verible-verilog-lint` isn't installed in this environment** — `make
  lint-verible` (part of `make lint`) will fail with "command not found"
  until it is. `make lint-verilator`, the RTL-correctness half, doesn't need
  it and passes clean.
- gshare ties the simpler 2-bit bimodal predictor rather than beating it —
  a non-speculative global history register lags the pipeline by a few
  cycles. See `results/predictor_results.md` for the full writeup and the
  fix (speculative GHR with rollback on flush).

## Predictor performance

Four predictors (`none`, `btfn`, `2bit`, `gshare`), CPI and control-hazard
cost across the branch-heavy benchmark suite: **`results/predictor_results.md`**.
Headline: CPI 1.463 → 1.090 and flush cycles/instruction 0.219 → 0.032 (−85%)
going from no prediction to a per-PC 2-bit bimodal predictor.
