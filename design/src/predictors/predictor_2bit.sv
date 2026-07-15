//2 bit saturating predictor
//This is a simple 2-bit predictor that predicts taken if the last two branches were taken

module predictor
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,

    // ---- PREDICT: queried in IF, combinational -------------------------
    input  logic [XLEN-1:0] instr,           // the instruction being fetched
    input  logic [XLEN-1:0] predict_pc,      // the PC being fetched
    output logic            predict_taken,   // guess: is this a taken branch/jump?
    output logic [XLEN-1:0] predict_target,  // guess: where does it go?

    // ---- UPDATE: driven from EX when a branch actually resolves ---------
    input  logic            update_valid,    // a real branch retired-for-prediction
    input  logic [XLEN-1:0] update_pc,       // its PC
    input  logic            update_taken,    // its ACTUAL outcome
    input  logic [XLEN-1:0] update_target,   // its ACTUAL target
    input  logic            update_mispred   // prediction was wrong (for stats/training)
);

  // simple 2-bit predictor state
  typedef enum logic [1:0] {
    STRONGLY_NOT_TAKEN = 2'b00,
    WEAKLY_NOT_TAKEN   = 2'b01,
    WEAKLY_TAKEN       = 2'b10,
    STRONGLY_TAKEN     = 2'b11
  } predictor_state_t;

  predictor_state_t predictor_state;


  assign predict_taken = (predictor_state == WEAKLY_TAKEN || predictor_state == STRONGLY_TAKEN);
  assign predict_target = predict_pc + 4; // this is a don't care, since



  endmodule