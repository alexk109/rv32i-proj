// decodes opcode and funct3/funct7 bits into control signal structure for the datapath
// single level decoder for simplictly
//
// Every instruction is illegal until a valid encoding proves otherwise. Each arm
// clears ctrl.illegal only inside the guard that established its funct3 is valid,
// alongside the commit signals that guard protects. An encoding matching no arm
// falls out with illegal=1 and every commit signal at 0, so nothing it does can
// reach architectural state.


module decoder
  import riscv_pkg::*;
  import ctrl_pkg::*;
(
    input  logic [31:0] instr,
    output ctrl_t       ctrl
);

always_comb begin
  ctrl = '0;
  ctrl.illegal = 1'b1;

  case (instr[6:0])  // opcode

    OPC_LOAD: begin
      case (instr[14:12])
        F3_LB, F3_LH, F3_LW, F3_LBU, F3_LHU: begin
          ctrl.illegal    = 1'b0;
          ctrl.reg_write  = 1'b1;
          ctrl.mem_read   = 1'b1;
          ctrl.mem_size   = instr[14:12];
          ctrl.alu_op     = ALU_ADD;
          ctrl.alu_src_a  = OPA_RS1;
          ctrl.alu_src_b  = 1'b1;       // immediate
          ctrl.result_sel = RESULT_MEM;
        end
        default: ;
      endcase
    end

    OPC_MISC_MEM: ctrl.illegal = 1'b0;  // FENCE: legal, but a NOP on this core

    OPC_OP_IMM: begin
      ctrl.illegal    = 1'b0;       // all 8 funct3 values are valid
      ctrl.reg_write  = 1'b1;
      ctrl.alu_src_a  = OPA_RS1;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RESULT_ALU;

      case (instr[14:12])
        F3_ADD_SUB: ctrl.alu_op = ALU_ADD;   // no SUBI since immediate
        F3_SLT:     ctrl.alu_op = ALU_SLT;
        F3_SLTU:    ctrl.alu_op = ALU_SLTU;
        F3_XOR:     ctrl.alu_op = ALU_XOR;
        F3_OR:      ctrl.alu_op = ALU_OR;
        F3_AND:     ctrl.alu_op = ALU_AND;
        F3_SLL:     ctrl.alu_op = ALU_SLL;
        F3_SR:      ctrl.alu_op = instr[30] ? ALU_SRA : ALU_SRL;
        default:    ctrl.alu_op = ALU_ADD;   // unreachable: all 8 covered above
      endcase
    end

    OPC_AUIPC: begin
      ctrl.illegal    = 1'b0;
      ctrl.reg_write  = 1'b1;
      ctrl.alu_op     = ALU_ADD;
      ctrl.alu_src_a  = OPA_PC;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RESULT_ALU;
    end

    OPC_STORE: begin
      case (instr[14:12])
        F3_SB, F3_SH, F3_SW: begin
          ctrl.illegal   = 1'b0;
          ctrl.mem_write = 1'b1;
          ctrl.mem_size  = instr[14:12];
          ctrl.alu_op    = ALU_ADD;
          ctrl.alu_src_a = OPA_RS1;
          ctrl.alu_src_b = 1'b1;      // immediate
        end
        default: ;
      endcase
    end

    OPC_OP: begin
      ctrl.illegal    = 1'b0;       // all 8 funct3 values are valid
      ctrl.reg_write  = 1'b1;
      ctrl.alu_src_a  = OPA_RS1;
      ctrl.alu_src_b  = 1'b0;       // rs2
      ctrl.result_sel = RESULT_ALU;

      case (instr[14:12])
        F3_ADD_SUB: ctrl.alu_op = instr[30] ? ALU_SUB : ALU_ADD;
        F3_SLL:     ctrl.alu_op = ALU_SLL;
        F3_SLT:     ctrl.alu_op = ALU_SLT;
        F3_SLTU:    ctrl.alu_op = ALU_SLTU;
        F3_XOR:     ctrl.alu_op = ALU_XOR;
        F3_SR:      ctrl.alu_op = instr[30] ? ALU_SRA : ALU_SRL;
        F3_OR:      ctrl.alu_op = ALU_OR;
        F3_AND:     ctrl.alu_op = ALU_AND;
        default:    ctrl.alu_op = ALU_ADD;   // unreachable: all 8 covered above
      endcase
    end

    OPC_LUI: begin
      ctrl.illegal    = 1'b0;
      ctrl.reg_write  = 1'b1;
      ctrl.alu_op     = ALU_ADD;
      ctrl.alu_src_a  = OPA_ZERO;
      ctrl.alu_src_b  = 1'b1;       // immediate
      ctrl.result_sel = RESULT_ALU;
    end

    OPC_BRANCH: begin
      // branch_op is a value signal, so an invalid funct3 may leave garbage in it.
      // ctrl.branch below is what decides whether anything ever acts on it.
      case (instr[14:12])
        F3_BEQ:  ctrl.branch_op = BR_EQ;
        F3_BNE:  ctrl.branch_op = BR_NE;
        F3_BLT:  ctrl.branch_op = BR_LT;
        F3_BGE:  ctrl.branch_op = BR_GE;
        F3_BLTU: ctrl.branch_op = BR_LTU;
        F3_BGEU: ctrl.branch_op = BR_GEU;
        default: ctrl.branch_op = BR_EQ;
      endcase

      case (instr[14:12])
        F3_BEQ, F3_BNE, F3_BLT, F3_BGE, F3_BLTU, F3_BGEU: begin
          ctrl.illegal = 1'b0;
          ctrl.branch  = 1'b1;
        end
        default: ;
      endcase
      // no alu fields, since branch is handled branch_cmp module
    end

    OPC_JALR: begin
      case (instr[14:12])
        F3_JALR: begin
          ctrl.illegal    = 1'b0;
          ctrl.reg_write  = 1'b1;
          ctrl.result_sel = RESULT_PC4;  // link value; target comes from dedicated adder
          ctrl.jump       = 1'b1;
          ctrl.jalr       = 1'b1;        // tells dedicated adder: base = rs1, not PC
        end
        default: ;
      endcase
    end

    OPC_JAL: begin
      ctrl.illegal    = 1'b0;
      ctrl.reg_write  = 1'b1;
      ctrl.result_sel = RESULT_PC4;
      ctrl.jump       = 1'b1;
    end

    OPC_SYSTEM: begin
      case (instr[14:12])
        F3_PRIV: begin
          ctrl.illegal = 1'b0;
          ctrl.halt    = 1'b1;   // ECALL & EBREAK, Phase 1: halt only
        end
        default: ;               // CSR ops: no Zicsr on this core
      endcase
    end

    default: ;  // unknown opcode

  endcase
end

endmodule
