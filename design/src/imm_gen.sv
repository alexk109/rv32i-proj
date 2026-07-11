  //immediate generator to reconstruct immediate values from instruction fields.

  module imm_gen 
    import riscv_pkg::*;
    import ctrl_pkg::*;
  (
    input  logic [31:0] instr,
    output logic [31:0] imm
  );
  
always_comb begin
  imm = '0;  // default to zero for instructions that don't use an immediate
  case (instr[6:0])

    // I-type
    OPC_OP_IMM, OPC_LOAD, OPC_JALR: begin
      imm = {{20{instr[31]}}, instr[31:20]};
    end

    // S-type
    OPC_STORE: begin
      imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    end

    // B-type
    OPC_BRANCH: begin
      imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    end

    // U-type
    OPC_LUI, OPC_AUIPC: begin
      imm = {instr[31:12], 12'b0};
    end

    // J-type
    OPC_JAL: begin
      imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    end

    default: begin
      imm = '0;
    end

  endcase
end

endmodule
