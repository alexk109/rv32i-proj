//ALU module
// combinational

module alu
  import riscv_pkg::*;
  import ctrl_pkg::*;
 (
    input  logic [XLEN-1:0]        a,
    input  logic [XLEN-1:0]        b,
    input  alu_op_e                op,
    output logic [XLEN-1:0]        result
);

  always_comb begin
    case (op)
      ALU_ADD:  result = a + b;
      ALU_SUB:  result = a - b;
      ALU_SLL:  result = a << b[4:0];
      ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
      ALU_XOR:  result = a ^ b;
      ALU_SRL:  result = a >> b[4:0];
      ALU_SRA:  result = $signed(a) >>> b[4:0];
      ALU_OR:   result = a | b;
      ALU_AND:  result = a & b;
      default:  result = '0;
    endcase
  end

endmodule
