// WAW - write to same register on same clock edge hazard. mitigate by inserting nop for second instr
// RAW - read after write hazard. mitigate by forwarding
// WAR - write after read hazard
module ucsbece154b_datapath (
    input                clk, reset,

    //slot1 signals
    input                PCSrcE_i,
    input                StallF_i,
    output reg    [31:0] PCF_o,
    input                StallD_i,
    input                FlushD_i,
    input         [31:0] InstrF_i,
    output wire    [6:0] op_o,
    output wire    [2:0] funct3_o,
    output wire          funct7b5_o,
    input                RegWriteW_i,
    input          [2:0] ImmSrcD_i,
    output wire    [4:0] Rs1D_o,
    output wire    [4:0] Rs2D_o,
    input  wire          FlushE_i,
    output reg     [4:0] Rs1E_o,
    output reg     [4:0] Rs2E_o, 
    output reg     [4:0] RdE_o, 
    input                ALUSrcE_i,
    input          [2:0] ALUControlE_i,
    input          [2:0] ForwardAE_i,
    input          [2:0] ForwardBE_i,
    output               ZeroE_o,
    output reg     [4:0] RdM_o, 
    output reg    [31:0] ALUResultM_o,
    output reg    [31:0] WriteDataM_o,
    input         [31:0] ReadDataM_i,
    input          [1:0] ResultSrcW_i,
    output reg     [4:0] RdW_o,
    input          [1:0] ResultSrcM_i,
    output reg           Mispredict_o,

    //slot2 signals
    input                PCSrcE2_i,
    input                StallF2_i,
    output reg    [31:0] PCF2_o,
    input                StallD2_i,
    input                FlushD2_i,
    input         [31:0] InstrF2_i,
    output wire    [6:0] op2_o,
    output wire    [2:0] funct3_2_o,
    output wire          funct7b5_2_o,
    input                RegWriteW2_i,
    input          [2:0] ImmSrcD2_i,
    output wire    [4:0] Rs1D2_o,
    output wire    [4:0] Rs2D2_o,
    input  wire          FlushE2_i,
    output reg     [4:0] Rs1E2_o,
    output reg     [4:0] Rs2E2_o, 
    output reg     [4:0] RdE2_o, 
    input                ALUSrcE2_i,
    input          [2:0] ALUControlE2_i,
    input          [2:0] ForwardAE2_i,
    input          [2:0] ForwardBE2_i,
    output               ZeroE2_o,
    output reg     [4:0] RdM2_o, 
    output reg    [31:0] ALUResultM2_o,
    output reg    [31:0] WriteDataM2_o,
    input         [31:0] ReadDataM2_i,
    input          [1:0] ResultSrcW2_i,
    output reg     [4:0] RdW2_o,
    input          [1:0] ResultSrcM2_i,

    // From decode stage of datapath
    output reg [4:0]  RdD1_o, RdD2_o,

    input RAW,
    input WAR,
    input WAW
);

`include "ucsbece154b_defines.vh"

localparam NUM_BTB_ENTRIES = 32;
localparam NUM_IDX_BITS = $clog2(NUM_BTB_ENTRIES);
localparam NUM_GHR_BITS = 5;

// FIXED: Moved earlier to avoid undefined reference
reg [31:0] PCE;           // Program counter in EX stage
reg [31:0] ExtImmE;       // Immediate in EX stage
wire [31:0] PCTargetE = PCE + ExtImmE;  // FIXED: Define early
reg [31:0] PCPlus4E;      // PC+4 in EX stage
reg [31:0] ResultW;

// NEW: Internal signals for branch predictor
wire [31:0] BTBtargetF;
wire BranchTakenF;
wire [NUM_GHR_BITS-1:0] PHTreadaddrF;     // output from branch predictor
reg  [NUM_GHR_BITS-1:0] PHTwriteaddrD, PHTwriteaddrE;
reg PHTweE, PHTincE;
reg GHRweF, GHRresetE;
reg BTBweE;
reg BranchTakenD, BranchTakenE;
reg [NUM_IDX_BITS-1:0] BTBwriteaddrE;
reg [31:0] BTBwritedataE;

// NEW: Branch predictor instantiation
ucsbece154b_branch #(NUM_BTB_ENTRIES, NUM_GHR_BITS) branch_predictor (
    .clk(clk),
    .reset_i(reset),
    .pc_i(PCF_o),
    .BTBwriteaddress_i(BTBwriteaddrE),
    .BTBwritedata_i(BTBwritedataE),
    .BTBtarget_o(BTBtargetF),
    .BTB_we(BTBweE),
    .BranchTaken_o(BranchTakenF),
    .op_i(op_o),
    .PHTincrement_i(PHTincE),
    .GHRreset_i(GHRresetE),
    .PHTwe_i(PHTweE),
    .GHRwe_i(GHRweF),
    .PHTwriteaddress_i(PHTwriteaddrE),
    .PHTreadaddress_o(PHTreadaddrF)
);

// Moved earlier to avoid undefined reference
reg [31:0] PCE2;           // Program counter in EX stage
reg [31:0] ExtImmE2;       // Immediate in EX stage
wire [31:0] PCTargetE2 = PCE2 + ExtImmE2;  // FIXED: Define early
reg [31:0] PCPlus4E2;      // PC+4 in EX stage
reg [31:0] ResultW2;


// ***** FETCH STAGE *********************************;

wire BranchF = (InstrF_i[6:0] == instr_branch_op);
wire JumpF = (InstrF_i[6:0] == instr_jal_op) || (InstrF_i[6:0] == instr_jalr_op);
wire BranchF2 = (InstrF2_i[6:0] == instr_branch_op);
wire JumpF2 = (InstrF2_i[6:0] == instr_jal_op) || (InstrF2_i[6:0] == instr_jalr_op);
wire BranchJump = BranchF || JumpF || BranchF2 || JumpF2;

wire [4:0] Rs1D2 = InstrF2_i[19:15];
wire [4:0] Rs2D2 = InstrF2_i[24:20];
wire [4:0] RdD1 = InstrF_i[11:7];
wire [4:0] RdD2 = InstrF2_i[11:7];

wire [6:0] opF = InstrF_i[6:0];
wire [6:0] opF2 = InstrF2_i[6:0];
reg RegWriteF;
reg RegWriteF2;

always @ (*) begin
    case (opF)
        instr_lui_op, instr_jal_op, instr_jalr_op: RegWriteF = 1'b1;
        instr_lw_op: RegWriteF = 1'b1;
        instr_Rtype_op: RegWriteF = 1'b1;
        instr_ItypeALU_op: RegWriteF = 1'b1;
        instr_sw_op: RegWriteF = 1'b0;
        instr_branch_op: RegWriteF = 1'b0;
        default: RegWriteF = 1'b0; // NOP or other instructions
    endcase
    case (opF2)
        instr_lui_op, instr_jal_op, instr_jalr_op: RegWriteF2 = 1'b1;
        instr_lw_op: RegWriteF2 = 1'b1;
        instr_Rtype_op: RegWriteF2 = 1'b1;
        instr_ItypeALU_op: RegWriteF2 = 1'b1;
        instr_sw_op: RegWriteF2 = 1'b0;
        instr_branch_op: RegWriteF2 = 1'b0;
        default: RegWriteF2 = 1'b0; // NOP or other instructions
    endcase
end

wire isRtypeF2 = (opF2 == instr_Rtype_op);
wire isStypeF2 = (opF2 == instr_sw_op);
wire check_rs2F2 = isRtypeF2 || isStypeF2;

wire RAWF = ((Rs1D2 == RdD1) && (RdD1 != 5'b0) || 
             (check_rs2F2 && (Rs2D2 == RdD1) && (RdD1 != 5'b0))) 
             && RegWriteF;

wire WAWF = (RdD1 == RdD2) && (RdD1 != 5'b0) && RegWriteF && RegWriteF2;
wire [31:0] PCPlus4F = PCF_o + ((StallF2_i || BranchJump || RAWF || WAWF) ? 32'd4 : 32'd8);
wire [31:0] PCtargetF = BranchTakenF ? BTBtargetF : PCPlus4F;
wire [31:0] mispredPC = BranchTakenE ? PCPlus4E : PCTargetE;
wire [31:0] PCnewF = Mispredict_o ? mispredPC : PCtargetF;

always @ (posedge clk) begin
  if (reset)
    PCF_o <= pc_start;
  else if (!StallF_i) begin
    PCF_o <= PCnewF;
  end
end

// ***** DECODE STAGE ********************************
reg [31:0] InstrD, PCPlus4D, PCD;
reg [31:0] ForwardDataM2;

assign op_o       = InstrD[6:0];
assign funct3_o   = InstrD[14:12];
assign funct7b5_o = InstrD[30]; 

assign Rs1D_o = InstrD[19:15];
assign Rs2D_o = InstrD[24:20];

wire [31:0] RD1D, RD2D;

reg [31:0] ExtImmD;

always @ * begin
   case(ImmSrcD_i)
      imm_Itype: ExtImmD = {{20{InstrD[31]}},InstrD[31:20]};
      imm_Stype: ExtImmD = {{20{InstrD[31]}},InstrD[31:25],InstrD[11:7]};
      imm_Btype: ExtImmD = {{20{InstrD[31]}},InstrD[7],InstrD[30:25], InstrD[11:8],1'b0};
      imm_Jtype: ExtImmD = {{12{InstrD[31]}},InstrD[19:12],InstrD[20],InstrD[30:21],1'b0};
      imm_Utype: ExtImmD = {InstrD[31:12],12'b0};
      default:   ExtImmD = 32'bx; 
   endcase
end

always @ (posedge clk) begin
    if (reset | FlushD_i) begin
        InstrD   <= 32'b0;
        PCPlus4D <= 32'b0;
        PCD      <= 32'b0;
        PHTwriteaddrD <= 5'b0;
        BranchTakenD <= 1'b0;
        RdD1_o <= 5'b0;
    end else if (!StallD_i) begin 
        InstrD   <= InstrF_i;
        PCPlus4D <= PCPlus4F;
        PCD      <= PCF_o;
        PHTwriteaddrD <= PHTreadaddrF;
        BranchTakenD <= BranchTakenF;
        RdD1_o <= InstrF_i[11:7];
    end 
end

// ***** EXECUTE STAGE ******************************

reg [31:0] RD1E, RD2E;
reg [3:0] funct3E;
reg [6:0] opE;

reg [31:0] ForwardDataM;

reg  [31:0] SrcAE;
always @ * begin
    case (ForwardAE_i)
        // forward from own pipe
       {1'b0, forward_mem}: SrcAE = ALUResultM_o; 
        {1'b0, forward_wb}: SrcAE = ResultW;
        {1'b0, forward_ex}: SrcAE = RD1E;

        // forward from other pipe
        {1'b1, forward_mem}: SrcAE = ALUResultM2_o;
        {1'b1, forward_wb}:  SrcAE = ResultW2;
       default: SrcAE = 32'bx;
    endcase
end

reg  [31:0] SrcBE;
reg  [31:0] WriteDataE;
always @ * begin
    case (ForwardBE_i)
       {1'b0, forward_mem}: WriteDataE = ForwardDataM; 
        {1'b0, forward_wb}: WriteDataE = ResultW;
        {1'b0, forward_ex}: WriteDataE = RD2E;
        
        // forward from other pipe
        {1'b1, forward_mem}: WriteDataE = ForwardDataM2;
        {1'b1, forward_wb}:  WriteDataE = ResultW2;
       default: WriteDataE = 32'bx;
    endcase
end

always @ * begin
    case (ALUSrcE_i)
        SrcB_imm: SrcBE = ExtImmE;
        SrcB_reg: SrcBE = WriteDataE;
      default: SrcBE = 32'bx;
    endcase
end

wire [31:0] ALUResultE;
ucsbece154b_alu alu (
    .a_i(SrcAE), .b_i(SrcBE),
    .alucontrol_i(ALUControlE_i),
    .result_o(ALUResultE),
    .zero_o(ZeroE_o)
);

// Branch predictor control logic (NEW)
wire is_branch = (opE == instr_branch_op);
wire is_jump = (opE == instr_jal_op) || (opE == instr_jalr_op);

wire branch_taken_actual = (funct3E == instr_beq_funct3 && ZeroE_o) ||
                            (funct3E == instr_bne_funct3 && !ZeroE_o);

always @(*) begin
    // btb write address is the index of the BTB which is the lower NUM_IDX_BITS of the PC
    BTBwriteaddrE  = PCE[NUM_IDX_BITS+1:2];

    // btb write data is the target address of the branch. the target is the PC + immediate
    // for beq/bne, the target is the PC + immediate
    BTBwritedataE  = PCTargetE;

    // Update BTB on taken branches (including bne)
    BTBweE = (opE == instr_branch_op && 
             ((funct3E == instr_beq_funct3 && ZeroE_o) ||  // beq (taken if ZeroE_o == 1)
              (funct3E == instr_bne_funct3 && !ZeroE_o)))  // bne (taken if ZeroE_o == 0)
           || opE == instr_jal_op 
           || opE == instr_jalr_op;
    
    // Update PHT on all branches in execute
    PHTweE = (opE == instr_branch_op);

    // Update GHR on all branches in fetch
    GHRweF = !StallF_i && (InstrF_i[6:0] == instr_branch_op);
    
    // Increment PHT counter if branch is taken (correct for both beq and bne)
    PHTincE = (opE == instr_branch_op && 
              ((funct3E == instr_beq_funct3 && ZeroE_o) ||   // beq taken
               (funct3E == instr_bne_funct3 && !ZeroE_o)));  // bne taken

    // Reset GHR on misprediction
    GHRresetE = (is_branch && (BranchTakenE != branch_taken_actual)) ||
                   (is_jump && (BranchTakenE != 1'b1));

    // mispredict_o is true if the branch was mispredicted
    // or if the instruction is a jump and the branch was not taken
    Mispredict_o = GHRresetE;
end

always @ (posedge clk) begin
    if (reset | FlushE_i) begin
        RD1E     <= 32'b0;
        RD2E     <= 32'b0;
        PCE      <= 32'b0;
        ExtImmE  <= 32'b0;
        PCPlus4E <= 32'b0;
        Rs1E_o   <=  5'b0;
        Rs2E_o   <=  5'b0;
        RdE_o    <=  5'b0;
        PHTwriteaddrE <= 5'b0;
        opE <= 7'b0;
        BranchTakenE <= 1'b0;
        funct3E <= 3'b0;
    end else begin 
        RD1E     <= RD1D;
        RD2E     <= RD2D;
        PCE      <= PCD;
        ExtImmE  <= ExtImmD;
        PCPlus4E <= PCPlus4D;
        Rs1E_o   <= Rs1D_o;
        Rs2E_o   <= Rs2D_o;
        RdE_o    <= RdD1_o;
        PHTwriteaddrE <= PHTwriteaddrD;
        opE <= op_o;
        BranchTakenE <= BranchTakenD;
        funct3E <= funct3_o;
    end 
end

// ***** MEMORY STAGE ***************************
reg [31:0] ExtImmM, PCPlus4M;

always @ * begin
   case(ResultSrcM_i)
     MuxResult_aluout:  ForwardDataM = ALUResultM_o;
     MuxResult_PCPlus4: ForwardDataM = PCPlus4M;
     MuxResult_imm:     ForwardDataM = ExtImmM;
     default:           ForwardDataM = 32'bx;
   endcase
 end

always @ (posedge clk) begin
    if (reset) begin
        ALUResultM_o <= 32'b0;
        WriteDataM_o <= 32'b0;
        ExtImmM      <= 32'b0;
        PCPlus4M     <= 32'b0;
        RdM_o        <=  5'b0;
    end else begin 
        ALUResultM_o <= ALUResultE;
        WriteDataM_o <= WriteDataE;
        ExtImmM      <= ExtImmE;
        PCPlus4M     <= PCPlus4E;
        RdM_o        <= RdE_o;
    end 
end

// ***** WRITEBACK STAGE ************************
reg [31:0] PCPlus4W, ALUResultW, ReadDataW, ExtImmW;

always @ * begin
   case(ResultSrcW_i)
     MuxResult_mem: ResultW = ReadDataW;
     MuxResult_aluout:  ResultW = ALUResultW;
     MuxResult_PCPlus4:  ResultW = PCPlus4W;
     MuxResult_imm:  ResultW = ExtImmW;
     default:        ResultW = 32'bx;
 endcase
end

always @ (posedge clk) begin
    if (reset) begin
        ALUResultW <= 32'b0;
        ReadDataW  <= 32'b0;
        ExtImmW    <= 32'b0;
        PCPlus4W   <= 32'b0;
        RdW_o      <=  5'b0;
    end else begin 
        ALUResultW <= ALUResultM_o;
        ReadDataW  <= ReadDataM_i;
        ExtImmW    <= ExtImmM;
        PCPlus4W   <= PCPlus4M;
        RdW_o      <= RdM_o;
    end 
end

// ************************** SLOT 2 **************************

// ***** FETCH STAGE *********************************


always @(posedge clk) begin
  if (reset)
    PCF2_o <= pc_start + 32'd4;
  else
    PCF2_o <= PCnewF + 32'd4;
end



// ***** DECODE STAGE ********************************
reg [31:0] InstrD2, PCPlus4D2, PCD2;

assign op2_o       = InstrD2[6:0];
assign funct3_2_o   = InstrD2[14:12];
assign funct7b5_2_o = InstrD2[30]; 

assign Rs1D2_o = InstrD2[19:15];
assign Rs2D2_o = InstrD2[24:20];

wire [31:0] RD1D2, RD2D2;

ucsbece154b_rf rf (
    .clk(~clk),
    .a1_i(Rs1D_o), .a2_i(Rs2D_o), .a3_i(RdW_o),
    .rd1_o(RD1D), .rd2_o(RD2D),
    .we3_i(RegWriteW_i), .wd3_i(ResultW),
    .a1_i2(Rs1D2_o), .a2_i2(Rs2D2_o), .a3_i2(RdW2_o),
    .rd1_o2(RD1D2), .rd2_o2(RD2D2),
    .we3_i2(RegWriteW2_i), .wd3_i2(ResultW2)
);

reg [31:0] ExtImmD2;

always @ * begin
   case(ImmSrcD2_i)
      imm_Itype: ExtImmD2 = {{20{InstrD2[31]}},InstrD2[31:20]};
      imm_Stype: ExtImmD2 = {{20{InstrD2[31]}},InstrD2[31:25],InstrD2[11:7]};
      imm_Btype: ExtImmD2 = {{20{InstrD2[31]}},InstrD2[7],InstrD2[30:25], InstrD2[11:8],1'b0};
      imm_Jtype: ExtImmD2 = {{12{InstrD2[31]}},InstrD2[19:12],InstrD2[20],InstrD2[30:21],1'b0};
      imm_Utype: ExtImmD2 = {InstrD2[31:12],12'b0};
      default:   ExtImmD2 = 32'bx; 
   endcase
end

always @ (posedge clk) begin
    if (reset | FlushD2_i) begin // FlushD2_i handles NOP injection
        InstrD2          <= 32'h00000013; // NOP instruction
        PCPlus4D2        <= 32'b0;
        PCD2             <= 32'b0;
        // PHTwriteaddrD2   <= 5'b0;
        // BranchTakenD2    <= 1'b0;
        RdD2_o <= 5'b0;
    end else if (!StallD2_i) begin
        InstrD2          <= InstrF2_i;
        //PCPlus4D2        <= PCPlus4F2;
        PCD2             <= PCF2_o;
        // PHTwriteaddrD2   <= PHTreadaddrF2;
        // BranchTakenD2    <= BranchTakenF2;
        RdD2_o          <= InstrF2_i[11:7];
    end
end

// ***** EXECUTE STAGE ******************************
reg [31:0] RD1E2, RD2E2;
reg [3:0] funct3E2;
reg [6:0] opE2;

reg  [31:0] SrcAE2;
always @ * begin
    case (ForwardAE2_i)
        // forward from own pipe
       {1'b0, forward_mem}: SrcAE2 = ALUResultM2_o; 
        {1'b0, forward_wb}: SrcAE2 = ResultW2;
        {1'b0, forward_ex}: SrcAE2 = RD1E2;
        
        // forward from other pipe
        {1'b1, forward_mem}: SrcAE2 = ALUResultM_o;
        {1'b1, forward_wb}:  SrcAE2 = ResultW;
       default: SrcAE2 = 32'bx;
    endcase
end

reg  [31:0] SrcBE2;
reg  [31:0] WriteDataE2;
always @ * begin
    case (ForwardBE2_i)
        // forward from own pipe
       {1'b0, forward_mem}: WriteDataE2 = ForwardDataM2; 
        {1'b0, forward_wb}: WriteDataE2 = ResultW2;
        {1'b0, forward_ex}: WriteDataE2 = RD2E2;

        // forward from other pipe
        {1'b1, forward_mem}: WriteDataE2 = ForwardDataM;
        {1'b1, forward_wb}:  WriteDataE2 = ResultW;
       default: WriteDataE2 = 32'bx;
    endcase
end

always @ * begin
    case (ALUSrcE2_i)
        SrcB_imm: SrcBE2 = ExtImmE2;
        SrcB_reg: SrcBE2 = WriteDataE2;
      default: SrcBE2 = 32'bx;
    endcase
end

wire [31:0] ALUResultE2;
ucsbece154b_alu alu2 (
    .a_i(SrcAE2), .b_i(SrcBE2),
    .alucontrol_i(ALUControlE2_i),
    .result_o(ALUResultE2),
    .zero_o(ZeroE2_o)
);

always @ (posedge clk) begin
    if (reset | FlushE2_i) begin
        RD1E2     <= 32'b0;
        RD2E2     <= 32'b0;
        PCE2      <= 32'b0;
        ExtImmE2  <= 32'b0;
        //PCPlus4E2 <= 32'b0;
        Rs1E2_o   <=  5'b0;
        Rs2E2_o   <=  5'b0;
        RdE2_o    <=  5'b0;
        //PHTwriteaddrE2 <= 5'b0;
        opE2 <= 7'b0;
        //BranchTakenE2 <= 1'b0;
        funct3E2 <= 3'b0;
    end else begin 
        RD1E2     <= RD1D2;
        RD2E2     <= RD2D2;
        PCE2      <= PCD2;
        ExtImmE2  <= ExtImmD2;
        //PCPlus4E2 <= PCPlus4D2;
        Rs1E2_o   <= Rs1D2_o;
        Rs2E2_o   <= Rs2D2_o;
        RdE2_o    <= RdD2_o;
        // PHTwriteaddrE2 <= PHTwriteaddrD2;
        opE2 <= op2_o;
        //BranchTakenE2 <= BranchTakenD2;
        funct3E2 <= funct3_2_o;
    end 
end

// ***** MEMORY STAGE ***************************
reg [31:0] ExtImmM2, PCPlus4M2;

always @ * begin
   case(ResultSrcM2_i)
     MuxResult_aluout:  ForwardDataM2 = ALUResultM2_o;
     MuxResult_PCPlus4: ForwardDataM2 = PCPlus4M2;
     MuxResult_imm:     ForwardDataM2 = ExtImmM2;
     default:           ForwardDataM2 = 32'bx;
   endcase
 end

always @ (posedge clk) begin
    if (reset) begin
        ALUResultM2_o <= 32'b0;
        WriteDataM2_o <= 32'b0;
        ExtImmM2      <= 32'b0;
        //PCPlus4M2     <= 32'b0;
        RdM2_o        <=  5'b0;
    end else begin 
        ALUResultM2_o <= ALUResultE2;
        WriteDataM2_o <= WriteDataE2;
        ExtImmM2      <= ExtImmE2;
        //PCPlus4M2     <= PCPlus4E2;
        RdM2_o        <= RdE2_o;
    end 
end

// ***** WRITEBACK STAGE ************************
reg [31:0] PCPlus4W2, ALUResultW2, ReadDataW2, ExtImmW2;

always @ * begin
   case(ResultSrcW2_i)
     MuxResult_mem: ResultW2 = ReadDataW2;
     MuxResult_aluout:  ResultW2 = ALUResultW2;
     //MuxResult_PCPlus4:  ResultW2 = PCPlus4W2;
     MuxResult_imm:  ResultW2 = ExtImmW2;
     default:        ResultW2 = 32'bx;
 endcase
end

always @ (posedge clk) begin
    if (reset) begin
        ALUResultW2 <= 32'b0;
        ReadDataW2  <= 32'b0;
        ExtImmW2    <= 32'b0;
        //PCPlus4W2   <= 32'b0;
        RdW2_o      <=  5'b0;
    end else begin 
        ALUResultW2 <= ALUResultM2_o;
        ReadDataW2  <= ReadDataM2_i;
        ExtImmW2    <= ExtImmM2;
        //PCPlus4W2   <= PCPlus4M2;
        RdW2_o      <= RdM2_o;
    end 
end

endmodule