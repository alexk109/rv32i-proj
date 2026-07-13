// dedicated branch compare unit


module branch_cmp 
    import riscv_pkg::*;
    import ctrl_pkg::*;
(
    input  logic [XLEN-1:0] rs1,
    input  logic [XLEN-1:0] rs2,
    input  branch_op_e      branch_op,          // which branch condition
    input  logic            branch,             // from ctrl: 1 = conditional branch, 0 = not a branch
    output logic            branch_taken         // branch condition met
);

logic take_branch; //internal signal for branch condition result

always_comb begin
    take_branch = 1'b0;  // default to not taken
    
    case (branch_op) // which branch condition
        BR_EQ:  take_branch = (rs1 == rs2);
        BR_NE:  take_branch = (rs1 != rs2);
        BR_LT:  take_branch = ($signed(rs1) < $signed(rs2));
        BR_GE:  take_branch = ($signed(rs1) >= $signed(rs2));
        BR_LTU: take_branch = (rs1 < rs2);
        BR_GEU: take_branch = (rs1 >= rs2);
        default: take_branch = 1'b0;
    endcase
end

assign branch_taken = branch & take_branch; // only take branch if it is a conditional branch

endmodule

