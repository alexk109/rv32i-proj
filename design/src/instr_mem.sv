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
`ifdef RISCV_FORMAL
    ,
    // fetched word, supplied by the formal harness. Has to arrive as a port,
    // not a local free variable: yosys-slang ignores both (* anyseq *) and
    // $anyseq, so a local "free" wire is just undriven, and its fanout gets
    // resolved independently by the optimizer. The real free variable lives
    // in verif/formal/wrapper.sv, read by the native yosys frontend instead.
    input  logic [31:0]     formal_instr
`endif
);

localparam int ADDR_WIDTH = $clog2(IMEM_SIZE);

`ifdef RISCV_FORMAL
  // free variable instead of a ROM, so the solver can return ANY word for a
  // fetch -- a fixed program would make the instruction checks near-vacuous.
  // Over-approximates (same PC can yield different words on different
  // cycles), fine for the per-retirement checks but why bus_imem isn't run.
  assign instr = formal_instr;

  wire _unused_formal = &{1'b0, addr};
`else
  // 1kB instruction memory (256 instructions)
  logic [31:0] mem [0:IMEM_SIZE-1]; // 32-bit words

  initial begin
    $readmemh(MEM_FILE, mem);
  end

  assign instr = mem[addr[ADDR_WIDTH+1:2]];  // word-aligned, so ignore bottom 2 bits
`endif

endmodule
