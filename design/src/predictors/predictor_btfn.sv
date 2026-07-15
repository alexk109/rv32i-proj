//Predict backwards taken, forwards not taken (BTFN)
//Predicts that if the next_PC is less than the current PC, then the branch is taken, otherwise it is not taken.

//stateless, built for loops

module predictor
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,

    // ---- PREDICT: queried in IF, combinational -------------------------
    input  logic [XLEN-1:0] predict_instr,   // the instruction being fetched
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
  //check the type of instruction to see if it is a branch or jump
  logic [6:0]     opccode;
  logic           is_branch;
  logic           is_jal;

  assign opccode   = predict_instr[6:0];
  assign is_branch = (opccode == OPC_BRANCH);
  assign is_jal    = (opccode == OPC_JAL);

  //immgen to find the branch target
  logic [XLEN-1:0] pred_imm;
  imm_gen pred_imm_gen 
  (
    .instr(predict_instr), 
   .imm(pred_imm)
   );

  assign predict_taken = (is_branch && predict_instr[31]) // if the instruction is a branch and the sign bit of the immediate negative, then it is taken,
                        || is_jal;                        // or take if unconditional jump (jal)

  assign predict_target = predict_pc + pred_imm; // if taken, the target is the current PC + the immediate value



  logic _unused;
  assign _unused = |{clk, rst_n, update_valid, update_pc, update_taken, update_target, update_mispred}; // tie off unused signals for lint

endmodule

