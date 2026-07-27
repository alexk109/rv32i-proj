// Strengthening invariants for k-induction (mode prove).
//
// BMC only ever visits reachable states; induction starts from an arbitrary
// one and has to be told what a reachable state looks like. The dominant
// induction failure without these is rvfi_insn_check.sv:167,
// `if (rs2_addr == 0) assert(rs2_rdata == 0)`, which induction can break by
// starting from a state where mem_wb_q claims rs2_addr==0 with a garbage
// rs2_rdata -- a state the core can never actually reach.
//
// These are asserts, not assumes: sby proves each one at every check it's
// compiled into, so a wrong invariant fails loudly instead of silently
// voiding every proof resting on it.
//
// Attached by `bind` so the core stays clean, and read via read_slang
// alongside the design (see [script-defines] in checks.cfg) -- the built-in
// yosys frontend used for [verilog-files] can't bind into a slang-elaborated
// module.

module formal_invariants (
    input logic        rst_n,

    input logic [4:0]  id_ex_rs1_addr,
    input logic [4:0]  id_ex_rs2_addr,
    input logic [31:0] id_ex_rs1_data,
    input logic [31:0] id_ex_rs2_data,

    input logic [4:0]  ex_mem_rs1_addr,
    input logic [4:0]  ex_mem_rs2_addr,
    input logic [31:0] ex_mem_rs1_rdata,
    input logic [31:0] ex_mem_rs2_rdata,

    input logic [4:0]  mem_wb_rs1_addr,
    input logic [4:0]  mem_wb_rs2_addr,
    input logic [31:0] mem_wb_rs1_rdata,
    input logic [31:0] mem_wb_rs2_rdata
);

  // x0 reads as zero at every stage that carries a source-register value.
  // Each is only inductive if the stage feeding it is too, back to the
  // register file -- hence all three rather than just MEM/WB (what RVFI
  // reports).
  always @* if (rst_n) begin
    if (id_ex_rs1_addr == 5'd0)  assert (id_ex_rs1_data  == 32'd0);
    if (id_ex_rs2_addr == 5'd0)  assert (id_ex_rs2_data  == 32'd0);

    if (ex_mem_rs1_addr == 5'd0) assert (ex_mem_rs1_rdata == 32'd0);
    if (ex_mem_rs2_addr == 5'd0) assert (ex_mem_rs2_rdata == 32'd0);

    if (mem_wb_rs1_addr == 5'd0) assert (mem_wb_rs1_rdata == 32'd0);
    if (mem_wb_rs2_addr == 5'd0) assert (mem_wb_rs2_rdata == 32'd0);
  end

endmodule

// Port expressions are elaborated in the scope of the bound instance, so
// these reach directly into cpu_pipeline_top's internals.
bind cpu_pipeline_top formal_invariants formal_invariants_i (
    .rst_n             (rst_n),

    .id_ex_rs1_addr    (id_ex_q.rs1_addr),
    .id_ex_rs2_addr    (id_ex_q.rs2_addr),
    .id_ex_rs1_data    (id_ex_q.rs1_data),
    .id_ex_rs2_data    (id_ex_q.rs2_data),

    .ex_mem_rs1_addr   (ex_mem_q.rs1_addr),
    .ex_mem_rs2_addr   (ex_mem_q.rs2_addr),
    .ex_mem_rs1_rdata  (ex_mem_q.rs1_rdata),
    .ex_mem_rs2_rdata  (ex_mem_q.rs2_rdata),

    .mem_wb_rs1_addr   (mem_wb_q.rs1_addr),
    .mem_wb_rs2_addr   (mem_wb_q.rs2_addr),
    .mem_wb_rs1_rdata  (mem_wb_q.rs1_rdata),
    .mem_wb_rs2_rdata  (mem_wb_q.rs2_rdata)
);

// x0's root cause lives inside reg_file, and --keep-hierarchy forbids
// reaching across a module boundary from the bind above, so it gets its own.
// True in every reachable state -- reg_file resets the whole array and
// forces '0 on any write to index 0 -- but induction has to be told.
module formal_regfile_invariants (
    input logic        rst_n,
    input logic [31:0] x0_value
);
  always @* if (rst_n) assert (x0_value == 32'd0);
endmodule

bind reg_file formal_regfile_invariants formal_regfile_invariants_i (
    .rst_n    (rst_n),
    .x0_value (regs[0])
);
