//============================================================================
// pipe_pkg.sv
//
// The four pipeline-register bundles. One struct per stage boundary.
//
// Grouping each boundary into a single struct is what makes stall and flush
// one-liners later:
//
//   if      (!rst_n) id_ex_q <= '0;      // reset
//   else if (flush)  id_ex_q <= '0;      // insert a bubble
//   else if (!stall) id_ex_q <= id_ex_d; // advance
//   // else: hold -- a stall is literally "do not update"
//
// Resetting to '0 clears ctrl, which clears every commit signal (reg_write,
// mem_write, branch, jump, halt). So a bubble, a flushed instruction, and the
// garbage in the pipe at reset are all architecturally inert by construction --
// the same discipline the decoder uses.
//
// The `valid` bit says "a real instruction occupies this stage". It is 0 during
// the fill after reset, 0 in a bubble, and 0 in a flushed slot. The valid bit at
// the WB boundary is rvfi_valid, and it is what CPI counts.
//============================================================================
package pipe_pkg;

  import riscv_pkg::*;
  import ctrl_pkg::*;

  typedef struct packed {
    logic        valid;
    word_t       pc;
    word_t       pc_plus4;
    logic [31:0] instr;
  } if_id_t;

  // rs1_addr/rs2_addr are not needed to execute anything. They are here because
  // the forwarding unit compares them against EX/MEM.rd_addr and MEM/WB.rd_addr.
  typedef struct packed {
    logic        valid;
    ctrl_t       ctrl;
    word_t       pc;
    word_t       pc_plus4;
    word_t       imm;
    word_t       rs1_data;
    word_t       rs2_data;
    regaddr_t    rs1_addr;
    regaddr_t    rs2_addr;
    regaddr_t    rd_addr;
    logic [31:0] instr;
  } id_ex_t;

  // rs2_data rides on: in EX it was an ALU operand, but its other consumer is
  // data_mem.wdata in MEM. Same value, two jobs, two stages.
  typedef struct packed {
    logic        valid;
    ctrl_t       ctrl;
    word_t       pc;
    word_t       pc_plus4;
    word_t       alu_result;
    word_t       rs2_data;
    regaddr_t    rd_addr;
    word_t       next_pc;
    logic [31:0] instr;
  } ex_mem_t;

  typedef struct packed {
    logic        valid;
    ctrl_t       ctrl;
    word_t       pc;
    word_t       pc_plus4;
    word_t       alu_result;
    word_t       mem_rdata;
    regaddr_t    rd_addr;
    word_t       next_pc;
    logic [31:0] instr;
    word_t       mem_addr;
    logic [3:0]  mem_rmask;
    logic [3:0]  mem_wmask;
    word_t       mem_wdata;
  } mem_wb_t;

endpackage : pipe_pkg
