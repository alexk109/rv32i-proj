// riscv-formal harness for cpu_pipeline_top.
//
// riscv-formal drives `clock`/`reset` (reset is ACTIVE HIGH) and expects the DUT
// to expose the RVFI channel through the `RVFI_CONN32 macro, whose named port
// connections match the rvfi_* port names on the core one-for-one.
//
// The core has no imem/dmem bus ports -- both memories live inside it. The
// instruction fetch is turned into a free variable by the `RISCV_FORMAL` branch
// in design/src/instr_mem.sv, which is what lets the solver explore every RV32I
// encoding instead of one $readmemh image.

module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);
	// THE free variables of the whole proof. `rvformal_rand_reg` is riscv-formal's
	// portable spelling; under yosys it expands to a bare `wire`, which combined
	// with (* keep *) yields a genuine per-cycle free value.
	//
	// These MUST live here rather than inside the memories. wrapper.sv is read by
	// yosys's native SystemVerilog frontend, which honours (* anyseq *) and this
	// idiom; the core itself is read by yosys-slang, which silently ignores both
	// (* anyseq *) and $anyseq -- verified by comparing `stat` output between the
	// two frontends. A free variable declared inside the core is therefore just an
	// undriven wire, and the optimizer resolves its fanout paths independently, so
	// two readers of the "same" word can see different values.
	//
	// Leaving them unconstrained is what lets the solver return ANY instruction for
	// a fetch and ANY word for a load, which is what makes the checks non-vacuous.
	// It also means fetch/store coherence is deliberately given up -- see the note
	// in checks.cfg about the bus_imem and memory-consistency checks.
	(* keep *) `rvformal_rand_reg [31:0] formal_imem_data;
	(* keep *) `rvformal_rand_reg [31:0] formal_dmem_rdata;

	// Non-RVFI core outputs. Kept so yosys does not optimise the cones feeding
	// them away, which keeps counterexample traces readable.
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
