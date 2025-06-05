`define SIM

module ucsbece154b_top_tb ();

reg clk = 1;
always #1 clk <= ~clk;

reg reset;

ucsbece154b_top top (
    .clk(clk),
    .reset(reset)
);

// Register file probes
wire [31:0] reg_s0 = top.riscv.dp.rf.s0;
wire [31:0] reg_s1 = top.riscv.dp.rf.s1;
wire [31:0] reg_s2 = top.riscv.dp.rf.s2;
wire [31:0] reg_s3 = top.riscv.dp.rf.s3;
wire [31:0] reg_t0 = top.riscv.dp.rf.t0;
wire [31:0] reg_t1 = top.riscv.dp.rf.t1;
wire [31:0] reg_t2 = top.riscv.dp.rf.t2;
wire [31:0] reg_t3 = top.riscv.dp.rf.t3;
wire [31:0] reg_t4 = top.riscv.dp.rf.t4;
wire [31:0] reg_t5 = top.riscv.dp.rf.t5;
wire [31:0] reg_t6 = top.riscv.dp.rf.t6;

wire [31:0] InstrD = top.riscv.dp.InstrD;
wire [31:0] InstrD2 = top.riscv.dp.InstrD2;

wire [31:0] PCF_o = top.riscv.dp.PCF_o;
wire [31:0] PCF2_o = top.riscv.dp.PCF2_o;
wire [31:0] InstrF_i = top.riscv.dp.InstrF_i;
wire [31:0] InstrF2_i = top.riscv.dp.InstrF2_i;

wire RAW = top.riscv.c.RAW;
wire WAW = top.riscv.c.WAW;
wire WAR = top.riscv.c.WAR;

wire [4:0] rs1_1 = top.riscv.c.Rs1D_i;
wire [4:0] rs2_1 = top.riscv.c.Rs2D_i;
wire [4:0] rd_1 = top.riscv.c.RdD1_i;
wire [4:0] rs1_2 = top.riscv.c.Rs1D2_i;
wire [4:0] rs2_2 = top.riscv.c.Rs2D2_i;
wire [4:0] rd_2 = top.riscv.c.RdD2_i;
wire RegWriteD = top.riscv.c.RegWriteD;
wire RegWriteD2 = top.riscv.c.RegWriteD2;

wire Hazard = top.riscv.c.Hazard;

integer cycle_count;
integer instruction_count;
integer branch_count, branch_miss_count;
integer jump_count, jump_miss_count;

reg [31:0] prev_pc1, prev_pc2;

integer i;
initial begin
    $display("Begin simulation.");
    reset = 1;
    cycle_count = 0;
    instruction_count = 0;
    branch_count = 0;
    branch_miss_count = 0;
    jump_count = 0;
    jump_miss_count = 0;
    prev_pc1 = 0;
    prev_pc2 = 0;

    @(posedge clk);
    @(posedge clk);
    reset = 0;

    for (i = 0; i < 500 &&
         !((prev_pc1 == top.riscv.dp.PCF_o && top.riscv.dp.InstrF_i == 32'h00000013) &&
           (prev_pc2 == top.riscv.dp.PCF2_o && top.riscv.dp.InstrF2_i == 32'h00000013)); i = i + 1) begin

        @(posedge clk);
        prev_pc1 <= top.riscv.dp.PCF_o;
        prev_pc2 <= top.riscv.dp.PCF2_o;
        cycle_count = cycle_count + 1;

        // Count instruction issue
        if (!reset) begin
            if (top.riscv.dp.InstrD !== 32'b0 && top.riscv.dp.InstrD != 32'h00000013)
                instruction_count = instruction_count + 1;
            if (top.riscv.dp.InstrD2 !== 32'b0 && top.riscv.dp.InstrD2 != 32'h00000013)
                instruction_count = instruction_count + 1;

            // Branch / Jump - Slot 1
            case (top.riscv.dp.opE)
                7'b1100011: begin
                    branch_count = branch_count + 1;
                    if (top.riscv.dp.Mispredict_o)
                        branch_miss_count = branch_miss_count + 1;
                end
                7'b1101111, 7'b1100111: begin
                    jump_count = jump_count + 1;
                    if (!top.riscv.dp.BranchTakenF)
                        jump_miss_count = jump_miss_count + 1;
                end
            endcase

            // Branch / Jump - Slot 2
            case (top.riscv.dp.opE2)
                7'b1100011: begin
                    branch_count = branch_count + 1;
                    if (top.riscv.dp.Mispredict2_o)
                        branch_miss_count = branch_miss_count + 1;
                end
                7'b1101111, 7'b1100111: begin
                    jump_count = jump_count + 1;
                    if (!top.riscv.dp.BranchTakenF2)
                        jump_miss_count = jump_miss_count + 1;
                end
            endcase
        end
    end

    $display("---- PROGRAM COMPLETE ----");
    $display("Register values:");
    $display("s0 (countx)      = %0d", reg_s0);
    $display("s1 (county)      = %0d", reg_s1);
    $display("s2 (countz)      = %0d", reg_s2);
    $display("s3 (innercount)  = %0d", reg_s3);
    $display("t0 = %0d", reg_t0);
    $display("t1 = %0d", reg_t1);
    $display("t2 = %0d", reg_t2);
    $display("t3 = %0d", reg_t3);
    $display("t4 = %0d", reg_t4);
    $display("t5 = %0d", reg_t5);
    $display("t6 = %0d", reg_t6);
    $display("--------------------------");
    $display("Performance:");
    $display("Cycle count:            %0d", cycle_count);
    $display("Instruction count:      %0d", instruction_count);
    $display("CPI:                    %0f", 1.0 * cycle_count / instruction_count);
    $display("Branch count:           %0d", branch_count);
    $display("Branch mispredictions:  %0d", branch_miss_count);
    $display("Branch misprediction rate: %0f%%", 
        (branch_count > 0) ? 100.0 * branch_miss_count / branch_count : 0.0);
    $display("Jump count:             %0d", jump_count);
    $display("Jump mispredictions:    %0d", jump_miss_count);
    $display("Jump misprediction rate:   %0f%%",
        (jump_count > 0) ? 100.0 * jump_miss_count / jump_count : 0.0);

    $stop;
end

endmodule
