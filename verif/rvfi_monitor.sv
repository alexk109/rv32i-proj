// RVFI retirement monitor: reconstructs the riscv-formal retirement snapshot
// from the core's writeback-stage state. Bound into cpu_core (see rvfi_bind.sv)
// so the core RTL itself carries none of this verification logic, while both
// the formal harness and the simulation testbench observe the same interface.

module rvfi_monitor
  import riscv_pkg::*;
  import ctrl_pkg::*;
  import pipe_pkg::*;
(
    input  logic            clk,
    input  logic            rst_n,

    // writeback-stage taps from the core
    input  mem_wb_t         mem_wb_q,
    input  logic            wb_reg_write,
    input  logic [XLEN-1:0] wb_rd_data,

    output logic            rvfi_valid,
    output logic [63:0]     rvfi_order,
    output logic [31:0]     rvfi_insn,
    output logic            rvfi_trap,
    output logic            rvfi_halt,
    output logic            rvfi_intr,
    output logic [1:0]      rvfi_mode,
    output logic [1:0]      rvfi_ixl,
    output logic [XLEN-1:0] rvfi_pc_rdata,
    output logic [XLEN-1:0] rvfi_pc_wdata,
    output logic [4:0]      rvfi_rs1_addr,
    output logic [4:0]      rvfi_rs2_addr,
    output logic [XLEN-1:0] rvfi_rs1_rdata,
    output logic [XLEN-1:0] rvfi_rs2_rdata,
    output logic [4:0]      rvfi_rd_addr,
    output logic [XLEN-1:0] rvfi_rd_wdata,
    output logic [XLEN-1:0] rvfi_mem_addr,
    output logic [3:0]      rvfi_mem_rmask,
    output logic [3:0]      rvfi_mem_wmask,
    output logic [XLEN-1:0] rvfi_mem_rdata,
    output logic [XLEN-1:0] rvfi_mem_wdata
);

  logic rvfi_rd_written;
  assign rvfi_rd_written = wb_reg_write && (mem_wb_q.rd_addr != 5'd0);

  // instructions that read no source register (LUI, AUIPC, JAL) must report x0,
  // not whatever stale rs*_addr happened to be decoded
  logic rvfi_reads_rs1, rvfi_reads_rs2;
  assign rvfi_reads_rs1 = mem_wb_q.ctrl.uses_rs1;
  assign rvfi_reads_rs2 = mem_wb_q.ctrl.uses_rs2;

  // retirement counter, must stay gap-free -- the multi-retirement checks
  // (reg, pc_fwd, causal) use it to order two RVFI snapshots
  logic [63:0] rvfi_order_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          rvfi_order_q <= 64'd0;
    else if (rvfi_valid) rvfi_order_q <= rvfi_order_q + 64'd1;
  end

  assign rvfi_valid     = mem_wb_q.valid;
  assign rvfi_order     = rvfi_order_q;
  assign rvfi_insn      = mem_wb_q.instr;
  assign rvfi_pc_rdata  = mem_wb_q.pc;
  assign rvfi_pc_wdata  = mem_wb_q.next_pc;
  assign rvfi_rs1_addr  = rvfi_reads_rs1 ? mem_wb_q.rs1_addr  : 5'd0;
  assign rvfi_rs2_addr  = rvfi_reads_rs2 ? mem_wb_q.rs2_addr  : 5'd0;
  assign rvfi_rs1_rdata = rvfi_reads_rs1 ? mem_wb_q.rs1_rdata : '0;
  assign rvfi_rs2_rdata = rvfi_reads_rs2 ? mem_wb_q.rs2_rdata : '0;
  assign rvfi_rd_addr   = rvfi_rd_written ? mem_wb_q.rd_addr : 5'd0;
  assign rvfi_rd_wdata  = rvfi_rd_written ? wb_rd_data       : '0;

  // no CSRs or privilege levels, so mode/ixl are fixed rather than real state
  assign rvfi_trap      = mem_wb_q.valid && mem_wb_q.trap;
  assign rvfi_halt      = 1'b0;
  assign rvfi_intr      = 1'b0;
  assign rvfi_mode      = 2'd3;  // M-mode
  assign rvfi_ixl       = 2'd1;  // XLEN=32
  assign rvfi_mem_addr  = mem_wb_q.mem_addr;
  assign rvfi_mem_rmask = mem_wb_q.mem_rmask;
  assign rvfi_mem_wmask = mem_wb_q.mem_wmask;
  assign rvfi_mem_rdata = mem_wb_q.mem_rdata_raw;
  assign rvfi_mem_wdata = mem_wb_q.mem_wdata;

endmodule
