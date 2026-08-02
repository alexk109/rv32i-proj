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
    output logic [XLEN-1:0] rdata,

    // untouched word at the aligned address, pre-extension -- RVFI reports this,
    // since the load specs do their own byte extraction from it
    output logic [XLEN-1:0] rdata_raw

  );

//decode address
logic [$clog2(DMEM_SIZE)-1:0] addr_word;  //word address for memory array
logic [1:0]                   addr_byte;  //byte address for memory array

assign addr_word = addr[$clog2(DMEM_SIZE) + 1 : 2];
assign addr_byte = addr[1:0];

// addressed word before byte selection -- one signal feeds both rdata and
// rdata_raw, so they can't disagree about what was read
logic [XLEN-1:0] read_word;

logic [XLEN-1:0] dmem [0:DMEM_SIZE-1]; //32 x memsize memory array

  //load initial data for sim
  initial begin
    $readmemh(DMEM_FILE, dmem);
  end

//sequential write port
// Sensitivity is posedge clk only. This used to also list `negedge rst_n` while
// the reset body sat commented out, which meant a falling reset edge could
// itself commit a write whenever mem_write happened to be high.
always_ff @( posedge clk ) begin
    if (mem_write) begin
        case (memsize)
            F3_SB:   dmem[ addr_word ][ (8*addr_byte) +: 8 ] <= wdata[7:0];
            F3_SH:   dmem[ addr_word ][ (8*addr_byte) +: 16] <= wdata[15:0];
            F3_SW:   dmem[ addr_word ]                   <= wdata;
            default: ; // do nothing for illegal size
        endcase
    end
end

assign read_word = dmem[ addr_word ];

wire _unused_dmem_rst = &{1'b0, rst_n};

//combinational read port
always_comb begin
    if (mem_read) begin
        case (memsize)
            F3_LB:   rdata = {{24{read_word[ (8*addr_byte) + 7 ]}}, read_word[ (8*addr_byte) +: 8 ]};    // sign extend x24, lower byte
            F3_LH:   rdata = {{16{read_word[ (8*addr_byte) + 15]}}, read_word[ (8*addr_byte) +: 16]};    // sign extend x16, lower halfword
            F3_LW:   rdata = read_word; //full word
            F3_LBU:  rdata = {{24{1'b0}}, read_word[ (8*addr_byte) +: 8 ]};  // zero extend x24, lower byte
            F3_LHU:  rdata = {{16{1'b0}}, read_word[ (8*addr_byte) +: 16]}; // zero extend x16, lower halfword
            default: rdata = '0; // do nothing for illegal size
        endcase
    end else begin
        rdata = '0;
    end

end

assign rdata_raw = mem_read ? read_word : '0;

endmodule
