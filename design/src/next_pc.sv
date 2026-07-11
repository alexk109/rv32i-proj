// next pc combinational logic

module next_pc
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
  input  [XLEN-1:0]   pc,
  input  [XLEN-1:0]   pc_plus4,     // taken from top signal
  input  [XLEN-1:0]   rs1_val,      // for JALR base
  input  [XLEN-1:0]   imm,          // from imm_gen — already the right format (B/J/I)
  input               jalr,         // from ctrl: 1 = JALR, 0 = JAL
  input               jump,         // from ctrl
  input               branch_taken, // from branch_cmp: condition result, gated by ctrl.branch externally or here
  output [XLEN-1:0]   pc_next
);

  logic [XLEN-1:0] target_base;
  logic [XLEN-1:0] target_raw;
  logic [XLEN-1:0] target;
  logic  take_redirect;

  // if JALR, base is rs1, else PC
  assign target_base = jalr ? rs1_val : pc;
  assign target_raw   = target_base + imm; // the raw target is always the base plus the immediate

  // JALR clears the LSB to prevent misalignment
  //JAL and branches don't need to because the immediate is already aligned
  assign target = jalr ? {target_raw[31:1], 1'b0} : target_raw;

  // take redirect if we are jumping or branching
  assign take_redirect = jump || (branch_taken);

  // next-PC output mux
  assign pc_next = take_redirect ? target : pc_plus4;

endmodule

