`define SIM
// `timescale 1ns / 1ps // Optional: define timescale if not globally defined

module ucsbece154b_top_tb ();

reg clk = 1;
always #5 clk <= ~clk; // Example: 10ns clock period

reg reset;

// Instantiate the top-level design
ucsbece154b_top top (
    .clk(clk),
    .reset(reset)
);

// Probes for specific registers.
wire [31:0] reg_t0 = top.riscv.dp.rf.t0;  // t0 is x5
wire [31:0] reg_t1 = top.riscv.dp.rf.t1;  // t1 is x6
wire [31:0] reg_t2 = top.riscv.dp.rf.t2;  // t2 is x7
wire [31:0] reg_s0 = top.riscv.dp.rf.s0;  // s0 is x8
wire [31:0] reg_s1 = top.riscv.dp.rf.s1;  // s1 is x9
wire [31:0] reg_s2 = top.riscv.dp.rf.s2; // s2 is x18
wire [31:0] reg_s3 = top.riscv.dp.rf.s3; // s3 is x19
wire [31:0] reg_t3 = top.riscv.dp.rf.t3; // t3 is x28
wire [31:0] reg_t4 = top.riscv.dp.rf.t4; // t4 is x29
wire [31:0] reg_t5 = top.riscv.dp.rf.t5; // t5 is x30
wire [31:0] reg_t6 = top.riscv.dp.rf.t6; // t6 is x31


integer cycle_count = 0;
integer retired_instruction_count = 0;
integer cycles_after_completion = 0;

parameter TARGET_INSTRUCTIONS = 8; // Number of 'addi' instructions in our test program
parameter PIPELINE_DRAIN_CYCLES = 10; // Cycles to run after all target instructions have retired
parameter SIMULATION_TIMEOUT_CYCLES = 200; // Safety timeout

// Performance counters from your original testbench (will be 0 for this specific ADDI test)
integer branch_count = 0;
integer branch_miss_count = 0;
integer jump_count = 0;
integer jump_miss_count = 0;

initial begin
    $display("Begin simulation.");
    reset = 1;
    // Initialize counters explicitly
    cycle_count = 0;
    retired_instruction_count = 0;
    cycles_after_completion = 0;
    branch_count = 0;
    branch_miss_count = 0;
    jump_count = 0;
    jump_miss_count = 0;

    // Apply reset for a few cycles
    repeat (2) @(posedge clk);
    reset = 0;
    $display("Reset de-asserted at time %0t.", $time);

    // Main simulation loop
    while ( (retired_instruction_count < TARGET_INSTRUCTIONS) || (cycles_after_completion < PIPELINE_DRAIN_CYCLES) ) begin
        @(posedge clk);
        cycle_count = cycle_count + 1;

        if (!reset) begin
            // Count retired instructions from slot 1
            // Check RegWrite signal from controller and ensure Rd is not x0
            if (top.riscv.c.RegWriteW_o && top.riscv.dp.RdW_o != 5'b00000) begin
                if (retired_instruction_count < TARGET_INSTRUCTIONS) begin
                    retired_instruction_count = retired_instruction_count + 1;
                   // $display("Time %0t: Slot 1 retired instruction. Total retired: %0d", $time, retired_instruction_count);
                end
            end

            // Count retired instructions from slot 2
            if (top.riscv.c.RegWriteW2_o && top.riscv.dp.RdW2_o != 5'b00000) begin
                if (retired_instruction_count < TARGET_INSTRUCTIONS) begin // Important to check again to avoid double counting the last one
                    retired_instruction_count = retired_instruction_count + 1;
                   // $display("Time %0t: Slot 2 retired instruction. Total retired: %0d", $time, retired_instruction_count);
                end
            end

            // Branch/Jump counting (will be 0 for the ADDI test program)
            // Slot 1
            if (top.riscv.c.BranchE && !top.riscv.c.FlushE_o) begin // Check if branch is valid in Ex
                 branch_count = branch_count + 1;
                 if (top.riscv.dp.Mispredict_o) // Mispredict from datapath
                     branch_miss_count = branch_miss_count + 1;
            end
            if (top.riscv.c.JumpE && !top.riscv.c.FlushE_o) begin // Check if jump is valid in Ex
                 jump_count = jump_count + 1;
                 // A simple jump misprediction might be if PC doesn't take the jump target
                 // This depends on branch predictor's handling of unconditional jumps
            end
             // Slot 2 - Assuming similar control signals exist and are correctly named
            if (top.riscv.c.BranchE2 && !top.riscv.c.FlushE2_o) begin
                 branch_count = branch_count + 1; // Add to total branch count
                 if (top.riscv.dp.Mispredict2_o)
                     branch_miss_count = branch_miss_count + 1;
            end
            if (top.riscv.c.JumpE2 && !top.riscv.c.FlushE2_o) begin
                 jump_count = jump_count + 1; // Add to total jump count
            end

        end

        if (retired_instruction_count >= TARGET_INSTRUCTIONS) begin
            cycles_after_completion = cycles_after_completion + 1;
        end

        // Safety timeout
        if (cycle_count >= SIMULATION_TIMEOUT_CYCLES) begin
            $display("Error: Simulation timed out after %0d cycles. Retired instructions: %0d", cycle_count, retired_instruction_count);
            break; // Exit the while loop
        end
    end

    // Add a small delay for final register values to settle if needed, though usually not for synchronous designs.
    @(posedge clk);

    $display("---- PROGRAM EXECUTION COMPLETE ----");
    $display("Time: %0t", $time);
    $display("Final Register values (expected values for the 8 ADDI program):");
    $display("t0 (x5)  = %0d (expected: 1)", reg_t0);
    $display("t1 (x6)  = %0d (expected: 2)", reg_t1);
    $display("t2 (x7)  = %0d (expected: 3)", reg_t2);
    $display("t3 (x28) = %0d (expected: 4)", reg_t3);
    $display("t4 (x29) = %0d (expected: 5)", reg_t4);
    $display("t5 (x30) = %0d (expected: 6)", reg_t5);
    $display("s0 (x8)  = %0d (expected: 7)", reg_s0);
    $display("s1 (x9)  = %0d (expected: 8)", reg_s1);
    $display("s2 (x18) = %0d (expected: 0)", reg_s2); // Unused by this program
    $display("s3 (x19) = %0d (expected: 0)", reg_s3); // Unused by this program
    $display("t6 (x31) = %0d (expected: 0)", reg_t6); // Unused by this program
    $display("------------------------------------");
    $display("Performance Metrics:");
    $display("Total cycles executed:    %0d", cycle_count);
    $display("Target instructions:      %0d", TARGET_INSTRUCTIONS);
    if (TARGET_INSTRUCTIONS > 0) begin
        $display("Measured CPI:             %f", 1.0 * cycle_count / TARGET_INSTRUCTIONS);
    end else begin
        $display("Measured CPI:             N/A (0 instructions targeted)");
    end
    $display("Branch count:             %0d", branch_count);
    $display("Branch mispredictions:    %0d", branch_miss_count);
    if (branch_count > 0) begin
        $display("Branch misprediction rate: %f%%", 100.0 * branch_miss_count / branch_count);
    end else begin
        $display("Branch misprediction rate: N/A");
    end
    $display("Jump count:               %0d", jump_count);
    // $display("Jump mispredictions:    %0d", jump_miss_count); // jump_miss_count not explicitly tracked here
    // if (jump_count > 0) begin
    //     $display("Jump misprediction rate:   %f%%", 100.0 * jump_miss_count / jump_count);
    // end else begin
    //     $display("Jump misprediction rate:   N/A");
    // end
    $display("------------------------------------");

    $stop;
end

endmodule