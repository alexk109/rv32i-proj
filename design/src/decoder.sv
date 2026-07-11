// decodes opcode and funct3/funct7 bits into control signal structure for the datapath
// single level decoder for simplictly


module decoder 
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    input  logic [31:0] instr,
    output ctrl_t       ctrl
);

always_comb begin
  ctrl = '0;  

  unique case (instr[6:0])  // opcode

    OPC_LOAD: begin
      ctrl.reg_write  = 1'b1;
      ctrl.mem_read   = 1'b1;
      ctrl.mem_size   = instr[14:12];
      ctrl.alu_op     = ALU_ADD;
      ctrl.alu_src_a  = OPA_RS1;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RES_MEM;
    end

    OPC_MISC_MEM: // no control signals needed for FENCE or FENCE.I

    OPC_OP_IMM: begin
      ctrl.reg_write  = 1'b1;
      ctrl.alu_src_a  = OPA_RS1;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RES_ALU;

      unique case (instr[14:12])
        F3_ADD_SUB: ctrl.alu_op = ALU_ADD;   // no SUBI since immediate
        F3_SLT:     ctrl.alu_op = ALU_SLT;
        F3_SLTU:    ctrl.alu_op = ALU_SLTU;
        F3_XOR:     ctrl.alu_op = ALU_XOR;
        F3_OR:      ctrl.alu_op = ALU_OR;
        F3_AND:     ctrl.alu_op = ALU_AND;
        F3_SLL:     ctrl.alu_op = ALU_SLL;
        F3_SR:      ctrl.alu_op = instr[30] ? ALU_SRA : ALU_SRL;
      endcase
    
    end

    OPC_AUIPC: begin
      ctrl.reg_write  = 1'b1;
      ctrl.alu_op     = ALU_ADD;
      ctrl.alu_src_a  = OPA_PC;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RES_ALU;
    end

    OPC_STORE: begin
      ctrl.mem_write = 1'b1;
      ctrl.mem_size  = instr[14:12];
      ctrl.alu_op    = ALU_ADD;
      ctrl.alu_src_a = OPA_RS1;
      ctrl.alu_src_b = 1'b1;        // immediate
    end

    OPC_OP: begin
      ctrl.reg_write  = 1'b1;
      ctrl.alu_src_a  = OPA_RS1;
      ctrl.alu_src_b  = 1'b0;       // rs2
      ctrl.result_sel = RES_ALU;
      unique case (instr[14:12])
        F3_ADD_SUB: ctrl.alu_op = instr[30] ? ALU_SUB : ALU_ADD;
        F3_SLL:     ctrl.alu_op = ALU_SLL;
        F3_SLT:     ctrl.alu_op = ALU_SLT;
        F3_SLTU:    ctrl.alu_op = ALU_SLTU;
        F3_XOR:     ctrl.alu_op = ALU_XOR;
        F3_SR:      ctrl.alu_op = instr[30] ? ALU_SRA : ALU_SRL;
        F3_OR:      ctrl.alu_op = ALU_OR;
        F3_AND:     ctrl.alu_op = ALU_AND;
      endcase
    end

    OPC_LUI: begin
      ctrl.reg_write  = 1'b1;
      ctrl.alu_op     = ALU_ADD;
      ctrl.alu_src_a  = OPA_ZERO;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RES_ALU;
    end

    OPC_BRANCH: begin
      ctrl.branch = 1'b1;
      unique case (instr[14:12])  // explicit enum handed to branch_cmp
        F3_BEQ:  ctrl.branch_op = BR_EQ;
        F3_BNE:  ctrl.branch_op = BR_NE;
        F3_BLT:  ctrl.branch_op = BR_LT;
        F3_BGE:  ctrl.branch_op = BR_GE;
        F3_BLTU: ctrl.branch_op = BR_LTU;
        F3_BGEU: ctrl.branch_op = BR_GEU;
      endcase
      // no alu fields, since branch is handled by dedicated branch_cmp block
    end

    OPC_JALR: begin
      ctrl.reg_write  = 1'b1;
      ctrl.result_sel = RES_PC4;    // link value; target comes from dedicated adder
      ctrl.jump       = 1'b1;
      ctrl.jalr       = 1'b1;       // tells dedicated adder: base = rs1, not PC
    end

    OPC_JAL: begin
      ctrl.reg_write  = 1'b1;
      ctrl.result_sel = RES_PC4;
      ctrl.jump       = 1'b1;
    end

    OPC_SYSTEM: ctrl.halt = 1'b1;   // ECALL & EBREAK, Phase 1: halt only

    default: ctrl = '0;  //default

  endcase
end

endmodule

