// riscv-formal harness for cpu_core.
//
// riscv-formal drives clock/reset (reset is active-high) and expects RVFI
// exposed through `RVFI_CONN32. The core's instruction and data memories are
// external, so this wrapper supplies them with a free-variable mem_responder:
// the fetched word and the read data word are unconstrained, which is what
// makes the instruction and load checks non-vacuous (it also gives up
// fetch/store coherence -- see checks.cfg on why bus_imem isn't run). The free
// variables live here, in a file read by yosys's native frontend, because
// yosys-slang silently ignores (* anyseq *)/`rvformal_rand_reg.

module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);
	// The free variables of the whole proof: leaving these unconstrained is
	// what lets the solver try any instruction for a fetch and any word for a
	// load, making the checks non-vacuous.
	(* keep *) `rvformal_rand_reg [31:0] formal_imem_data;
	(* keep *) `rvformal_rand_reg [31:0] formal_dmem_rdata;

	// core <-> memory buses
	(* keep *) wire [31:0] imem_addr;
	(* keep *) wire [31:0] imem_rdata;
	(* keep *) wire [31:0] dmem_addr;
	(* keep *) wire [31:0] dmem_wdata;
	(* keep *) wire        dmem_read;
	(* keep *) wire        dmem_write;
	(* keep *) wire [2:0]  dmem_size;
	(* keep *) wire [31:0] dmem_rdata;
	(* keep *) wire [31:0] dmem_rdata_raw;

	// kept so yosys doesn't optimize away the cones feeding these, which would
	// make counterexample traces harder to read
	(* keep *) wire [31:0] pc_out;
	(* keep *) wire [31:0] instr_out;
	(* keep *) wire        halt;
	(* keep *) wire        perf_stall;
	(* keep *) wire        perf_flush;

	cpu_core uut (
		.clk        (clock     ),
		.rst_n      (!reset    ),

		.imem_addr      (imem_addr     ),
		.imem_rdata     (imem_rdata    ),
		.dmem_addr      (dmem_addr     ),
		.dmem_wdata     (dmem_wdata    ),
		.dmem_read      (dmem_read     ),
		.dmem_write     (dmem_write    ),
		.dmem_size      (dmem_size     ),
		.dmem_rdata     (dmem_rdata    ),
		.dmem_rdata_raw (dmem_rdata_raw),

		.pc_out     (pc_out    ),
		.instr_out  (instr_out ),
		.halt       (halt      ),

		`RVFI_CONN32,

		.perf_stall (perf_stall),
		.perf_flush (perf_flush)
	);

	mem_responder mem_responder_i (
		.free_iword     (formal_imem_data ),
		.imem_rdata     (imem_rdata       ),
		.dmem_read      (dmem_read        ),
		.dmem_size      (dmem_size        ),
		.dmem_addr_byte (dmem_addr[1:0]   ),
		.free_dword     (formal_dmem_rdata),
		.dmem_rdata     (dmem_rdata       ),
		.dmem_rdata_raw (dmem_rdata_raw   )
	);
endmodule
