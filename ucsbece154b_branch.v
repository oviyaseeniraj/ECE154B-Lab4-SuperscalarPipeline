// DEBUG-ENHANCED ucsbece154b_branch.v
module ucsbece154b_branch #(
    parameter NUM_BTB_ENTRIES = 32,
    parameter NUM_GHR_BITS    = 5
) (
    input               clk, 
    input               reset_i,
    input        [31:0] pc_i,
    input  [$clog2(NUM_BTB_ENTRIES)-1:0] BTBwriteaddress_i,
    input        [31:0] BTBwritedata_i,   
    output reg   [31:0] BTBtarget_o,           
    input               BTB_we, 
    output reg          BranchTaken_o,
    input         [6:0] op_i, 
    input               PHTincrement_i, 
    input               GHRreset_i,
    input               PHTwe_i,
    input               GHRwe_i,
    input    [NUM_GHR_BITS-1:0]  PHTwriteaddress_i,
    output   [NUM_GHR_BITS-1:0]  PHTreadaddress_o
);

`include "ucsbece154b_defines.vh"

localparam BTB_IDX_BITS = $clog2(NUM_BTB_ENTRIES);

reg [31:0] BTB_target [0:NUM_BTB_ENTRIES-1];
reg [31:0] BTB_tag    [0:NUM_BTB_ENTRIES-1];
reg        BTB_j_flag [0:NUM_BTB_ENTRIES-1];
reg        BTB_b_flag [0:NUM_BTB_ENTRIES-1];
reg        BTB_valid  [0:NUM_BTB_ENTRIES-1];

reg [NUM_GHR_BITS-1:0] GHR;
reg [1:0] PHT [0:(1 << NUM_GHR_BITS)-1];

wire [BTB_IDX_BITS-1:0] btb_index = pc_i[BTB_IDX_BITS+1:2];
wire [31:0] btb_tag_in = pc_i;
reg tag_match = 1'b0;
reg btb_entry_valid = 1'b0;

reg [31:0] tag_d, tag_e;
reg tag_match_d = 1'b0;
reg tag_match_e = 1'b0;
reg [6:0] op_e = 7'b0;

integer i;
always @ (posedge clk) begin
    if (reset_i) begin
        for (i = 0; i < NUM_BTB_ENTRIES; i = i + 1) begin
            BTB_target[i] <= 32'b0;
            BTB_tag[i]    <= 32'b0;
            BTB_j_flag[i] <= 1'b0;
            BTB_b_flag[i] <= 1'b0;
            BTB_valid[i]  <= 1'b0;
        end

        // Initialize PHT to strongly not taken
         for (i = 0; i < (1 << NUM_GHR_BITS); i = i + 1) begin
             PHT[i] <= 2'b01;
         end
         
         GHR <= {NUM_GHR_BITS{1'b0}};

    end
end

always @(posedge clk) begin
    tag_d <= btb_tag_in;
    tag_e <= tag_d;
    tag_match_d <= tag_match;
    tag_match_e <= tag_match_d;
    op_e <= op_i;
end

always @(*) begin
    if (BTB_valid[btb_index]) begin
        tag_match = (btb_tag_in == BTB_tag[btb_index]);
    end else begin
        tag_match = 1'b0;
    end
end


always @(posedge clk) begin
    /**
    $display("[BTB INDEX] index=%0d", btb_index);
    $display("[BTB TAG FROM PC] tag=%h", btb_tag_in);
    $display("[BTB TAG FROM TABLE] tag=%h", BTB_tag[btb_index]);
    $display("[BTB VALID] valid=%b", BTB_valid[btb_index]);
    
    $display("[BTB TAG E MATCH] match_e=%b", tag_match_e);
    $display("[BTB TAG DECODE MATCH] match=%b", tag_match);
    */
    // $display("[BTB INDEX EXECUTE] index=%0d", BTBwriteaddress_i);
    // $display("[BTB TAG EXEC PC] tag=%h", tag_e);
    // $display("[BTB EXEC TAG FROM TABLE] tag=%h", BTB_tag[BTBwriteaddress_i]);
    // $display("[BTB EXEC VALID] valid=%b", BTB_valid[BTBwriteaddress_i]);

    if (BTB_we && (!tag_match_e || !BTB_valid[BTBwriteaddress_i])) begin
        BTB_target[BTBwriteaddress_i] <= BTBwritedata_i;
        BTB_tag[BTBwriteaddress_i]    <= tag_e;
        BTB_j_flag[BTBwriteaddress_i] <= (op_e == instr_jal_op || op_e == instr_jalr_op);
        BTB_b_flag[BTBwriteaddress_i] <= (op_e == instr_branch_op);
        BTB_valid[BTBwriteaddress_i]  <= 1'b1;

        /**
        $display("[BTB WRITE] index=%0d PC=%h target=%h op=%b j=%b b=%b", 
                 BTBwriteaddress_i, tag_e, BTBwritedata_i, op_e, 
                 (op_e == instr_jal_op || op_e == instr_jalr_op), 
                 (op_e == instr_branch_op));
        
        $display("[BTB ENTRY] index=%0d tag=%h target=%h j=%b b=%b valid=%b",
                BTBwriteaddress_i, BTB_tag[BTBwriteaddress_i], BTB_target[BTBwriteaddress_i], 
                BTB_j_flag[BTBwriteaddress_i], BTB_b_flag[BTBwriteaddress_i], BTB_valid[BTBwriteaddress_i]);
        */

    end
    
end


wire [NUM_GHR_BITS-1:0] pc_xor_ghr = pc_i[NUM_GHR_BITS+1:2] ^ GHR;
assign PHTreadaddress_o = pc_xor_ghr;
wire predict_taken = PHT[pc_xor_ghr][1];

wire btb_hit = BTB_valid[btb_index] && (btb_tag_in == BTB_tag[btb_index]);
assign btb_b = btb_hit ? BTB_b_flag[btb_index] : 1'b0;
assign btb_j = btb_hit ? BTB_j_flag[btb_index] : 1'b0;

assign btb_valid = BTB_valid[btb_index];

always @(*) begin
    BTBtarget_o = 32'b0;
    BranchTaken_o = 1'b0;

    if (BTB_valid[btb_index] && tag_match) begin
        /**
        $display("[BJ] pc=%h b=%b j=%b", 
            BTB_tag[btb_index], BTB_b_flag[btb_index], BTB_j_flag[btb_index]);
        */
        if (BTB_j_flag[btb_index]) begin
            // Jumps are always taken
            BTBtarget_o = BTB_target[btb_index];
            BranchTaken_o = 1'b1;
        end else if (BTB_b_flag[btb_index]) begin
            // Branch depends on PHT prediction
            BTBtarget_o = BTB_target[btb_index];
            BranchTaken_o = predict_taken;  // MSB of counter
            /**
            $display("[BRANCHTAKEN] pc=%h addr=%0d PHTval=%b BranchTaken_o=%b", 
                 pc_i, pc_xor_ghr, PHT[pc_xor_ghr][1], BranchTaken_o);
            */
        end
    end else begin
        // No valid entry in BTB, default to not taken
        BTBtarget_o = pc_i + 4;
        BranchTaken_o = 1'b0;
    end
end


always @(posedge clk) begin
    if (PHTwe_i) begin
        if (PHTincrement_i && PHT[PHTwriteaddress_i] < 2'b11)
            PHT[PHTwriteaddress_i] <= PHT[PHTwriteaddress_i] + 1;
        else if (!PHTincrement_i && PHT[PHTwriteaddress_i] > 2'b00)
            PHT[PHTwriteaddress_i] <= PHT[PHTwriteaddress_i] - 1;

        /**
        $display("[PHT UPDATE] addr=%0d inc=%b new_value=%b", 
                 PHTwriteaddress_i, PHTincrement_i, PHT[PHTwriteaddress_i]);
        */
    end
end

always @(posedge clk) begin
    if (reset_i || GHRreset_i) begin
        $display("[GHR RESET] pc=%h, btb_hit=%b", pc_i, btb_hit);
        GHR <= {NUM_GHR_BITS{1'b0}};
    end else if (GHRwe_i) begin
        //GHR <= {GHR[NUM_GHR_BITS-2:0], BranchTaken_o};  // Shift in latest result
        $display("[GHR UPDATE] pc=%h old=%b new=%b", 
                 pc_i, GHR, {BranchTaken_o, GHR[NUM_GHR_BITS-1:1]});
        GHR <= {BranchTaken_o, GHR[NUM_GHR_BITS-1:1]};
        //GHR <= {GHR[NUM_GHR_BITS-2:0], PHTincrement_i};
    end
end

endmodule