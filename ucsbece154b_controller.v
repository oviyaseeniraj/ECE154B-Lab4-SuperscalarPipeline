// ucsbece154b_controller.v
// ECE 154B, RISC-V pipelined processor 
// All Rights Reserved
// Copyright (c) 2024 UCSB ECE
// Distribution Prohibited


module ucsbece154b_controller (
    input                clk, reset,
    input         [6:0]  op_i, 
    input         [2:0]  funct3_i,
    input                funct7b5_i,
    input 	             ZeroE_i,
    input         [4:0]  Rs1D_i,
    input         [4:0]  Rs2D_i,
    input         [4:0]  Rs1E_i,
    input         [4:0]  Rs2E_i,
    input         [4:0]  RdE_i,
    input         [4:0]  RdM_i,
    input         [4:0]  RdW_i,
    output wire		     StallF_o,  
    output wire          StallD_o,
    output wire          FlushD_o,
    output wire    [2:0] ImmSrcD_o,
    output wire          PCSrcE_o,
    output reg     [2:0] ALUControlE_o,
    output reg           ALUSrcE_o,
    output wire          FlushE_o,
    output reg     [2:0] ForwardAE_o,
    output reg     [2:0] ForwardBE_o,
    output reg           MemWriteM_o,
    output reg           RegWriteW_o,
    output reg     [1:0] ResultSrcW_o, 
    output reg     [1:0] ResultSrcM_o,
    input                Mispredict_i,

    // slot 2
    input         [6:0]  op2_i, 
    input         [2:0]  funct3_2_i,
    input                funct7b5_2_i,
    input 	             ZeroE2_i,
    input         [4:0]  Rs1D2_i,
    input         [4:0]  Rs2D2_i,
    input         [4:0]  Rs1E2_i,
    input         [4:0]  Rs2E2_i,
    input         [4:0]  RdE2_i,
    input         [4:0]  RdM2_i,
    input         [4:0]  RdW2_i,
    output wire		     StallF2_o,  
    output wire          StallD2_o,
    output wire          FlushD2_o,
    output wire    [2:0] ImmSrcD2_o,
    output wire          PCSrcE2_o,
    output reg     [2:0] ALUControlE2_o,
    output reg           ALUSrcE2_o,
    output wire          FlushE2_o,
    output reg     [2:0] ForwardAE2_o,
    output reg     [2:0] ForwardBE2_o,
    output reg           MemWriteM2_o,
    output reg           RegWriteW2_o,
    output reg     [1:0] ResultSrcW2_o, 
    output reg     [1:0] ResultSrcM2_o,

    input [4:0] RdD1_i,
    input [4:0] RdD2_i,

    output RAW,
    output WAR,
    output WAW
);


 `include "ucsbece154b_defines.vh"

// Decoder signals other than from hazard unit are implemented next. Hazard unit is implemented at the end

// ***** FETCH STAGE ***************************************

// ***** DECODE STAGE **************************************
 wire RegWriteD, MemWriteD, JumpD, ALUSrcD;
 reg BranchTypeD;
 wire [1:0] ResultSrcD; 
 reg [2:0] ALUControlD;
 
 wire [1:0] ALUOpD;

 reg [11:0] maindecoderD; // Note that maindecoder is just clubbing of signals for a convinient (compact, human readable) implementaiton of main decoder table. "reg" is required because is maindecoder is used in always block, which is used because of case statements. Also note that default in always blocks is a must in such case, otherwise maindecoder will be treated as register.

wire Hazard;

 assign {RegWriteD,	
	      ImmSrcD_o,
        ALUSrcD,
        MemWriteD,
        ResultSrcD,
         BranchD, 
         ALUOpD,
         JumpD} = maindecoderD;

 always @ * begin
   case (op_i)
	instr_lw_op:        maindecoderD = 12'b1_000_1_0_01_0_00_0;       
	instr_sw_op:        maindecoderD = 12'b0_001_1_1_00_0_00_0; 
	instr_Rtype_op:     maindecoderD = 12'b1_xxx_0_0_00_0_10_0;  
	instr_branch_op:    maindecoderD = 12'b0_010_0_0_00_1_01_0;  
	instr_ItypeALU_op:  maindecoderD = 12'b1_000_1_0_00_0_10_0; 
	instr_jal_op:       maindecoderD = 12'b1_011_x_0_10_0_xx_1; 
        instr_lui_op:       maindecoderD = 12'b1_100_x_0_11_0_xx_0; 
        instr_jalr_op:      maindecoderD = 12'b1_000_x_0_10_0_xx_1;  
	default: 	    maindecoderD = 12'b0_xxx_x_0_xx_0_xx_0; 
//            `ifdef SIM
//            $warning("Unsupported op given: %h", op_i);
//            `else
//            ;
//            `endif
   endcase
 end

 wire RtypeSubD;

 assign RtypeSubD = funct7b5_i & op_i[5];

 always @ * begin
  case(ALUOpD)
    ALUop_mem:                 ALUControlD = ALUcontrol_add;
    ALUop_beqbne:              ALUControlD = ALUcontrol_sub;
    ALUop_other: 
       case(funct3_i)
           instr_addsub_funct3: 
                 if(RtypeSubD) ALUControlD = ALUcontrol_sub;
                 else          ALUControlD = ALUcontrol_add;  
           instr_slt_funct3:   ALUControlD = ALUcontrol_slt;  
           instr_or_funct3:    ALUControlD = ALUcontrol_or;  
           instr_and_funct3:   ALUControlD = ALUcontrol_and;  
           default:            ALUControlD = 3'bxxx;
        //     `ifdef SIM
        //         $warning("Unsupported funct3 given: %h", funct3_i);
        //     `else
        //         ;
        //     `endif  
       endcase
    //default:
      // `ifdef SIM
      //     $warning("Unsupported ALUop given: %h", ALUOpD);
      // `else
      //     ;
      // `endif   
   endcase
 end

// this is pipelined signal to invert zero when branch is bne

 always @ * begin
  case(funct3_i)
    instr_beq_funct3:      BranchTypeD = 1'b0;
    instr_bne_funct3:      BranchTypeD = 1'b1;
    default:               BranchTypeD = 1'bx;
   endcase
 end


// ****** EXECUTE STAGE ****************************************
 reg RegWriteE, MemWriteE, JumpE, BranchE;
 reg BranchTypeE;
 reg [1:0] ResultSrcE;
 reg [6:0] opE;
 reg [2:0] funct3E;

 // Pipeline registers for op_i and funct3_i
 always @(posedge clk) begin
    if (FlushE_o | reset) begin
        opE     <= 7'b0;
        funct3E <= 3'b0;
    end else begin
        opE     <= op_i;
        funct3E <= funct3_i;
    end
 end

 assign PCSrcE_o = BranchE & (ZeroE_i ^ BranchTypeE) | JumpE;


// Update registers (move control signals via pipeline)
 always @(posedge clk) begin
    if(FlushE_o | reset) begin
       RegWriteE     <=  1'b0;
       ResultSrcE    <=  2'b0;
       MemWriteE     <=  1'b0;
       JumpE         <=  1'b0;
       BranchE       <=  1'b0;
       ALUControlE_o <=  3'b0;
       ALUSrcE_o     <=  1'b0;
       BranchTypeE   <=  1'b0;
    end else begin
       RegWriteE     <= RegWriteD;
       ResultSrcE    <= ResultSrcD;
       MemWriteE     <= MemWriteD;
       JumpE         <= JumpD;
       BranchE       <= BranchD;
       ALUControlE_o <= ALUControlD;
       ALUSrcE_o     <= ALUSrcD; 
       BranchTypeE   <= BranchTypeD;
    end
 end 

// ***** MEMORY STAGE ******************************************
 reg RegWriteM;
  reg RegWriteM2;

// Update registers (move control signals via pipeline)
 always @(posedge clk) begin
    if(reset) begin 
       RegWriteM    <= 1'b0;
       ResultSrcM_o <= 2'b0;
       MemWriteM_o  <= 1'b0;
    end else begin
       RegWriteM    <= RegWriteE;
       ResultSrcM_o <= ResultSrcE;
       MemWriteM_o  <= MemWriteE;
    end
  end


// ***** WRITEBACK STAGE ***************************************

// Update registers (move control signals via pipeline)
 always @(posedge clk) begin
    if(reset) begin 
       RegWriteW_o  <= 1'b0;
       ResultSrcW_o <= 2'b0;
    end else begin
       RegWriteW_o  <= RegWriteM;
       ResultSrcW_o <= ResultSrcM_o;
    end
  end


// Hazard unit (stall and data forwarding)

// Forwarding logic
 always @ * begin
  if      ( (Rs1E_i == RdM_i) & RegWriteM & (Rs1E_i != 0) ) 
         ForwardAE_o = {1'b0, forward_mem};
  else if ( (Rs1E_i == RdW_i) & RegWriteW_o & (Rs1E_i != 0) ) 
         ForwardAE_o = {1'b0, forward_wb};
   else if ((Rs1E_i == RdM2_i) && RegWriteM2 && (Rs1E_i != 0)) 
    ForwardAE_o = {1'b1, forward_mem};
   else if ((Rs1E_i == RdW2_i) && RegWriteW2_o && (Rs1E_i != 0)) 
    ForwardAE_o = {1'b1, forward_wb};
  else   ForwardAE_o = {1'b0, forward_ex};
 end
  
 always @ * begin
  if      ( (Rs2E_i == RdM_i) & RegWriteM & (Rs2E_i != 0) ) 
         ForwardBE_o = {1'b0, forward_mem};
  else if ( (Rs2E_i == RdW_i) & RegWriteW_o & (Rs2E_i != 0) ) 
         ForwardBE_o = {1'b0, forward_wb};
   else if ((Rs2E_i == RdM2_i) && RegWriteM2 && (Rs2E_i != 0)) 
    ForwardBE_o = {1'b1, forward_mem};
   else if ((Rs2E_i == RdW2_i) && RegWriteW2_o && (Rs2E_i != 0)) 
    ForwardBE_o = {1'b1, forward_wb};

  else   ForwardBE_o = {1'b0, forward_ex};
 end

// Stall logic
 wire lwStall = (ResultSrcE == 1) & ((Rs1D_i == RdE_i) | (Rs2D_i == RdE_i)) & (RdE_i != 0); 
 //assign lwStall = (ResultSrcE == 1) & ( (Rs1D_i == RdE_i) | (Rs2D_i == RdE_i) ) & (RdE_i != 0); 
 assign StallF_o = lwStall; 
 assign StallD_o = lwStall; 
 assign FlushD_o = Mispredict_i; 
 assign FlushE_o = lwStall | Mispredict_i;


// slot 2

// ***** FETCH STAGE ***************************************

// ***** DECODE STAGE **************************************
 wire RegWriteD2, MemWriteD2, JumpD2, ALUSrcD2;
 reg BranchTypeD2;
 wire [1:0] ResultSrcD2; 
 reg [2:0] ALUControlD2;
 
 wire [1:0] ALUOpD2;

 reg [11:0] maindecoderD2; // Note that maindecoder is just clubbing of signals for a convinient (compact, human readable) implementaiton of main decoder table. "reg" is required because is maindecoder is used in always block, which is used because of case statements. Also note that default in always blocks is a must in such case, otherwise maindecoder will be treated as register.


 assign {RegWriteD2,	
	      ImmSrcD2_o,
        ALUSrcD2,
        MemWriteD2,
        ResultSrcD2,
         BranchD2, 
         ALUOpD2,
         JumpD2} = maindecoderD2;

 always @ * begin
   case (op2_i)
      instr_lw_op:        maindecoderD2 = 12'b1_000_1_0_01_0_00_0;       
      instr_sw_op:        maindecoderD2 = 12'b0_001_1_1_00_0_00_0; 
      instr_Rtype_op:     maindecoderD2 = 12'b1_xxx_0_0_00_0_10_0;  
      instr_branch_op:    maindecoderD2 = 12'b0_010_0_0_00_1_01_0;  
      instr_ItypeALU_op:  maindecoderD2 = 12'b1_000_1_0_00_0_10_0; 
      instr_jal_op:       maindecoderD2 = 12'b1_011_x_0_10_0_xx_1; 
         instr_lui_op:       maindecoderD2 = 12'b1_100_x_0_11_0_xx_0; 
         instr_jalr_op:      maindecoderD2 = 12'b1_000_x_0_10_0_xx_1;  
      default: 	    maindecoderD2 = 12'b0_xxx_x_0_xx_0_xx_0; 
   //            `ifdef SIM
   //            $warning("Unsupported op given: %h", op_i);
   //            `else
   //            ;
   //            `endif
   endcase
 end

 wire RtypeSubD2;

 assign RtypeSubD2 = funct7b5_2_i & op2_i[5];

 always @ * begin
  case(ALUOpD2)
    ALUop_mem:                 ALUControlD2 = ALUcontrol_add;
    ALUop_beqbne:              ALUControlD2 = ALUcontrol_sub;
    ALUop_other: 
       case(funct3_2_i)
           instr_addsub_funct3: 
                 if(RtypeSubD2) ALUControlD2 = ALUcontrol_sub;
                 else          ALUControlD2 = ALUcontrol_add;  
           instr_slt_funct3:   ALUControlD2 = ALUcontrol_slt;  
           instr_or_funct3:    ALUControlD2 = ALUcontrol_or;  
           instr_and_funct3:   ALUControlD2 = ALUcontrol_and;  
           default:            ALUControlD2 = 3'bxxx;
        //     `ifdef SIM
        //         $warning("Unsupported funct3 given: %h", funct3_i);
        //     `else
        //         ;
        //     `endif  
       endcase
    //default:
      // `ifdef SIM
      //     $warning("Unsupported ALUop given: %h", ALUOpD);
      // `else
      //     ;
      // `endif   
   endcase
 end

// this is pipelined signal to invert zero when branch is bne

 always @ * begin
  case(funct3_2_i)
    instr_beq_funct3:      BranchTypeD2 = 1'b0;
    instr_bne_funct3:      BranchTypeD2 = 1'b1;
    default:               BranchTypeD2 = 1'bx;
   endcase
 end


// ****** EXECUTE STAGE ****************************************
 reg RegWriteE2, MemWriteE2, JumpE2, BranchE2;
 reg BranchTypeE2;
 reg [1:0] ResultSrcE2;
 reg [6:0] opE2;
 reg [2:0] funct3E2;

 // Pipeline registers for op2_i and funct3_2_i
 always @(posedge clk) begin
    if (FlushE2_o | reset) begin
        opE2     <= 7'b0;
        funct3E2 <= 3'b0;
    end else begin
        opE2     <= op2_i;
        funct3E2 <= funct3_2_i;
    end
 end

 assign PCSrcE2_o = BranchE2 & (ZeroE2_i ^ BranchTypeE2) | JumpE2;

// Update registers (move control signals via pipeline)
 always @(posedge clk) begin
    if(FlushE2_o | reset) begin
       RegWriteE2     <=  1'b0;
       ResultSrcE2    <=  2'b0;
       MemWriteE2     <=  1'b0;
       JumpE2         <=  1'b0;
       BranchE2       <=  1'b0;
       ALUControlE2_o <=  3'b0;
       ALUSrcE2_o     <=  1'b0;
       BranchTypeE2   <=  1'b0;
    end else begin
       RegWriteE2     <= RegWriteD2;
       ResultSrcE2    <= ResultSrcD2;
       MemWriteE2     <= MemWriteD2;
       JumpE2         <= JumpD2;
       BranchE2       <= BranchD2;
       ALUControlE2_o <= ALUControlD2;
       ALUSrcE2_o     <= ALUSrcD2; 
       BranchTypeE2   <= BranchTypeD2;
    end
 end 

// ***** MEMORY STAGE ******************************************


// Update registers (move control signals via pipeline)
 always @(posedge clk) begin
    if(reset) begin 
       RegWriteM2    <= 1'b0;
       ResultSrcM2_o <= 2'b0;
       MemWriteM2_o  <= 1'b0;
    end else begin
       RegWriteM2    <= RegWriteE2;
       ResultSrcM2_o <= ResultSrcE2;
       MemWriteM2_o  <= MemWriteE2;
    end
  end


// ***** WRITEBACK STAGE ***************************************

// Update registers (move control signals via pipeline)
always @(posedge clk) begin
    if(reset) begin 
       RegWriteW2_o  <= 1'b0;
       ResultSrcW2_o <= 2'b0;
    end else begin
       RegWriteW2_o  <= RegWriteM2;
       ResultSrcW2_o <= ResultSrcM2_o;
    end
  end

  // Forwarding logic for slot 2 (Rs1E2_i)
   always @ * begin
      if      ( (Rs1E2_i == RdM2_i) & RegWriteM2 & (Rs1E2_i != 0) ) 
               ForwardAE2_o = {1'b0, forward_mem};
      else if ( (Rs1E2_i == RdW2_i) & RegWriteW2_o & (Rs1E2_i != 0) ) 
               ForwardAE2_o = {1'b0, forward_wb};
      else if ( (Rs1E2_i == RdM_i)  & RegWriteM  & (Rs1E2_i != 0) ) 
               ForwardAE2_o = {1'b1, forward_mem};
      else if ( (Rs1E2_i == RdW_i)  & RegWriteW_o  & (Rs1E2_i != 0) ) 
               ForwardAE2_o = {1'b1, forward_wb};
      else   ForwardAE2_o = {1'b0, forward_ex};
   end

   // Forwarding logic for slot 2 (Rs2E2_i)
   always @ * begin
      if      ( (Rs2E2_i == RdM2_i) & RegWriteM2 & (Rs2E2_i != 0) ) 
               ForwardBE2_o = {1'b0, forward_mem};
      else if ( (Rs2E2_i == RdW2_i) & RegWriteW2_o & (Rs2E2_i != 0) ) 
               ForwardBE2_o = {1'b0, forward_wb};
      else if ( (Rs2E2_i == RdM_i)  & RegWriteM  & (Rs2E2_i != 0) ) 
               ForwardBE2_o = {1'b1, forward_mem};
      else if ( (Rs2E2_i == RdW_i)  & RegWriteW_o  & (Rs2E2_i != 0) ) 
               ForwardBE2_o = {1'b1, forward_wb};
      else   ForwardBE2_o = {1'b0, forward_ex};
   end


   // Hazard unit (stall and data forwarding)
   wire Rs2ValidD2 = (op2_i == instr_Rtype_op) || (op2_i == instr_sw_op) || (op2_i == instr_branch_op);

   assign RAW = RegWriteD && (RdD1_i != 5'b0) &&
               ((Rs1D2_i == RdD1_i) ||
               (Rs2ValidD2 && Rs2D2_i == RdD1_i));
   

   assign WAW = (RdD1_i == RdD2_i) && (RdD1_i != 5'b0) &&
               RegWriteD && RegWriteD2;

   wire Rs2ValidD1 = (op_i == instr_Rtype_op) || (op_i == instr_sw_op) || (op_i == instr_branch_op);

   assign WAR = RegWriteD2 && (RdD2_i != 5'b0) &&
               ((Rs1D_i == RdD2_i) ||
               (Rs2ValidD1 && Rs2D_i == RdD2_i));



   wire lwStall2 = (ResultSrcE2 == 2'b01) && ((Rs1D2_i == RdE2_i && RdE2_i != 0) || (Rs2D2_i == RdE2_i && RdE2_i != 0));

   // load use hazards between pipelines
   wire loadUse2 = (ResultSrcE2 == 2'b01) && ((Rs1D_i == RdE2_i && RdE2_i != 0) || (Rs2D_i == RdE2_i && RdE2_i != 0));
   wire loadUse1 = (ResultSrcE == 2'b01) && ((Rs1D2_i == RdE_i && RdE_i != 0) || (Rs2D2_i == RdE_i && RdE_i != 0));

   assign Hazard = RAW || WAW || loadUse1 || loadUse2 || BranchD || JumpD || BranchD2 || JumpD2; 

   assign StallF2_o = Hazard;
   assign StallD2_o = Hazard;
   assign FlushD2_o = Hazard || Mispredict_i;
   assign FlushE2_o = Hazard || Mispredict_i;


endmodule