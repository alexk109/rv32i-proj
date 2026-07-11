// instruction memory
// loaded from hex for simulation

module instr_mem 
    import riscv_pkg::*;
    import ctrl_pkg::*;
#(
    parameter string MEM_FILE = "instr_mem.hex"
)
(
    input  logic [XLEN-1:0] addr,        // PC
    output logic [31:0]     instr
);


  // 1kB instruction memory (256 instructions)
  logic [31:0] mem [0:255];

  initial begin
    $readmemh(MEM_FILE, mem);
  end

assign instr = mem[addr[9:2]];  // word-aligned, so ignore bottom 2 bits

endmodule
