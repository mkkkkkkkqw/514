`ifndef REGFILE
`define REGFILE
`include "setsize.v"
module RegFile (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    //query from decoder
    input  wire [`REG_POS_WID] rs1,
    output reg [`DATA_WID] val1,
    output reg [`ROB_ID_WID] rob_id1,
    input  wire [`REG_POS_WID] rs2,
    output reg [`DATA_WID] val2,
    output reg [`ROB_ID_WID] rob_id2,

    //decoder issue instruction
    input wire issue,
    input wire [`REG_POS_WID] issue_rd,
    input wire [`ROB_POS_WID] issue_rob_pos,

    //ROB commit
    input wire commit,
    input wire [`REG_POS_WID] commit_rd,
    input wire [`DATA_WID] commit_val,
    input wire [`ROB_POS_WID] commit_rob_pos
);
    integer i;
    reg [`DATA_WID] val[`REG_SIZE-1:0];
    reg [`ROB_ID_WID] rob_id[`REG_SIZE-1:0];

    wire real_commit = commit && commit_rd != 0;
    wire is_latest_commit = rob_id[commit_rd] == {1'b1, commit_rob_pos};
    
    always @(*) begin
        if (real_commit && rs1 == commit_rd && is_latest_commit) begin
            rob_id1 = 5'b0;
            val1 = commit_val;
        end else begin
            rob_id1 = rob_id[rs1];
            val1 = val[rs1];
        end

        if (real_commit && rs2 == commit_rd && is_latest_commit) begin
            rob_id2 = 5'b0;
            val2 = commit_val;
        end else begin
            rob_id2 = rob_id[rs2];
            val2 = val[rs2];
        end
    end

    
    always @(posedge clk) begin
        if (rst) begin
        for (i = 0; i < 32; i = i + 1) begin
            val[i] <= 32'b0;
            rob_id[i] <= 5'b0;
        end
        end else if (rdy) begin
            if (real_commit) begin
                val[commit_rd] <= commit_val;
                if (is_latest_commit) rob_id[commit_rd] <= 5'b0;
            end
            if (issue && issue_rd != 0) begin
                rob_id[issue_rd] <= {1'b1, issue_rob_pos};
            end

            if (rollback) begin
                for (i = 0; i < 32; i = i + 1) rob_id[i] <= 5'b0;
            end
        end
    end
endmodule
`endif