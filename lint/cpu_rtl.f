// RTL filelist for the single-cycle core.
// Paths are relative to the repo root; run the tools from there (the Makefile does).
// Packages must come first — they define the types every module imports.

design/pkg/riscv_pkg.sv
design/pkg/ctrl_pkg.sv

design/src/alu.sv
design/src/imm_gen.sv
design/src/decoder.sv
design/src/reg_file.sv
design/src/branch_cmp.sv
design/src/next_pc.sv
design/src/instr_mem.sv
design/src/data_mem.sv

design/cpu_single_cycle_top.sv
