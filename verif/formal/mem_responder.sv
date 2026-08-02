// Free-variable memory for the formal harness: stands in for instr_mem and
// data_mem on the core's buses. The fetched word and the read data word are
// unconstrained (driven from the wrapper's rand_regs), which is what keeps the
// instruction and load checks non-vacuous. The load byte-extraction mirrors
// data_mem exactly, so rdata and rdata_raw carry the same relationship the real
// memory would present -- the property the load specs check against.

module mem_responder
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    // instruction bus
    input  logic [31:0]     free_iword,
    output logic [31:0]     imem_rdata,

    // data bus
    input  logic            dmem_read,
    input  logic [2:0]      dmem_size,
    input  logic [1:0]      dmem_addr_byte,
    input  logic [31:0]     free_dword,
    output logic [XLEN-1:0] dmem_rdata,
    output logic [XLEN-1:0] dmem_rdata_raw
);

  assign imem_rdata     = free_iword;
  assign dmem_rdata_raw = dmem_read ? free_dword : '0;

  always_comb begin
    if (dmem_read) begin
      case (dmem_size)
        F3_LB:   dmem_rdata = {{24{free_dword[(8*dmem_addr_byte)+7]}}, free_dword[(8*dmem_addr_byte)+:8]};
        F3_LH:   dmem_rdata = {{16{free_dword[(8*dmem_addr_byte)+15]}}, free_dword[(8*dmem_addr_byte)+:16]};
        F3_LW:   dmem_rdata = free_dword;
        F3_LBU:  dmem_rdata = {{24{1'b0}}, free_dword[(8*dmem_addr_byte)+:8]};
        F3_LHU:  dmem_rdata = {{16{1'b0}}, free_dword[(8*dmem_addr_byte)+:16]};
        default: dmem_rdata = '0;
      endcase
    end else begin
      dmem_rdata = '0;
    end
  end

endmodule
