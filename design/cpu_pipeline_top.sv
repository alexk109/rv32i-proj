// 5-stage pipelined RV32I core: IF / ID / EX / MEM / WB.


module cpu_pipeline_top
  import riscv_pkg::*;
  import ctrl_pkg::*;
  import pipe_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,

    output logic [XLEN-1:0] pc_out,
    output logic [XLEN-1:0] instr_out,
    output logic            halt

`ifdef RVFI
    ,
    output logic            rvfi_valid,
    output logic [31:0]     rvfi_insn,
    output logic [XLEN-1:0] rvfi_pc_rdata,
    output logic [XLEN-1:0] rvfi_pc_wdata,
    output logic [4:0]      rvfi_rd_addr,
    output logic [XLEN-1:0] rvfi_rd_wdata,
    output logic [XLEN-1:0] rvfi_mem_addr,
    output logic [3:0]      rvfi_mem_rmask,
    output logic [3:0]      rvfi_mem_wmask,
    output logic [XLEN-1:0] rvfi_mem_rdata,
    output logic [XLEN-1:0] rvfi_mem_wdata,

    // Cycle-level performance signals (not part of formal RVFI, which is
    // retirement-only). These pulse per cycle so the testbench can attribute the
    // gap between cycles and retired instructions to stalls vs flushes.
    output logic            perf_stall,
    output logic            perf_flush
`endif
);

  if_id_t  if_id_d,  if_id_q;
  id_ex_t  id_ex_d,  id_ex_q;
  ex_mem_t ex_mem_d, ex_mem_q;
  mem_wb_t mem_wb_d, mem_wb_q;


  //signals to update the branch predictor, driven from EX stage
  logic            update_valid;
  logic [XLEN-1:0] update_pc;
  logic            update_taken;
  logic [XLEN-1:0] update_target;
  logic            update_mispred;

  // ======================= IF =========================================

  logic            stall;

  //next PC logic and prediction
  logic [XLEN-1:0] pc_q;
  logic [XLEN-1:0] pc_d;
  logic [XLEN-1:0] pc_plus4;
  logic [XLEN-1:0] if_instr;
  
  logic            flush;

  logic            predict_taken;
  logic [XLEN-1:0] predict_target;

  logic            ex_redirect; //redirect for flushing, if we predicted PC wrong
  logic [XLEN-1:0] ex_target;

  
  //hazard detection: checks for load-use hazard
  assign stall =  id_ex_q.valid && id_ex_q.ctrl.mem_read  // instr in EX is a load
                  && (id_ex_q.rd_addr != 5'd0)            // not x0

                   //but we need that value in ID, so we stall IF and ID for one cycle
                  && ( ( id_ctrl.uses_rs1 && (id_ex_q.rd_addr == if_id_q.instr[19:15]) )
                    || ( id_ctrl.uses_rs2 && (id_ex_q.rd_addr == if_id_q.instr[24:20]) ) );


  //next PC reg
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc_q <= RESET_PC;
    else if (!stall) //stalls disable IF stage
      pc_q <= pc_d;
  
  end

  //predictor
  predictor predictor_i (
  .clk             (clk),   // I 
  .rst_n           (rst_n), // I

  // ---- PREDICT: queried in IF, combinational -------------------------
  .predict_instr   (if_instr),        // I: the instruction being fetched in IF
  .predict_pc      (pc_q),            // I: the PC being fetched in IF
  .predict_taken   (predict_taken),   // O
  .predict_target  (predict_target),  // O [XLEN-1:0]

  // Updates from EX used to update the predictor state, not to compute the next PC
  .update_valid    (update_valid),
  .update_pc       (update_pc), 
  .update_taken    (update_taken),
  .update_target   (update_target), 
  .update_mispred  (update_mispred)  
);

  assign pc_plus4 = pc_q + 32'd4;
  assign pc_d =      ex_redirect     ? ex_target         // EX correction — real branch from EX stage
                   : predict_taken   ? predict_target    // predicted guess
                   :                   pc_plus4;         // sequential 

  assign flush    = ex_redirect; // flush IF/ID register on branch/jump


  //instruction memory
  instr_mem instr_mem_i (
    .addr  (pc_q    ),
    .instr (if_instr)
  );


  //IF/ID pipeline register
  always_comb begin
    if_id_d                = '0;
    if_id_d.valid          = 1'b1;
    if_id_d.predict_taken  = predict_taken;
    if_id_d.predict_target = predict_target;
    if_id_d.pc             = pc_q;
    if_id_d.pc_plus4       = pc_plus4;
    if_id_d.instr          = if_instr;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
      if_id_q <= '0;
    else if (flush)
      if_id_q <= '0;
    else if (!stall) //stalls disable IF/ID reg
      if_id_q <= if_id_d;
  end

  // ======================= ID =========================================

  ctrl_t           id_ctrl;
  logic [XLEN-1:0] id_imm;
  logic [XLEN-1:0] id_rs1_data;
  logic [XLEN-1:0] id_rs2_data;

  decoder decoder_i (
    .instr (if_id_q.instr),
    .ctrl  (id_ctrl      )
  );

  imm_gen imm_gen_i (
    .instr (if_id_q.instr),
    .imm   (id_imm       )
  );

  // Writeback comes from the WB stage, four instructions behind whatever ID is
  // reading. Without a write-first bypass, a read that collides with the write
  // sees the OLD value -- one more RAW case, and the reason reg_file gains an
  // internal bypass in the next step.
  logic [XLEN-1:0] wb_rd_data;
  logic            wb_reg_write;

  reg_file reg_file_i (
    .clk       (clk                 ),
    .rst_n     (rst_n               ),
    .rs1_addr  (if_id_q.instr[19:15]),
    .rs2_addr  (if_id_q.instr[24:20]),
    .wr_addr   (mem_wb_q.rd_addr    ),
    .wr_data   (wb_rd_data          ),
    .reg_write (wb_reg_write        ),
    .rs1_data  (id_rs1_data         ),
    .rs2_data  (id_rs2_data         )
  );

  always_comb begin
    id_ex_d                = '0;
    id_ex_d.valid          = if_id_q.valid;
    id_ex_d.ctrl           = id_ctrl;
    id_ex_d.predict_taken  = if_id_q.predict_taken;
    id_ex_d.predict_target = if_id_q.predict_target;
    id_ex_d.pc             = if_id_q.pc;
    id_ex_d.pc_plus4       = if_id_q.pc_plus4;
    id_ex_d.imm            = id_imm;
    id_ex_d.rs1_data       = id_rs1_data;
    id_ex_d.rs2_data       = id_rs2_data;
    id_ex_d.rs1_addr       = if_id_q.instr[19:15];
    id_ex_d.rs2_addr       = if_id_q.instr[24:20];
    id_ex_d.rd_addr        = if_id_q.instr[11:7];
    id_ex_d.instr          = if_id_q.instr;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
      id_ex_q <= '0;
    else if(flush || stall) //stalls have to clear id_ex register
      id_ex_q <= '0;
    else             
      id_ex_q <= id_ex_d;
  end

  // ======================= EX =========================================
  
  //forwarding logic:
  // if the instruction in EX needs a register that is being written by MEM or WB, forward the value from the later stage
  logic [XLEN-1:0] mem_alu_result; // signal from MEM stage to forward to EX stage
  logic [XLEN-1:0] ex_rs1;
  logic [XLEN-1:0] ex_rs2;

  logic [XLEN-1:0] alu_input_a;
  logic [XLEN-1:0] alu_input_b;
  
  assign ex_rs1 = (id_ex_q.ctrl.uses_rs1 && ex_mem_q.valid && ex_mem_q.ctrl.reg_write && (ex_mem_q.rd_addr == id_ex_q.rs1_addr) && (ex_mem_q.rd_addr != 5'd0)) ? mem_alu_result :         //forward from MEM stage
                  (id_ex_q.ctrl.uses_rs1 && mem_wb_q.valid && mem_wb_q.ctrl.reg_write && (mem_wb_q.rd_addr == id_ex_q.rs1_addr) && (mem_wb_q.rd_addr != 5'd0)) ? wb_rd_data            //forward from WB stage
                                                                                                                                                                : id_ex_q.rs1_data;    //no forwarding, use value from ID stage

  assign ex_rs2 = (id_ex_q.ctrl.uses_rs2 && ex_mem_q.valid && ex_mem_q.ctrl.reg_write && (ex_mem_q.rd_addr == id_ex_q.rs2_addr) && (ex_mem_q.rd_addr != 5'd0)) ? mem_alu_result :         //forward from MEM stage
                  (id_ex_q.ctrl.uses_rs2 && mem_wb_q.valid && mem_wb_q.ctrl.reg_write && (mem_wb_q.rd_addr == id_ex_q.rs2_addr) && (mem_wb_q.rd_addr != 5'd0)) ? wb_rd_data            //forward from WB stage
                                                                                                                                                                : id_ex_q.rs2_data;    // no forward

  //prediction signals and logic back to ID
  logic [XLEN-1:0] ex_alu_result;
  logic            ex_branch_taken;
  logic            actual_taken; //prediction was correct or not

  assign actual_taken = ex_branch_taken || id_ex_q.ctrl.jump;
 
  //update the predictor with the actual outcome of the branch/jump
  assign update_valid   = id_ex_q.valid && (id_ex_q.ctrl.branch || id_ex_q.ctrl.jump);
  assign update_pc      = id_ex_q.pc;
  assign update_taken   = actual_taken;
  assign update_target  = ex_next_pc;    //correct target from next_pc logic in EX stage
  assign update_mispred = ex_redirect;   //prediction was wrong if we had to redirect


  always_comb begin
    case (id_ex_q.ctrl.alu_src_a)
      OPA_RS1:  alu_input_a = ex_rs1;
      OPA_PC:   alu_input_a = id_ex_q.pc;
      OPA_ZERO: alu_input_a = '0;
      default:  alu_input_a = '0;
    endcase
  end

  assign alu_input_b = id_ex_q.ctrl.alu_src_b ? id_ex_q.imm : ex_rs2;

  alu alu_i (
    .a      (alu_input_a  ),
    .b      (alu_input_b  ),
    .op     (id_ex_q.ctrl.alu_op),
    .result (ex_alu_result)
  );

  branch_cmp branch_cmp_i (
    .rs1          (ex_rs1              ),
    .rs2          (ex_rs2              ),
    .branch_op    (id_ex_q.ctrl.branch_op),
    .branch       (id_ex_q.ctrl.branch ),
    .branch_taken (ex_branch_taken     )
  );

  logic [XLEN-1:0] ex_next_pc;

  next_pc next_pc_i (
    .pc           (id_ex_q.pc      ),
    .pc_plus4     (id_ex_q.pc_plus4),
    .rs1_val      (ex_rs1          ),
    .imm          (id_ex_q.imm     ),
    .jalr         (id_ex_q.ctrl.jalr),
    .jump         (id_ex_q.ctrl.jump),
    .branch_taken (ex_branch_taken ),
    .pc_next      (ex_next_pc      )
  );

  // Redirect for a mispredicted branch or jump.
  assign ex_redirect = id_ex_q.valid && (
                       (actual_taken != id_ex_q.predict_taken) ||                     // mispredicted branch
                       (actual_taken && (ex_next_pc != id_ex_q.predict_target)));     // mispredicted target for taken branch/jump

  assign ex_target   = ex_next_pc;

  always_comb begin
    ex_mem_d            = '0;
    ex_mem_d.valid      = id_ex_q.valid;
    ex_mem_d.ctrl       = id_ex_q.ctrl;
    ex_mem_d.pc         = id_ex_q.pc;
    ex_mem_d.pc_plus4   = id_ex_q.pc_plus4;
    ex_mem_d.alu_result = ex_alu_result;
    ex_mem_d.rs2_data   = ex_rs2;
    ex_mem_d.rd_addr    = id_ex_q.rd_addr;
    ex_mem_d.next_pc    = ex_next_pc;
    ex_mem_d.instr      = id_ex_q.instr;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) 
      ex_mem_q <= '0;
    else        
      ex_mem_q <= ex_mem_d;
  end

  // ======================= MEM ========================================

  //forwarding signal to EX stage
  assign mem_alu_result = (ex_mem_q.ctrl.result_sel == RESULT_PC4) ? ex_mem_q.pc_plus4 : ex_mem_q.alu_result; //forward the correct value to EX stage, either ALU result or PC+4 for JAL/JALR
  
  logic [XLEN-1:0] mem_rdata;

  // gate with valid to prevent bubbles from touching memory
  logic mem_read_q;
  logic mem_write_q;

  assign mem_read_q  = ex_mem_q.valid && ex_mem_q.ctrl.mem_read;
  assign mem_write_q = ex_mem_q.valid && ex_mem_q.ctrl.mem_write;

  data_mem #(
    .DMEM_SIZE (1024                ),
    .DMEM_FILE ("data_mem_init.hex" )
  ) data_mem_i (
    .clk       (clk                ),
    .rst_n     (rst_n              ),
    .addr      (ex_mem_q.alu_result),
    .wdata     (ex_mem_q.rs2_data  ),
    .mem_read  (mem_read_q         ),
    .mem_write (mem_write_q        ),
    .memsize   (ex_mem_q.ctrl.mem_size),
    .rdata     (mem_rdata          )
  );

   // RVFI outputs
  logic [3:0] mem_rmask;
  logic [3:0] mem_wmask;

  always_comb begin
    mem_rmask = 4'b0000;
    if (mem_read_q) begin
      case (ex_mem_q.ctrl.mem_size)
        F3_LB, F3_LBU: mem_rmask = 4'b0001 << ex_mem_q.alu_result[1:0];
        F3_LH, F3_LHU: mem_rmask = 4'b0011 << ex_mem_q.alu_result[1:0];
        F3_LW:         mem_rmask = 4'b1111;
        default:       mem_rmask = 4'b0000;
      endcase
    end
  end

  always_comb begin
    mem_wmask = 4'b0000;
    if (mem_write_q) begin
      case (ex_mem_q.ctrl.mem_size)
        F3_SB:   mem_wmask = 4'b0001 << ex_mem_q.alu_result[1:0];
        F3_SH:   mem_wmask = 4'b0011 << ex_mem_q.alu_result[1:0];
        F3_SW:   mem_wmask = 4'b1111;
        default: mem_wmask = 4'b0000;
      endcase
    end
  end

  always_comb begin
    mem_wb_d            = '0;
    mem_wb_d.valid      = ex_mem_q.valid;
    mem_wb_d.ctrl       = ex_mem_q.ctrl;
    mem_wb_d.pc         = ex_mem_q.pc;
    mem_wb_d.pc_plus4   = ex_mem_q.pc_plus4;
    mem_wb_d.alu_result = ex_mem_q.alu_result;
    mem_wb_d.mem_rdata  = mem_rdata;
    mem_wb_d.rd_addr    = ex_mem_q.rd_addr;
    mem_wb_d.next_pc    = ex_mem_q.next_pc;
    mem_wb_d.instr      = ex_mem_q.instr;
    mem_wb_d.mem_addr   = {ex_mem_q.alu_result[XLEN-1:2], 2'b00};
    mem_wb_d.mem_rmask  = mem_rmask;
    mem_wb_d.mem_wmask  = mem_wmask;
    mem_wb_d.mem_wdata  = ex_mem_q.rs2_data << {ex_mem_q.alu_result[1:0], 3'b000};
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) mem_wb_q <= '0;
    else        mem_wb_q <= mem_wb_d;
  end

  // ======================= WB =========================================

  //result select mux -- selects which of the three possible results to write back to the reg file
  always_comb begin
    case (mem_wb_q.ctrl.result_sel)
      RESULT_ALU: wb_rd_data = mem_wb_q.alu_result;
      RESULT_MEM: wb_rd_data = mem_wb_q.mem_rdata;
      RESULT_PC4: wb_rd_data = mem_wb_q.pc_plus4;
      default:    wb_rd_data = '0;
    endcase
  end

  assign wb_reg_write = mem_wb_q.valid && mem_wb_q.ctrl.reg_write;

  // ------------------------ outputs -----------------------------------

  // halt must come from WB, not from decode. An ECALL in ID has four instructions
  // ahead of it still in flight; halting there would stop the clock before they
  // wrote back, and the testbench would read stale registers.
  assign halt      = mem_wb_q.valid && mem_wb_q.ctrl.halt;
  assign pc_out    = pc_q;
  assign instr_out = if_instr;

  // ======================= RVFI =======================================
`ifdef RVFI

  logic rvfi_rd_written;
  assign rvfi_rd_written = wb_reg_write && (mem_wb_q.rd_addr != 5'd0);

  assign rvfi_valid     = mem_wb_q.valid;
  assign rvfi_insn      = mem_wb_q.instr;
  assign rvfi_pc_rdata  = mem_wb_q.pc;
  assign rvfi_pc_wdata  = mem_wb_q.next_pc;
  assign rvfi_rd_addr   = rvfi_rd_written ? mem_wb_q.rd_addr : 5'd0;
  assign rvfi_rd_wdata  = rvfi_rd_written ? wb_rd_data       : '0;
  assign rvfi_mem_addr  = mem_wb_q.mem_addr;
  assign rvfi_mem_rmask = mem_wb_q.mem_rmask;
  assign rvfi_mem_wmask = mem_wb_q.mem_wmask;
  assign rvfi_mem_rdata = mem_wb_q.mem_rdata;
  assign rvfi_mem_wdata = mem_wb_q.mem_wdata;

  assign perf_stall = stall;
  assign perf_flush = flush;

`endif

endmodule
