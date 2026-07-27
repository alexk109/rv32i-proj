// The four pipeline-register bundles, one struct per stage boundary. Grouping
// each boundary into a struct makes reset/flush/stall a one-liner:
// `if (!rst_n || flush) q <= '0; else if (!stall) q <= d;` -- and resetting to
// '0 clears ctrl along with everything else, so a bubble, a flushed slot, and
// reset garbage are all architecturally inert for free. `valid` marks a real
// instruction in that stage; at the WB boundary it's rvfi_valid.
package pipe_pkg;

  import riscv_pkg::*;
  import ctrl_pkg::*;

  typedef struct packed {
    logic                   valid;
    logic                   predict_taken;  //from predictor
    word_t                  predict_target; //target if taken
    logic [PRED_HIST_W-1:0] predict_ghr;    //history snapshot used for this prediction
    word_t                  pc;
    word_t                  pc_plus4;
    logic [31:0]            instr;
  } if_id_t;

  // rs1_addr/rs2_addr are not needed to execute anything. They are here because
  // the forwarding unit compares them against EX/MEM.rd_addr and MEM/WB.rd_addr.
  typedef struct packed {
    logic                   valid;
    ctrl_t                  ctrl;
    logic                   predict_taken;  //from predictor
    word_t                  predict_target; //target if taken
    logic [PRED_HIST_W-1:0] predict_ghr;    //history snapshot used for this prediction
    word_t                  pc;
    word_t                  pc_plus4;
    word_t                  imm;
    word_t       rs1_data;
    word_t       rs2_data;
    regaddr_t    rs1_addr;
    regaddr_t    rs2_addr;
    regaddr_t    rd_addr;
    logic [31:0] instr;
  } id_ex_t;

  // rs2_data rides on: an ALU operand in EX, then data_mem.wdata in MEM.
  // rs1/rs2 addr+rdata ride along purely for RVFI, and must be the
  // post-forwarding values (ex_rs1/ex_rs2) -- what the instruction actually used.
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
    regaddr_t    rs1_addr;
    regaddr_t    rs2_addr;
    word_t       rs1_rdata;
    word_t       rs2_rdata;
    logic        trap;         // misaligned access/target, detected in EX
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
    regaddr_t    rs1_addr;
    regaddr_t    rs2_addr;
    word_t       rs1_rdata;
    word_t       rs2_rdata;
    word_t       mem_rdata_raw;  // pre-extension word, for RVFI only
    logic        trap;           // rides to WB so the trap commits in order
  } mem_wb_t;

endpackage : pipe_pkg
