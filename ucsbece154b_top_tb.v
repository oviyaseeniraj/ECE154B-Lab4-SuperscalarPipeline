`define SIM

module ucsbece154b_top_tb ();

reg clk = 1;
always #1 clk <= ~clk;

reg reset;

ucsbece154b_top top (
    .clk(clk),
    .reset(reset)
);

// Probes for written registers
wire [31:0] reg_s0 = top.riscv.dp.rf.s0;
wire [31:0] reg_s1 = top.riscv.dp.rf.s1;
wire [31:0] reg_s2 = top.riscv.dp.rf.s2;
wire [31:0] reg_s3 = top.riscv.dp.rf.s3;
wire [31:0] reg_s4 = top.riscv.dp.rf.s4;
wire [31:0] reg_s5 = top.riscv.dp.rf.s5;
wire [31:0] reg_s6 = top.riscv.dp.rf.s6;
wire [31:0] reg_t0 = top.riscv.dp.rf.t0;
wire [31:0] reg_t1 = top.riscv.dp.rf.t1;
wire [31:0] reg_t2 = top.riscv.dp.rf.t2;
wire [31:0] reg_t3 = top.riscv.dp.rf.t3;
wire [31:0] reg_t4 = top.riscv.dp.rf.t4;
wire [31:0] reg_t5 = top.riscv.dp.rf.t5;
wire [31:0] reg_t6 = top.riscv.dp.rf.t6;
wire [31:0] reg_a0 = top.riscv.dp.rf.a0;
wire [31:0] reg_a1 = top.riscv.dp.rf.a1;
wire [31:0] reg_a2 = top.riscv.dp.rf.a2;
wire [31:0] reg_a3 = top.riscv.dp.rf.a3;
wire [31:0] reg_a4 = top.riscv.dp.rf.a4;
wire [31:0] reg_a5 = top.riscv.dp.rf.a5;
wire [31:0] reg_a6 = top.riscv.dp.rf.a6;
wire [31:0] reg_a7 = top.riscv.dp.rf.a7;

integer cycle_count;
integer instruction_count;
reg [31:0] prev_pc1, prev_pc2;

integer i;
initial begin
    $display("Begin simulation.");
    reset = 1;
    cycle_count = 0;
    instruction_count = 0;
    prev_pc1 = 0;
    prev_pc2 = 0;

    @(posedge clk); @(posedge clk);
    reset = 0;

    for (i = 0; i < 100 && !((top.riscv.dp.InstrF_i == 32'h00000013) &&
                             (top.riscv.dp.InstrF2_i == 32'h00000013)); i++) begin
        @(posedge clk);
        cycle_count++;

        if (top.riscv.dp.InstrD !== 32'b0 && top.riscv.dp.InstrD != 32'h00000013)
            instruction_count++;
        if (top.riscv.dp.InstrD2 !== 32'b0 && top.riscv.dp.InstrD2 != 32'h00000013)
            instruction_count++;
    end

    $display("---- PROGRAM COMPLETE ----");
    $display("Instruction Count: %0d", instruction_count);
    $display("Cycle Count:       %0d", cycle_count);
    $display("CPI:               %0f", 1.0 * cycle_count / instruction_count);
    $display("----- Register Values -----");
    $display("s0  = %0d", reg_s0);
    $display("s1  = %0d", reg_s1);
    $display("s2  = %0d", reg_s2);
    $display("s3  = %0d", reg_s3);
    $display("s4  = %0d", reg_s4);
    $display("s5  = %0d", reg_s5);
    $display("s6  = %0d", reg_s6);
    $display("t0  = %0d", reg_t0);
    $display("t1  = %0d", reg_t1);
    $display("t2  = %0d", reg_t2);
    $display("t3  = %0d", reg_t3);
    $display("t4  = %0d", reg_t4);
    $display("t5  = %0d", reg_t5);
    $display("t6  = %0d", reg_t6);
    $display("a0  = %0d", reg_a0);
    $display("a1  = %0d", reg_a1);
    $display("a2  = %0d", reg_a2);
    $display("a3  = %0d", reg_a3);
    $display("a4  = %0d", reg_a4);
    $display("a5  = %0d", reg_a5);
    $display("a6  = %0d", reg_a6);
    $display("a7  = %0d", reg_a7);

    $stop;
end

endmodule
