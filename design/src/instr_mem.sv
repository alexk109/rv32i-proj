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
    // The fetched word, supplied by the formal harness. It has to arrive as a
    // PORT rather than being conjured locally: yosys-slang silently ignores both
    // `(* anyseq *)` and `$anyseq`, so a locally declared "free" variable is just
    // an undriven wire whose fanout the optimizer resolves independently. The
    // real free variable is declared in verif/formal/wrapper.sv, which the native
    // yosys frontend reads and where those constructs do work.
    input  logic [31:0]     formal_instr
`endif
);

localparam int ADDR_WIDTH = $clog2(IMEM_SIZE);

`ifdef RISCV_FORMAL
  // Formal builds replace the ROM with a free variable so the solver may return
  // ANY word for a fetch. A $readmemh image would pin the proof to one program
  // and make the instruction checks near-vacuous; unconstraining the fetch is
  // what lets riscv-formal reason about every RV32I encoding at once.
  //
  // This is an over-approximation: the same PC may yield different words on
  // different cycles. That is sound for the insn/reg/pc checks -- they are
  // per-retirement properties that never require fetch coherence -- but it is
  // exactly why the bus_imem checks cannot be run against this core.
  assign instr = formal_instr;

  // Silence unused-signal warnings in this build.
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
