// instruction memory
// loaded from hex for simulation

module instr_mem 
    import riscv_pkg::*;
    import ctrl_pkg::*;
#(
    parameter int    IMEM_SIZE = 1024,                   //size in words
    parameter string MEM_FILE = "instr_mem.hex"
)
(
    input  logic [XLEN-1:0] addr,        // PC
    output logic [31:0]     instr
);

localparam int ADDR_WIDTH = $clog2(IMEM_SIZE);

  // 1kB instruction memory (256 instructions)
  logic [31:0] mem [0:IMEM_SIZE-1]; // 32-bit words

  initial begin
    $readmemh(MEM_FILE, mem);
  end

assign instr = mem[addr[ADDR_WIDTH+1:2]];  // word-aligned, so ignore bottom 2 bits

endmodule
