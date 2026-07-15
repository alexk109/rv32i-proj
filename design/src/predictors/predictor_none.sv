//baseline, always predicts not taken, and target is PC+4s

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

    //always predicts not taken
    assign predict_taken = 1'b0;

    assign predict_target = predict_pc + 4; // this is a don't care, since predict_taken is always 0, but it is required to be a valid value


     // everything else is unused but tied off for lint
    logic _unused;
    assign _unused = |{clk, rst_n, instr, predict_pc, update_valid, update_pc,
                      update_taken, update_target, update_mispred};

endmodule
