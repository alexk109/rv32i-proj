// Top module for RISC V CPU
// single cycle implementation

module cpu_single_cycle_top
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,
    output logic [XLEN-1:0] pc_out,
    output logic [XLEN-1:0] instr_out
);

  // internal signal declaration
  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] next_pc;
  logic [XLEN-1:0] instr;
  logic [XLEN-1:0] rs1_data;
  logic [XLEN-1:0] rs2_data;
  logic [XLEN-1:0] rd_data;
  logic [XLEN-1:0] alu_result;
  logic [XLEN-1:0] mem_rdata;
  ctrl_s           ctrl;

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
  assign pc_out = pc;

  ////////////////////////////
  // instruction memory
  ////////////////////////////
  instr_mem instr_mem_i(
        .addr      (pc         ),   // I [XLEN-1:0] address
        .instr     (instr      )    // O [XLEN-1:0] instruction
 );

  // ------------------------ ID -------------------------------


  ////////////////////////////
  // Register file
  ////////////////////////////

  reg_file reg_file_i(
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(instr[19:15]),
    .rs2_addr(instr[24:20]),
    .rd_addr(instr[11:7]),
    .rd_data(rd_data),
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

  /////////////////////////////
  // rs1 and rs2 muxes
  /////////////////////////////
  logic [XLEN-1:0] alu_input_a;
  logic [XLEN-1:0] alu_input_b;
  logic [XLEN-1:0] rs1_mux_out;
  logic [XLEN-1:0] rs2_mux_out;

  assign rs1_mux_out = (//some condition) ? rs1_data : '0;
  assign rs2_mux_out = (//some condition) ? rs2_data : '0;

  // ------------------------ EX -------------------------------

  
  
  ////////////////////////////
  // ALU
  ////////////////////////////
  alu alu_i(
    .a(alu_input_a),
    .b(alu_input_b),
    .op(ctrl.alu_op),
    .result(alu_result)
  );


endmodule

