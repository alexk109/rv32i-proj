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
    input logic        clk,
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
    input logic [31:0] mem_wb_rs2_rdata,

    // retirement stream -- for order monotonicity
    input logic         rvfi_valid,
    input logic [63:0]  rvfi_order
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

  // ------------------------------------------------------------------------
  // Order monotonicity: rvfi_order this cycle equals last cycle's rvfi_order
  // plus last cycle's rvfi_valid -- the RTL's own update rule
  // (`rvfi_order_q <= rvfi_order_q + rvfi_valid`), restated one cycle later
  // instead of referenced directly, so it can be asserted unconditionally.
  //
  // First attempt used a "have I seen a prior sample" gate (skip the check
  // until the second valid retirement) and got the arithmetic wrong besides
  // (rvfi_order is 0 at the FIRST valid retirement, not 1 -- it's a
  // combinational read of the not-yet-incremented register, so the
  // increment for retirement N is visible starting at retirement N+1). The
  // gate was also the wrong instinct on its own: it carves out one frame per
  // induction window where the invariant is vacuously satisfied regardless
  // of value, and the solver exploited exactly that to seed rvfi_order at an
  // arbitrary value chosen to collide with another frame in the same
  // window -- refuting unique_ch0/causal_ch0 without corresponding to any
  // reachable behavior.
  //
  // This version has no gate, matches the RTL's actual timing, and is TRUE
  // (BMC confirms it) -- but still leaves unique_ch0/causal_ch0/pc_bwd_ch0
  // UNKNOWN under induction. Traced the counterexample down to the actual
  // cause: the checker's OWN bookkeeping (rvfi_unique_check.sv's
  // `found_other_insn`, reset only inside `if (reset)`) is just as free at
  // frame 0 as any register of ours -- induction assumes reset stays off
  // for the whole window, so the solver can seed found_other_insn = 1 at
  // frame 0 for free, and nothing in the checker's own logic ever clears it
  // back to 0. `assert(!found_other_insn)` then fails at the check cycle
  // independent of whether rvfi_order is well-behaved. No invariant stated
  // purely in terms of our design's signals can reach into a checker
  // module's local state to fix this. Kept anyway: it's a real, useful,
  // BMC-proven fact, just not the missing piece for these three.
  logic [63:0] order_before;
  logic        valid_before;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      order_before <= 64'd0;
      valid_before <= 1'b0;
    end else begin
      order_before <= rvfi_order;
      valid_before <= rvfi_valid;
    end
  end

  always @* if (rst_n)
    assert (rvfi_order == order_before + {63'd0, valid_before});

  // reg_ch0 needs "the operand an instruction reports reading is the most
  // recent architectural write to that register" -- a register-file fact.
  // Three encodings tried, all dropped:
  //   - dynamic lookup indexed by the pipeline's own per-cycle-varying
  //     rs*_addr: ~10s BMC check -> no result in 15 minutes.
  //   - a single (* anyconst *)-selected index (riscv-formal's own
  //     rand_const_reg register_index trick): cheap, but a literal
  //     tautology (`assert(x == x)` on the same dynamic part-select) failed
  //     under BMC -- an anyconst-driven dynamic part-select interacting
  //     badly with something in this solver/toolchain, not chased further.
  //   - a generate-loop of 32 STATIC per-register bit-slices (no dynamic
  //     indexing at all): correct, but the 64 added comparisons per cycle
  //     were themselves too expensive -- no result within reasonable time.
  // reg_ch0 stays UNKNOWN under induction; it still passes BMC at both
  // configured depths, so there's no known counterexample, just no proof
  // for all time.

endmodule

// Port expressions are elaborated in the scope of the bound instance, so
// these reach directly into cpu_core's internals.
bind cpu_core formal_invariants formal_invariants_i (
    .clk               (clk),
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
    .mem_wb_rs2_rdata  (mem_wb_q.rs2_rdata),

    .rvfi_valid        (rvfi_valid),
    .rvfi_order        (rvfi_order)
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
