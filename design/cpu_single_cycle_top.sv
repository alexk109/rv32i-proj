// Top module for RISC V CPU
// single cycle implementation

module cpu_single_cycle_top
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,

    output logic [XLEN-1:0] pc_out,
    output logic [XLEN-1:0] instr_out,
    output logic            halt

`ifdef RVFI
    // RV formal interface for verification purposes
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

    // Present for a uniform testbench interface. A single-cycle core never stalls
    // or flushes, so both are constant 0 and its CPI is exactly 1.0.
    output logic            perf_stall,
    output logic            perf_flush
`endif
);

  // internal signal declaration
  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] next_pc;
  logic [XLEN-1:0] pc_plus4;
  logic [XLEN-1:0] instr;
  logic [XLEN-1:0] imm;
  logic [XLEN-1:0] rs1_data;
  logic [XLEN-1:0] rs2_data;
  logic [XLEN-1:0] rd_data;      // result of mux in WB stage, to be written to regfile
  logic [XLEN-1:0] alu_result;   // result of ALU operation
  logic [XLEN-1:0] mem_rdata;    // Load data from memory
  logic            branch_taken; // result of branch comparator, gated by ctrl.branch
  ctrl_t           ctrl;

  // ------------------------ IF -------------------------------

  ////////////////////////////
  // PC register and next pc logic
  ////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= '0;
    end
    else begin
        pc <= next_pc;
    end
  end

  next_pc next_pc_i(
    .pc            (pc          ),  // I [XLEN-1:0] current PC
    .pc_plus4      (pc_plus4    ),  // I [XLEN-1:0] PC + 4, from top
    .rs1_val       (rs1_data    ),  // I [XLEN-1:0] rs1 value, for JALR base
    .imm           (imm         ),  // I [XLEN-1:0] immediate, from imm_gen
    .jalr          (ctrl.jalr   ),  // I
    .jump          (ctrl.jump   ),  // I
    .branch_taken  (branch_taken),  // I
    .pc_next       (next_pc     )   // O [XLEN-1:0] next PC
  );

  assign pc_plus4 = pc + 4;
  

  ////////////////////////////
  // instruction memory
  ////////////////////////////
  instr_mem #(
    .IMEM_SIZE(1025), //size in words
    .MEM_FILE("instr_mem.hex")
  ) instr_mem_i(
        .addr      (pc         ),   // I [XLEN-1:0] address
        .instr     (instr      )    // O [XLEN-1:0] instruction
 );

  // ------------------------ ID -------------------------------


  ////////////////////////////
  // Register file
  ////////////////////////////

  reg_file #(
    .P_ENABLE_BYPASS (0) // bypass logic to prevent read-after-write hazards, disable for single cycle
  )reg_file_i(
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(instr[19:15]),
    .rs2_addr(instr[24:20]),
    .wr_addr(instr[11:7]),
    .wr_data(rd_data),
    .reg_write(ctrl.reg_write),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
  );

  ////////////////////////////
  // decoder
  ////////////////////////////
  decoder decoder_i(
      .instr(instr),
      .ctrl(ctrl)
  );

  ////////////////////////////
  // Immediate generator
  ////////////////////////////
  imm_gen imm_gen_i(
    .instr(instr),
    .imm(imm)
  );


  // ------------------------ EX -------------------------------
  /////////////////////////////
  // branch comparator
  /////////////////////////////

  branch_cmp branch_cmp_i(
    .rs1(rs1_data),
    .rs2(rs2_data),
    .branch_op(ctrl.branch_op),
    .branch(ctrl.branch),
    .branch_taken(branch_taken)
  );

  /////////////////////////////
  // alu input muxing
  /////////////////////////////
  logic [XLEN-1:0] alu_input_a;
  logic [XLEN-1:0] alu_input_b;

  always_comb begin
    case (ctrl.alu_src_a)
      OPA_RS1: alu_input_a = rs1_data;
      OPA_PC:  alu_input_a = pc;
      OPA_ZERO:alu_input_a = '0;
      default: alu_input_a = '0;
    endcase
  end

  assign alu_input_b = ctrl.alu_src_b ? imm : rs2_data;
  
  ////////////////////////////
  // ALU
  ////////////////////////////
  alu alu_i(
    .a(alu_input_a),
    .b(alu_input_b),
    .op(ctrl.alu_op),
    .result(alu_result)
  );

  // ------------------------ MEM -------------------------------

  /////////////////////////////
  // data memory
  /////////////////////////////
  data_mem #(
  .DMEM_SIZE(1024),               //size in words
  .DMEM_FILE("data_mem_init.hex") // initialization file
  ) data_mem_i (

  //clk and reset
  .clk         ( clk       ), // I
  .rst_n       ( rst_n     ), //I

  //address and write data
  .addr        ( alu_result ), // I [XLEN-1:0] address from ALU result
  .wdata       ( rs2_data   ), // I [XLEN-1:0] data to write from rs2

  //control signal
  .mem_read    ( ctrl.mem_read  ), // I
  .mem_write   ( ctrl.mem_write ), // I
  .memsize     ( ctrl.mem_size  ), // I [2:0] size and signedness for load

  //read data
  .rdata       ( mem_rdata      )  // O [XLEN-1:0] data read from memory
  );

  // ------------------------ WB -------------------------------

  always_comb begin
    case (ctrl.result_sel)
      RESULT_ALU:  rd_data = alu_result;
      RESULT_MEM:  rd_data = mem_rdata;
      RESULT_PC4:  rd_data = pc_plus4;
      default:     rd_data = '0;
    endcase
  end

  //------------------------Assign outputs-----------------------
  assign instr_out = instr;
  assign halt = ctrl.halt;
  assign pc_out = pc;

  // ------------------------ RVFI ------------------------------
`ifdef RVFI

  // Single-cycle: exactly one instruction retires every cycle once out of reset.
  // There are no bubbles or flushes to qualify against, so rvfi_valid is simply
  // "not in reset". The pipeline will replace this with the WB stage's valid bit.
  assign rvfi_valid    = rst_n;
  assign rvfi_insn     = instr;
  assign rvfi_pc_rdata = pc;
  assign rvfi_pc_wdata = next_pc;

  // A write to x0 is dropped by the register file, so architecturally it is not a
  // write at all and must be reported as rd_addr = 0.
  logic rvfi_rd_written;
  assign rvfi_rd_written = ctrl.reg_write && (instr[11:7] != 5'd0);

  assign rvfi_rd_addr  = rvfi_rd_written ? instr[11:7] : 5'd0;
  assign rvfi_rd_wdata = rvfi_rd_written ? rd_data     : '0;

  // Convention: mem_addr is the word-aligned address, and the byte masks and data
  // are positioned within that word. So {addr, wmask, wdata} fully describes the
  // write, the way a memory bus would carry it.
  //
  // These masks are derived from mem_size and the byte offset INDEPENDENTLY of
  // data_mem's own lane logic. That is deliberate: if the two ever disagree, the
  // cosim scoreboard sees it. A shared derivation would hide exactly the byte-lane
  // bugs this is here to catch.
  assign rvfi_mem_addr = {alu_result[XLEN-1:2], 2'b00};

  always_comb begin
    rvfi_mem_rmask = 4'b0000;
    if (ctrl.mem_read) begin
      case (ctrl.mem_size)
        F3_LB, F3_LBU: rvfi_mem_rmask = 4'b0001 << alu_result[1:0];
        F3_LH, F3_LHU: rvfi_mem_rmask = 4'b0011 << alu_result[1:0];
        F3_LW:         rvfi_mem_rmask = 4'b1111;
        default:       rvfi_mem_rmask = 4'b0000;
      endcase
    end
  end

  always_comb begin
    rvfi_mem_wmask = 4'b0000;
    if (ctrl.mem_write) begin
      case (ctrl.mem_size)
        F3_SB:   rvfi_mem_wmask = 4'b0001 << alu_result[1:0];
        F3_SH:   rvfi_mem_wmask = 4'b0011 << alu_result[1:0];
        F3_SW:   rvfi_mem_wmask = 4'b1111;
        default: rvfi_mem_wmask = 4'b0000;
      endcase
    end
  end

  assign rvfi_mem_rdata = mem_rdata;
  assign rvfi_mem_wdata = rs2_data << {alu_result[1:0], 3'b000};

  assign perf_stall = 1'b0;
  assign perf_flush = 1'b0;

`endif

endmodule

