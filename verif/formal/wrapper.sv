// riscv-formal harness for cpu_pipeline_top.
//
// riscv-formal drives clock/reset (reset is active-high) and expects RVFI
// exposed through `RVFI_CONN32, whose named connections match the core's
// rvfi_* ports one-for-one. The core has no imem/dmem bus ports -- both
// memories live inside it -- so this wrapper is also where the fetch and load
// data become free variables (see design/src/instr_mem.sv).

module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);
	// The free variables of the whole proof: leaving these unconstrained is
	// what lets the solver try any instruction for a fetch and any word for a
	// load, making the checks non-vacuous (it also means fetch/store coherence
	// is given up -- see checks.cfg on why bus_imem isn't run). They live here,
	// not inside the memories, because this file goes through yosys's native
	// frontend, which honours (* anyseq *)/`rvformal_rand_reg`; the core goes
	// through yosys-slang, which silently ignores both.
	(* keep *) `rvformal_rand_reg [31:0] formal_imem_data;
	(* keep *) `rvformal_rand_reg [31:0] formal_dmem_rdata;

	// kept so yosys doesn't optimize away the cones feeding these, which would
	// make counterexample traces harder to read
	(* keep *) wire [31:0] pc_out;
	(* keep *) wire [31:0] instr_out;
	(* keep *) wire        halt;
	(* keep *) wire        perf_stall;
	(* keep *) wire        perf_flush;

	cpu_pipeline_top uut (
		.clk        (clock     ),
		.rst_n      (!reset    ),

		.pc_out     (pc_out    ),
		.instr_out  (instr_out ),
		.halt       (halt      ),

		.formal_imem_data  (formal_imem_data ),
		.formal_dmem_rdata (formal_dmem_rdata),

		`RVFI_CONN32,

		.perf_stall (perf_stall),
		.perf_flush (perf_flush)
	);
endmodule
