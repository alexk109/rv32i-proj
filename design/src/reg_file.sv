// 32 x 32 reg file with 2 read ports and 1 write port

module reg_file
  import riscv_pkg::*;
  import ctrl_pkg::*;
  #(
    parameter P_ENABLE_BYPASS = 1 // bypass logic to prevent read-after-write hazards, disable for single cycle
  )
(

    // clock and reset
    input  logic            clk,
    input  logic            rst_n,

    // register file interface
    input  logic [4:0]      rs1_addr, 
    input  logic [4:0]      rs2_addr, 
    input  logic [4:0]      wr_addr,
    input  logic [XLEN-1:0] wr_data,
    input  logic            reg_write,

    // output to ALU / MEM
    output logic [XLEN-1:0] rs1_data, 
    output logic [XLEN-1:0] rs2_data

);


  logic [XLEN-1:0] regs [0:REG_COUNT-1]  /* verilator public_flat_rd */; // 32 x 32 register file


  // combinational read ports -- with bypass to prevent read-after-write hazard
  assign rs1_data = (P_ENABLE_BYPASS && ((rs1_addr == wr_addr) && reg_write && wr_addr != 5'd0)) ? wr_data : regs[rs1_addr];
  assign rs2_data = (P_ENABLE_BYPASS && ((rs2_addr == wr_addr) && reg_write && wr_addr != 5'd0)) ? wr_data : regs[rs2_addr];

  //sequential write port
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      regs <= '{default: '0};
    end 
    else if (reg_write && wr_addr == 5'd0) begin
      // writes to x0 are ignored
      regs[wr_addr] <= '0;
    end
    else if (reg_write && wr_addr != 5'd0) begin
      regs[wr_addr] <= wr_data;
    end
  end

endmodule
