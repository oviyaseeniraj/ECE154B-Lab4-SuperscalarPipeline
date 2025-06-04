// ucsbece154_imem.v
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited

`define MIN(A,B) (((A)<(B))?(A):(B))

module ucsbece154_imem #(
    parameter TEXT_SIZE = 64
) (
    input        [31:0] a_i,
    output wire  [31:0] rd_o,
    input        [31:0] a_i2,
    output wire  [31:0] rd_o2
);

// instantiate/initialize BRAM
reg [31:0] TEXT [0:TEXT_SIZE-1];

// initialize memory with test program. Change this with your file for running custom code
initial $readmemh("text.dat", TEXT);

// calculate address bounds for memory
localparam TEXT_START = 32'h00010000;
localparam TEXT_END   = `MIN( TEXT_START + (TEXT_SIZE*4), 32'h10000000);

// calculate address width
localparam TEXT_ADDRESS_WIDTH = $clog2(TEXT_SIZE);

// create flags to specify whether in-range 
wire text_enable = (TEXT_START <= a_i) && (a_i < TEXT_END);
wire text_enable2 = (TEXT_START <= a_i2) && (a_i2 < TEXT_END);

// create addresses 
wire [TEXT_ADDRESS_WIDTH-1:0] text_address = a_i[2 +: TEXT_ADDRESS_WIDTH]-(TEXT_START[2 +: TEXT_ADDRESS_WIDTH]);
wire [TEXT_ADDRESS_WIDTH-1:0] text_address2 = a_i2[2 +: TEXT_ADDRESS_WIDTH]-(TEXT_START[2 +: TEXT_ADDRESS_WIDTH]);

// get read-data 
wire [31:0] text_data = TEXT[ text_address ];
wire [31:0] text_data2 = TEXT[ text_address2 ];

// set rd_o iff a_i is in range 
assign rd_o =
    text_enable ? text_data : 
    {32{1'bz}}; // not driven by this memory

assign rd_o2 =
    text_enable2 ? text_data2 :
    {32{1'bz}}; // not driven by this memory

`ifdef SIM
always @ * begin
    if (a_i[1:0]!=2'b0)
        $warning("Attempted to access invalid address 0x%h. Address coerced to 0x%h.", a_i, (a_i&(~32'b11)));
    if (a_i2[1:0]!=2'b0)
        $warning("Attempted to access invalid address 0x%h. Address coerced to 0x%h.", a_i2, (a_i2&(~32'b11)));
end
`endif

endmodule

`undef MIN
