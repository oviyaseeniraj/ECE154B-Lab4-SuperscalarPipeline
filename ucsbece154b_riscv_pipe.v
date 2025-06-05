// ucsbece154b_riscv_pipe.v
// ECE 154B, RISC-V pipelined processor 
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited

module ucsbece154b_riscv_pipe (
    input               clk, reset,
    output wire  [31:0] PCF_o,
    input        [31:0] InstrF_i,
    output wire         MemWriteM_o,
    output wire  [31:0] ALUResultM_o,
    output wire  [31:0] WriteDataM_o,
    input        [31:0] ReadDataM_i,

    // Slot 2 interface
    output wire  [31:0] PCF2_o,
    input        [31:0] InstrF2_i,
    input        [31:0] ReadDataM2_i,
    output wire         MemWriteM2_o,
    output wire  [31:0] ALUResultM2_o,
    output wire  [31:0] WriteDataM2_o
);

wire [4:0] RdD1, RdD2;
wire RAW, WAR, WAW;

wire  PCSrcE, StallF, StallD, FlushD, RegWriteW, FlushE, ALUSrcE, ZeroE;
wire [6:0] op;
wire [2:0] funct3;
wire funct7b5;
wire [2:0] ImmSrcD;
wire [2:0] ALUControlE;
wire [1:0] ForwardAE, ForwardBE, ResultSrcW, ResultSrcM;
wire [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;
wire mispredict;

wire  PCSrcE2, StallF2, StallD2, FlushD2, RegWriteW2, FlushE2, ALUSrcE2, ZeroE2;
wire [6:0] op2;
wire [2:0] funct3_2;
wire funct7b5_2;
wire [2:0] ImmSrcD2;
wire [2:0] ALUControlE2;
wire [1:0] ForwardAE2, ForwardBE2, ResultSrcW2, ResultSrcM2;
wire [4:0] Rs1D2, Rs2D2, Rs1E2, Rs2E2, RdE2, RdM2, RdW2;

ucsbece154b_controller c (
    .clk(clk), .reset(reset),
    .op_i(op), 
    .funct3_i(funct3),
    .funct7b5_i(funct7b5),
    .ZeroE_i(ZeroE),
    .Rs1D_i(Rs1D),
    .Rs2D_i(Rs2D),
    .Rs1E_i(Rs1E),
    .Rs2E_i(Rs2E),
    .RdE_i(RdE),
    .RdM_i(RdM),
    .RdW_i(RdW),

    // slot 2 hazard detection and control
    .op2_i(op2),
    .funct3_2_i(funct3_2),
    .funct7b5_2_i(funct7b5_2),
    .ZeroE2_i(ZeroE2),
    .Rs1D2_i(Rs1D2),
    .Rs2D2_i(Rs2D2),
    .Rs1E2_i(Rs1E2),
    .Rs2E2_i(Rs2E2),
    .RdE2_i(RdE2),
    .RdM2_i(RdM2),
    .RdW2_i(RdW2),

    .StallF_o(StallF),  
    .StallD_o(StallD),
    .FlushD_o(FlushD),
    .FlushD2_o(FlushD2),
    .ImmSrcD_o(ImmSrcD),
    .PCSrcE_o(PCSrcE),
    .ALUControlE_o(ALUControlE),
    .ALUSrcE_o(ALUSrcE),
    .FlushE_o(FlushE),
    .ForwardAE_o(ForwardAE),
    .ForwardBE_o(ForwardBE),
    .MemWriteM_o(MemWriteM_o),
    .RegWriteW_o(RegWriteW),
    .ResultSrcW_o(ResultSrcW),
    .ResultSrcM_o(ResultSrcM),
    .Mispredict_i(mispredict),
    .RdD1_i(RdD1),
    .RdD2_i(RdD2),

    .PCSrcE2_o(PCSrcE2),
    .StallF2_o(StallF2),
    .StallD2_o(StallD2),
    .FlushE2_o(FlushE2),
    .ImmSrcD2_o(ImmSrcD2),
    .ALUControlE2_o(ALUControlE2),
    .ALUSrcE2_o(ALUSrcE2),
    .ForwardAE2_o(ForwardAE2),
    .ForwardBE2_o(ForwardBE2),
    .MemWriteM2_o(MemWriteM2_o),
    .RegWriteW2_o(RegWriteW2),
    .ResultSrcW2_o(ResultSrcW2),
    .ResultSrcM2_o(ResultSrcM2),

    .RAW(RAW),
    .WAR(WAR),
    .WAW(WAW)
);

ucsbece154b_datapath dp (
    .clk(clk), .reset(reset),
    .PCSrcE_i(PCSrcE),
    .StallF_i(StallF),
    .PCF_o(PCF_o),
    .StallD_i(StallD),
    .FlushD_i(FlushD),
    .InstrF_i(InstrF_i),
    .op_o(op),
    .funct3_o(funct3),
    .funct7b5_o(funct7b5),
    .RegWriteW_i(RegWriteW),
    .ImmSrcD_i(ImmSrcD),
    .Rs1D_o(Rs1D),
    .Rs2D_o(Rs2D),
    .FlushE_i(FlushE),
    .Rs1E_o(Rs1E),
    .Rs2E_o(Rs2E), 
    .RdE_o(RdE), 
    .ALUSrcE_i(ALUSrcE),
    .ALUControlE_i(ALUControlE),
    .ForwardAE_i(ForwardAE),
    .ForwardBE_i(ForwardBE),
    .ZeroE_o(ZeroE),
    .RdM_o(RdM), 
    .ALUResultM_o(ALUResultM_o),
    .WriteDataM_o(WriteDataM_o),
    .ReadDataM_i(ReadDataM_i),
    .ResultSrcW_i(ResultSrcW),
    .RdW_o(RdW),
    .ResultSrcM_i(ResultSrcM),
    .Mispredict_o(mispredict),

    .PCSrcE2_i(PCSrcE2),
    .StallF2_i(StallF2),
    .PCF2_o(PCF2_o),
    .StallD2_i(StallD2),
    .FlushD2_i(FlushD2),
    .InstrF2_i(InstrF2_i),
    .op2_o(op2),
    .funct3_2_o(funct3_2),
    .funct7b5_2_o(funct7b5_2),
    .RegWriteW2_i(RegWriteW2),
    .ImmSrcD2_i(ImmSrcD2),
    .Rs1D2_o(Rs1D2),
    .Rs2D2_o(Rs2D2),
    .FlushE2_i(FlushE2),
    .Rs1E2_o(Rs1E2),
    .Rs2E2_o(Rs2E2), 
    .RdE2_o(RdE2), 
    .ALUSrcE2_i(ALUSrcE2),
    .ALUControlE2_i(ALUControlE2),
    .ForwardAE2_i(ForwardAE2),
    .ForwardBE2_i(ForwardBE2),
    .ZeroE2_o(ZeroE2),
    .RdM2_o(RdM2), 
    .ALUResultM2_o(ALUResultM2_o),
    .WriteDataM2_o(WriteDataM2_o),
    .ReadDataM2_i(ReadDataM2_i),
    .ResultSrcW2_i(ResultSrcW2),
    .RdW2_o(RdW2),
    .ResultSrcM2_i(ResultSrcM2),
    .RdD1_o(RdD1),
    .RdD2_o(RdD2),
    .RAW(RAW),
    .WAR(WAR),
    .WAW(WAW)
);

endmodule