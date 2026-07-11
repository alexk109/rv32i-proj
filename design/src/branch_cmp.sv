// dedicated branch compare unit


module branch_cmp 
    import riscv_pkg::*;
    import ctrl_pkg::*;
(
    input  logic [XLEN-1:0] rs1,
    input  logic [XLEN-1:0] rs2,
    input  branch_op_e      branch_op,          // which branch condition
    output logic            take_branch         // branch condition met
);


always_comb begin
    take_branch = 1'b0;  // default to not taken
    
    unique case (branch_op) // which branch condition
        BR_EQ:  take_branch = (rs1 == rs2);
        BR_NE:  take_branch = (rs1 != rs2);
        BR_LT:  take_branch = ($signed(rs1) < $signed(rs2));
        BR_GE:  take_branch = ($signed(rs1) >= $signed(rs2));
        BR_LTU: take_branch = (rs1 < rs2);
        BR_GEU: take_branch = (rs1 >= rs2);
        default: take_branch = 1'b0;
    endcase
end


endmodule

