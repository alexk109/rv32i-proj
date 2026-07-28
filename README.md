
Design and verification of a CPU using RV32I base instruction set. 4 stage pipeline with prediction and hazard detection. 


## Highlights

- **Branch prediction**
I wrote 3 predictors - a two bit predictor, backwards taken forwards nottake (BTFN) predictor, and a global shared history predictor (gshare). 
Across 3 sample programs written to show common branch problems, we can predict the branch over 95% of the time. 

```
Cycles per Instruction (CPI) table:
| predictor          | bubblesort | search | statemachine | **aggregate** |
|--------------------|-----------:|-------:|-------------:|--------------:|
| none (not-taken)   |      1.660 |  1.454 |        1.413 |     **1.463** |
| btfn (static)      |      1.337 |  1.009 |        1.167 |     **1.165** |
| 2bit bimodal (PHT) |      1.256 |  1.011 |        1.070 |     **1.090** |
| gshare (8-bit GHR) |      1.261 |  1.016 |        1.074 |     **1.094** |
```

- **Formal verification** using [riscv-formal](https://github.com/YosysHQ/riscv-formal)
  and SymbiYosys, passing 43/43 tests with BMC for depth 30 (far beyond pipeline depth)
  and **39/43 are proved for k-induction.** I wrote invariant assertions to meet k-induction,
  going from 4 tests completing for k-induction, to 39. 

- **Verified all instructions with golden model**: the pipeline's RVFI retirement stream matches a
  single-cycle reference instruction-for-instruction, across all 4 predictors,
  plus it passes the official `riscv-tests` rv32ui suite. As shown above, we can run common programs like
  bubblesort and binary search. 

(image.png)
A simple program doing some addis and then storing and loading the result, shown in gtkwave



## Quick start guide

```
make verify         # golden-model diff + official ISA test suite, on all predictors
make stats          # CPI and flush-rate tables for all predictors
make formal-setup && make formal-gen && make formal-run && make formal-status
```

`make help` lists every target.

## Repo layout

```
design/          RTL: pipeline top, single-cycle golden model, packages, units
verif/sim/       Verilator testbench, directed test programs, riscv-tests glue
verif/formal/    riscv-formal harness, invariants, check config, scripts
tools/           self-contained formal toolchain (vendored + built by setup)
results/         branch predictor performance writeup
```

