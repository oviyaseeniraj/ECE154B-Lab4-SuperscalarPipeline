// ucsbece154b_top.v
// ECE 154B, RISC-V pipelined processor 
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited


module ucsbece154b_top (
    input clk, reset
);

wire [31:0] pc, instr, readdata;
wire [31:0] pc2, instr2, readdata2;
wire        memwrite2;
wire [31:0] writedata2, dataadr2;
wire [31:0] writedata, dataadr;
wire        memwrite;

// processor and memories are instantiated here
ucsbece154b_riscv_pipe riscv (
    .clk(clk), .reset(reset),

    // Slot 1
    .PCF_o(pc),
    .InstrF_i(instr),
    .MemWriteM_o(memwrite),
    .ALUResultM_o(dataadr), 
    .WriteDataM_o(writedata),
    .ReadDataM_i(readdata),

    // Slot 2
    .PCF2_o(pc2),
    .InstrF2_i(instr2),
    .MemWriteM2_o(memwrite2),
    .ALUResultM2_o(dataadr2), 
    .WriteDataM2_o(writedata2),
    .ReadDataM2_i(readdata2)
);

ucsbece154_imem imem (
    .a_i(pc), .rd_o(instr)
);
ucsbece154_dmem dmem (
    .clk(clk), .we_i(memwrite),
    .a_i(dataadr), .wd_i(writedata),
    .rd_o(readdata)
);

endmodule
