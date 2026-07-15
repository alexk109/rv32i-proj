# rv32i-core

A RISC-V RV32I CPU built from scratch in SystemVerilog, verified against the
official RISC-V ISA test suite.

**Status: Phase 1 complete — single-cycle core, 40/40 rv32ui tests passing.**

---

## Architecture

Single-cycle: every instruction fetches, decodes, executes, accesses memory, and
writes back within one clock. The only sequential state is the PC, the register
file, and data memory.

```
        ┌────┐   ┌──────────┐   ┌──────────┐   ┌─────┐   ┌──────────┐
  PC ──▶│imem│──▶│ decoder  │──▶│ operand  │──▶│ ALU │──▶│ data_mem │──┐
   ▲    └────┘   │ reg_file │   │  muxes   │   └─────┘   └──────────┘  │
   │             │ imm_gen  │   └──────────┘      │                     │
   │             └──────────┘                     │                     │
   │                  │                           │            ┌────────▼────────┐
   │                  ▼                           │            │ writeback mux   │
   │            ┌────────────┐                    │            │ ALU / MEM / PC+4│
   │            │ branch_cmp │────────────────┐   │            └────────┬────────┘
   │            └────────────┘                │   │                     │
   │                                          ▼   ▼                     ▼
   └──────────────────────────────────────┤ next_pc ├              reg_file (wr)
```

### Modules

| module | role |
|---|---|
| `riscv_pkg` | ISA encodings — opcodes, funct3/funct7, formats |
| `ctrl_pkg` | the `ctrl_t` control bundle and its enums |
| `decoder` | instruction → control bundle; detects illegal encodings |
| `imm_gen` | immediate reconstruction for all five formats (I/S/B/U/J) |
| `alu` | 10 operations, incl. `SRA`/`SLT`/`SLTU` |
| `branch_cmp` | the six branch conditions, gated by `ctrl.branch` |
| `next_pc` | PC+4 / branch target / jump target, with the JALR bit-0 clear |
| `reg_file` | 32×32, 2R/1W, x0 hardwired to zero |
| `instr_mem` | 4 KiB, combinational read |
| `data_mem` | 4 KiB, byte-lane write enables, sign/zero-extending loads |

Every module except the top carries forward unchanged into the Phase 2 pipeline.

---

## Features

- **Full RV32I base integer ISA** — all ~40 instructions
- **Sub-word memory** — `LB/LH/LW/LBU/LHU`, `SB/SH/SW` with byte-lane write
  enables and correct sign/zero extension
- **Illegal-instruction detection** — every encoding is illegal until a valid
  decode proves otherwise; nothing illegal can commit architectural state
- **RVFI retirement interface** — RISC-V Formal Interface ports, `` `ifdef ``-guarded,
  ready for Spike co-simulation and `riscv-formal`

### Not implemented (by design, Phase 1)

- **Traps / CSRs** — `ctrl.illegal` is computed but unconsumed. Phase 3E.
- **Misaligned access** — assumed not to occur. Phase 3E.
- **M extension** — no `MUL`/`DIV`. Phase 3D.

---

## Results

| | |
|---|---|
| **rv32ui ISA suite** | **40 / 40 passing** |
| Directed tests | 7 / 7 passing (~75 subtests) |
| Lint | clean, `verilator --lint-only -Wall`, both build configs |
| CPI | 1.0 (single-cycle, by construction) |
| C program (`arraysum`) | 208 cycles |
| RTL | 906 lines |

Two rv32ui tests are excluded, for architectural reasons rather than bugs:

- `ma_data` — misaligned access requires traps (Phase 3E)
- `fence_i` — self-modifying code is impossible on a Harvard core with separate
  instruction and data memories; `Zifencei` is not part of base RV32I

---

## Build and run

Requires [Verilator](https://verilator.org) and a bare-metal RISC-V toolchain
(`riscv32-unknown-elf-gcc`).

```sh
make lint                        # verilator + verible, both configs
make run PROG=smoke              # run one program, writes a VCD
make run PROG=arraysum           # the C program
make regress                     # the full rv32ui suite (clones riscv-tests)
make dump PROG=arraysum          # disassemble — read this when a test fails
```

### Layout

```
design/          the RTL
lint/            filelist + lint waivers
verif/           tb_cpu.cpp — the C++ harness
verif/sim/programs/   test program sources (.S and .c)
verif/sim/runs/       per-run artifacts: hex images, VCDs
doc/             plans, verification plan, test list
```

### Verification

Verilator compiles the RTL into C++; `verif/tb_cpu.cpp` is the `main()` linked
against it. Programs are self-checking, using the riscv-tests convention: a test
leaves `a0 == 0` to pass, and `gp` holding the number of the subtest that broke.
One harness serves the directed tests and the whole ISA suite.

Test programs are dependency-ordered — each only relies on what the previous ones
proved — and the suite is **mutation-tested**: injecting a known bug (deleting the
JALR bit-0 clear, breaking the byte-lane stride) makes exactly the intended
subtest fail.

---

## Roadmap

| phase | |
|---|---|
| **1. Single-cycle RV32I** | **complete** |
| 2. 5-stage pipeline | forwarding, hazard detection, branch prediction, Spike co-simulation |
| 3A. Caches | I$/D$ over a unified memory |
| 3B. AXI4-Lite | SoC-ready bus interface |
| 3C. FPGA | synthesis, timing closure, fmax/area numbers |
| 3D. M extension | multiply/divide |
| 3E. CSRs and traps | `mtvec`/`mepc`/`mcause`, ECALL, interrupts |
