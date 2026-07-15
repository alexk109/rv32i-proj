//============================================================================
// ctrl_pkg.sv
//
// The control vocabulary of the core. The decoder is the only producer of a
// ctrl_t; every datapath unit downstream of it is a consumer. Defining the
// bundle once here is what lets the Phase 2 pipeline carry it through the
// stage registers unchanged.
//============================================================================
package ctrl_pkg;

  typedef enum logic [3:0] {
    ALU_ADD, 
    ALU_SUB, 
    ALU_SLL, 
    ALU_SLT, 
    ALU_SLTU,
    ALU_XOR, 
    ALU_SRL, 
    ALU_SRA, 
    ALU_OR,  
    ALU_AND
  } alu_op_e;

  typedef enum logic [1:0] {
    RESULT_ALU,   // R-type, OP-IMM, LUI, AUIPC
    RESULT_MEM,   // loads
    RESULT_PC4    // JAL, JALR (link value)
  } result_sel_e;

  typedef enum logic [1:0] {
    OPA_RS1,      // normal case
    OPA_PC,       // AUIPC
    OPA_ZERO      // LUI
  } alu_src_a_e;

  typedef enum logic [2:0] {
    BR_EQ,
    BR_NE,
    BR_LT,
    BR_GE,
    BR_LTU,
    BR_GEU
  } branch_op_e;

  typedef struct packed {
    logic        reg_write;   // does this instr write rd?
    logic        mem_read;    // load
    logic        mem_write;   // store
    logic [2:0]  mem_size;    // funct3, reused: byte/half/word + sign for loads
    alu_op_e     alu_op;      // which ALU operation
    alu_src_a_e  alu_src_a;   // rs1 / PC / zero
    logic        alu_src_b;   // 0 = rs2, 1 = immediate
    logic        uses_rs1;    // reads rs1 as a source — for hazard/forward gating
    logic        uses_rs2;    // reads rs2 as a source — for hazard/forward gating
    result_sel_e result_sel;  // ALU / mem / PC+4
    logic        branch;      // conditional branch (BEQ...BGEU)
    branch_op_e  branch_op;   // condition for branch_cmp; meaningful only when branch=1
    logic        jump;        // JAL or JALR
    logic        jalr;        // 1 = JALR (target = rs1+imm), 0 = JAL (target = PC+imm)
    logic        halt;        // ECALL/EBREAK — tells top to stop sim
    logic        illegal;     // illegal instruction
  } ctrl_t;

endpackage : ctrl_pkg
