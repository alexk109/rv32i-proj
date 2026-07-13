// data memory
// simple syncronous write, combinational read

module data_mem
    import riscv_pkg::*;
    import ctrl_pkg::*;
#(
    parameter int    DMEM_SIZE = 1024,                  //size in words
    parameter string DMEM_FILE = "data_mem_init.hex"   //file to load initial data for simulation
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

logic [XLEN-1:0] dmem [0:DMEM_SIZE-1]; //32 x memsize memory array

  //load initial data for sim
  initial begin
    $readmemh(DMEM_FILE, dmem);
  end


//decode address
logic [$clog2(DMEM_SIZE)-1:0] addr_word;  //word address for memory array
logic [1:0]                   addr_byte;  //byte address for memory array

assign addr_word = addr[$clog2(DMEM_SIZE) + 1 : 2]; 
assign addr_byte = addr[1:0];              


//sequential write port
always_ff @( posedge clk or negedge rst_n) begin
    
    //no reset for simulation
    //if (!rst_n) begin
    //   dmem <= '0;
    //end else 

    if (mem_write) begin
        case (memsize)
            F3_SB:   dmem[ addr_word ][ (8*addr_byte) +: 8 ] <= wdata[7:0];
            F3_SH:   dmem[ addr_word ][ (8*addr_byte) +: 16] <= wdata[15:0];
            F3_SW:   dmem[ addr_word ]                   <= wdata;
            default: ; // do nothing for illegal size
        endcase
    end
end

//combinational read port
always_comb begin
    if (mem_read) begin
        case (memsize)
            F3_LB:   rdata = {{24{dmem[ addr_word ][ (8*addr_byte) + 7 ]}}, dmem[ addr_word ][ (8*addr_byte) +: 8 ]};    // sign extend x24, lower byte
            F3_LH:   rdata = {{16{dmem[ addr_word ][ (8*addr_byte) + 15]}}, dmem[ addr_word ][ (8*addr_byte) +: 16]};    // sign extend x16, lower halfword
            F3_LW:   rdata = dmem[ addr_word ]; //full word
            F3_LBU:  rdata = {{24{1'b0}}, dmem[ addr_word ][ (8*addr_byte) +: 8 ]};  // zero extend x24, lower byte
            F3_LHU:  rdata = {{16{1'b0}}, dmem[ addr_word ][ (8*addr_byte) +: 16]}; // zero extend x16, lower halfword
            default: rdata = '0; // do nothing for illegal size
        endcase
    end else begin
        rdata = '0;
    end

end

endmodule
