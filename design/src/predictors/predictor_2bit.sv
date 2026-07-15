//2 bit saturating predictor
//This is a simple 2-bit predictor that predicts taken if the last two branches were taken

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

  localparam PL_NUM_ENTRIES = 256; // 2^8 entries
  localparam PL_INDEX_WIDTH = $clog2(PL_NUM_ENTRIES); // number of bits needed to index into the predictor table
  // simple 2-bit predictor state
  typedef enum logic [1:0] {
    STRONGLY_NOT_TAKEN = 2'b00,
    WEAKLY_NOT_TAKEN   = 2'b01,
    WEAKLY_TAKEN       = 2'b10,
    STRONGLY_TAKEN     = 2'b11
  } predictor_state_t;

  predictor_state_t predictor_state [0:PL_NUM_ENTRIES-1]; // array of predictor states for each entry

  //check the type of instruction to see if it is a branch or jump
  logic [6:0]     opccode;
  logic           is_branch;
  logic           is_jal;

  assign opccode   = predict_instr[6:0];
  assign is_branch = (opccode == OPC_BRANCH);
  assign is_jal    = (opccode == OPC_JAL);

  //predict taken if the last two branches were taken, otherwise predict not taken
  assign predict_taken = (is_branch || is_jal) && (predictor_state[predict_pc[PL_INDEX_WIDTH+1:2]] == WEAKLY_TAKEN 
                                                || predictor_state[predict_pc[PL_INDEX_WIDTH+1:2]] == STRONGLY_TAKEN); 



  // Then we find the target:
  //immgen to find the branch target
  logic [XLEN-1:0] pred_imm;
  imm_gen pred_imm_gen 
  (
    .instr(predict_instr), 
   .imm(pred_imm)
   );


  assign predict_target = predict_pc + pred_imm; // if taken, the target is the current PC + the immediate value

  //update the predictor state based on the actual outcome of the branch/jump
  generate
    for (genvar i = 0; i < PL_NUM_ENTRIES; i++) begin : gen_predictor_state
       always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          predictor_state[i] <= STRONGLY_NOT_TAKEN;
        end
        else if (update_valid && (update_pc[PL_INDEX_WIDTH+1:2] == i)) begin
          case (predictor_state[i])
            STRONGLY_NOT_TAKEN: predictor_state[i] <= update_taken ? WEAKLY_NOT_TAKEN : STRONGLY_NOT_TAKEN;
            WEAKLY_NOT_TAKEN:   predictor_state[i] <= update_taken ? WEAKLY_TAKEN     : STRONGLY_NOT_TAKEN;
            WEAKLY_TAKEN:       predictor_state[i] <= update_taken ? STRONGLY_TAKEN   : WEAKLY_NOT_TAKEN;
            STRONGLY_TAKEN:     predictor_state[i] <= update_taken ? STRONGLY_TAKEN   : WEAKLY_TAKEN;
          endcase
        end
      end
    end
  endgenerate


  logic _unused;
  assign _unused = |{ update_pc, update_target, update_mispred}; // tie off unused signals for lint
  endmodule

