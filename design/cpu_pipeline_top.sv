// Simulation/SoC top: the pipelined core wired to its instruction and data
// memories. This is the unit the C++ testbench drives; synthesis replaces the
// hex-backed memories here with on-chip RAM and, later, a cache.


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
    output logic [XLEN-1:0] rvfi_mem_wdata,

    output logic            perf_stall,
    output logic            perf_flush
`endif
);

  // instruction memory bus
  logic [XLEN-1:0] imem_addr;
  logic [31:0]     imem_rdata;

  // data memory bus
  logic [XLEN-1:0] dmem_addr;
  logic [XLEN-1:0] dmem_wdata;
  logic            dmem_read;
  logic            dmem_write;
  logic [2:0]      dmem_size;
  logic [XLEN-1:0] dmem_rdata;
  logic [XLEN-1:0] dmem_rdata_raw;

  cpu_core core_i (
    .clk            (clk           ),
    .rst_n          (rst_n         ),
    .imem_addr      (imem_addr     ),
    .imem_rdata     (imem_rdata    ),
    .dmem_addr      (dmem_addr     ),
    .dmem_wdata     (dmem_wdata    ),
    .dmem_read      (dmem_read     ),
    .dmem_write     (dmem_write    ),
    .dmem_size      (dmem_size     ),
    .dmem_rdata     (dmem_rdata    ),
    .dmem_rdata_raw (dmem_rdata_raw),
    .pc_out         (pc_out        ),
    .instr_out      (instr_out     ),
    .halt           (halt          )
`ifdef RVFI
    ,
    .rvfi_valid     (rvfi_valid    ),
    .rvfi_order     (rvfi_order    ),
    .rvfi_insn      (rvfi_insn     ),
    .rvfi_trap      (rvfi_trap     ),
    .rvfi_halt      (rvfi_halt     ),
    .rvfi_intr      (rvfi_intr     ),
    .rvfi_mode      (rvfi_mode     ),
    .rvfi_ixl       (rvfi_ixl      ),
    .rvfi_pc_rdata  (rvfi_pc_rdata ),
    .rvfi_pc_wdata  (rvfi_pc_wdata ),
    .rvfi_rs1_addr  (rvfi_rs1_addr ),
    .rvfi_rs2_addr  (rvfi_rs2_addr ),
    .rvfi_rs1_rdata (rvfi_rs1_rdata),
    .rvfi_rs2_rdata (rvfi_rs2_rdata),
    .rvfi_rd_addr   (rvfi_rd_addr  ),
    .rvfi_rd_wdata  (rvfi_rd_wdata ),
    .rvfi_mem_addr  (rvfi_mem_addr ),
    .rvfi_mem_rmask (rvfi_mem_rmask),
    .rvfi_mem_wmask (rvfi_mem_wmask),
    .rvfi_mem_rdata (rvfi_mem_rdata),
    .rvfi_mem_wdata (rvfi_mem_wdata),
    .perf_stall     (perf_stall    ),
    .perf_flush     (perf_flush    )
`endif
  );

  instr_mem instr_mem_i (
    .addr  (imem_addr ),
    .instr (imem_rdata)
  );

  data_mem #(
    .DMEM_SIZE (1024                ),
    .DMEM_FILE ("data_mem_init.hex" )
  ) data_mem_i (
    .clk       (clk           ),
    .rst_n     (rst_n         ),
    .addr      (dmem_addr     ),
    .wdata     (dmem_wdata    ),
    .mem_read  (dmem_read     ),
    .mem_write (dmem_write    ),
    .memsize   (dmem_size     ),
    .rdata     (dmem_rdata    ),
    .rdata_raw (dmem_rdata_raw)
  );

endmodule
