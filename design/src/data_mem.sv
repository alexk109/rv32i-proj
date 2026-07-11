// data memory
// simple syncronous write, combinational read

module data_mem
    import riscv_pkg::*;
    import ctrl_pkg::*;
#(
    parameter MEM_SIZE = 1024
) (

    //clk and reset
    input  logic            clk,
    input  logic            rst_n,

    //address and write data
    input  logic [XLEN-1:0] addr,
    input  logic [XLEN-1:0] wdata,

    //control signal
    input  logic            mem_read,
    input  logic            mem_write,
    input  logic [2:0]      memsize,       // size + signedness for load
    
    //read data
    output logic [XLEN-1:0] rdata

  );


logic [XLEN-1:0] dmem [0:MEM_SIZE-1]; //32 x memsize memory array

//sequential write port
always_ff @( posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dmem <= '0;
    end
    else if (mem_write) begin
        case (memsize)
            F3_LB:  dmem[addr] <= wdata[7:0];
            F3_LH:  dmem[addr] <= wdata[15:0];
            F3_LW:  dmem[addr] <= wdata;
            default: dmem[addr] <= wdata; // default to word write
        endcase
    end
end

assign rdata = mem_read ? dmem[addr] : '0; //combinational read, return 0 if not reading


endmodule
