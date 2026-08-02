// Binds the RVFI monitor into every cpu_core instance, driving the core's
// rvfi_* output ports from its writeback-stage internals. Included in a build
// only when RVFI is defined (the ports it connects to exist only then), so the
// synthesis elaboration of cpu_core never sees it.

bind cpu_core rvfi_monitor rvfi_monitor_i (
    .clk            (clk           ),
    .rst_n          (rst_n         ),
    .mem_wb_q       (mem_wb_q      ),
    .wb_reg_write   (wb_reg_write  ),
    .wb_rd_data     (wb_rd_data    ),
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
    .rvfi_mem_wdata (rvfi_mem_wdata)
);
