//============================================================================
// riscv_pkg.sv
//============================================================================
package riscv_pkg;

  //--------------------------------------------------------------------------
  // Core parameters
  //--------------------------------------------------------------------------
  localparam int XLEN       = 32;              // register / datapath width
  localparam int INSTR_W    = 32;              // instruction width (base ISA)
  localparam int REG_COUNT  = 32;              // architectural registers x0..x31
  localparam int REG_ADDR_W = 5;               // $clog2(REG_COUNT)

  typedef logic [XLEN-1:0]       word_t;       // a data/address word
  typedef logic [REG_ADDR_W-1:0] regaddr_t;    // a register index (rs1/rs2/rd)

  localparam word_t RESET_PC = 32'h0000_0000;  // PC value at reset

  //--------------------------------------------------------------------------
  // Opcodes  (instruction bits [6:0])  — the 11 RV32I base opcodes
  //--------------------------------------------------------------------------
  localparam logic [6:0] OPC_LOAD     = 7'b0000011;  // LB LH LW LBU LHU   (I)
  localparam logic [6:0] OPC_MISC_MEM = 7'b0001111;  // FENCE              (I)
  localparam logic [6:0] OPC_OP_IMM   = 7'b0010011;  // ADDI..SRAI         (I)
  localparam logic [6:0] OPC_AUIPC    = 7'b0010111;  // AUIPC              (U)
  localparam logic [6:0] OPC_STORE    = 7'b0100011;  // SB SH SW           (S)
  localparam logic [6:0] OPC_OP       = 7'b0110011;  // ADD..AND           (R)
  localparam logic [6:0] OPC_LUI      = 7'b0110111;  // LUI                (U)
  localparam logic [6:0] OPC_BRANCH   = 7'b1100011;  // BEQ..BGEU          (B)
  localparam logic [6:0] OPC_JALR     = 7'b1100111;  // JALR               (I)
  localparam logic [6:0] OPC_JAL      = 7'b1101111;  // JAL                (J)
  localparam logic [6:0] OPC_SYSTEM   = 7'b1110011;  // ECALL EBREAK       (I)

  //--------------------------------------------------------------------------
  // funct3 — OP and OP-IMM (arithmetic / logic)
  // Same funct3 encodes the R-type and I-type form of each operation.
  // funct7 (below) then disambiguates ADD/SUB and SRL/SRA.
  //--------------------------------------------------------------------------
  localparam logic [2:0] F3_ADD_SUB = 3'b000;  // ADD/SUB, ADDI
  localparam logic [2:0] F3_SLL     = 3'b001;  // SLL, SLLI
  localparam logic [2:0] F3_SLT     = 3'b010;  // SLT, SLTI
  localparam logic [2:0] F3_SLTU    = 3'b011;  // SLTU, SLTIU
  localparam logic [2:0] F3_XOR     = 3'b100;  // XOR, XORI
  localparam logic [2:0] F3_SR      = 3'b101;  // SRL/SRA, SRLI/SRAI
  localparam logic [2:0] F3_OR      = 3'b110;  // OR, ORI
  localparam logic [2:0] F3_AND     = 3'b111;  // AND, ANDI

  //--------------------------------------------------------------------------
  // funct7 — R-type and shift-immediate discriminator
  // Only bit 30 (funct7[5]) actually matters in the base ISA: it selects
  // SUB vs ADD and SRA vs SRL (and SRAI vs SRLI). Everywhere else funct7 = 0.
  //--------------------------------------------------------------------------
  localparam logic [6:0] F7_DEFAULT = 7'b0000000;  // ADD, SRL, SRLI, ...
  localparam logic [6:0] F7_ALT     = 7'b0100000;  // SUB, SRA, SRAI

  //--------------------------------------------------------------------------
  // funct3 — BRANCH
  //--------------------------------------------------------------------------
  localparam logic [2:0] F3_BEQ  = 3'b000;
  localparam logic [2:0] F3_BNE  = 3'b001;
  // 010 and 011 are reserved for future use in the base ISA
  localparam logic [2:0] F3_BLT  = 3'b100;   // signed
  localparam logic [2:0] F3_BGE  = 3'b101;   // signed
  localparam logic [2:0] F3_BLTU = 3'b110;   // unsigned
  localparam logic [2:0] F3_BGEU = 3'b111;   // unsigned

  //--------------------------------------------------------------------------
  // funct3 — LOAD  (encodes access size AND signedness)
  //--------------------------------------------------------------------------
  localparam logic [2:0] F3_LB  = 3'b000;    // byte,  sign-extended
  localparam logic [2:0] F3_LH  = 3'b001;    // half,  sign-extended
  localparam logic [2:0] F3_LW  = 3'b010;    // word
  localparam logic [2:0] F3_LBU = 3'b100;    // byte,  zero-extended
  localparam logic [2:0] F3_LHU = 3'b101;    // half,  zero-extended

  //--------------------------------------------------------------------------
  // funct3 — STORE
  //--------------------------------------------------------------------------
  localparam logic [2:0] F3_SB = 3'b000;     // byte
  localparam logic [2:0] F3_SH = 3'b001;     // half
  localparam logic [2:0] F3_SW = 3'b010;     // word

  // JALR is the sole OPC_JALR instruction; funct3 must be 000.
  localparam logic [2:0] F3_JALR = 3'b000;

  //--------------------------------------------------------------------------
  // SYSTEM — ECALL / EBREAK share OPC_SYSTEM + funct3=000; imm[11:0] selects.
  //--------------------------------------------------------------------------
  localparam logic [2:0]  F3_PRIV    = 3'b000;
  localparam logic [11:0] SYS_ECALL  = 12'h000;
  localparam logic [11:0] SYS_EBREAK = 12'h001;

  //--------------------------------------------------------------------------
  // Instruction formats — drives immediate assembly in imm_gen.
  // (R has no immediate; listed for completeness.)
  //--------------------------------------------------------------------------
  typedef enum logic [2:0] {
    FMT_R,
    FMT_I,
    FMT_S,
    FMT_B,
    FMT_U,
    FMT_J
  } instr_fmt_e;

endpackage : riscv_pkg
