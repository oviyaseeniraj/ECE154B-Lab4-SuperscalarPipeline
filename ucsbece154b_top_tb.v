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

    @(posedge clk);
    @(posedge clk);
    reset = 0;

    for (i = 0; i < 200 && !((prev_pc1 == top.riscv.dp.PCF_o && top.riscv.dp.InstrF_i == 32'h00000013) &&
                             (prev_pc2 == top.riscv.dp.PCF2_o && top.riscv.dp.InstrF2_i == 32'h00000013)); i = i + 1) begin
        @(posedge clk);
        prev_pc1 <= top.riscv.dp.PCF_o;
        prev_pc2 <= top.riscv.dp.PCF2_o;
        cycle_count++;

        if (top.riscv.dp.InstrD !== 32'b0 && top.riscv.dp.InstrD != 32'h00000013)
            instruction_count++;
        if (top.riscv.dp.InstrD2 !== 32'b0 && top.riscv.dp.InstrD2 != 32'h00000013)
            instruction_count++;
    end

    $display("---- PROGRAM COMPLETE ----");
    $display("s0 = %0d", reg_s0);
    $display("s1 = %0d", reg_s1);
    $display("Instruction count: %0d", instruction_count);
    $display("Cycle count:       %0d", cycle_count);
    $display("CPI:               %0f", 1.0 * cycle_count / instruction_count);
    $stop;
end

endmodule
