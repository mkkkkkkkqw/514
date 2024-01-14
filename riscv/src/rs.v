`ifndef RS
`define RS
`include "setsize.v"
module RS (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    output reg rs_nxt_full,

    //issue
    input wire issue,
    input wire [`ROB_POS_WID] issue_rob_pos,
    input wire [`OPCODE_WID] issue_opcode,
    input wire [`FUNCT3_WID] issue_funct3,
    input wire issue_funct7,
    input wire [`DATA_WID] issue_rs1_val,
    input wire [`ROB_ID_WID] issue_rs1_rob_id,
    input wire [`DATA_WID] issue_rs2_val,
    input wire [`ROB_ID_WID] issue_rs2_rob_id,
    input wire [`DATA_WID] issue_imm,
    input wire [`ADDR_WID] issue_pc,

    //to ALU
    output reg alu_en,
    output reg [`OPCODE_WID] alu_opcode,
    output reg [`FUNCT3_WID] alu_funct3,
    output reg alu_funct7,
    output reg [`DATA_WID] alu_val1,
    output reg [`DATA_WID] alu_val2,
    output reg [`DATA_WID] alu_imm,
    output reg [`ADDR_WID] alu_pc,
    output reg [`ROB_POS_WID] alu_rob_pos,

    //broadcast
    input wire alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [`DATA_WID] alu_result_val,

    input wire lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [`DATA_WID] lsb_result_val
);
    integer i;
    reg busy [`RS_SIZE-1:0];
    reg [`ROB_POS_WID] rob_pos [`RS_SIZE-1:0];
    reg [`OPCODE_WID] opcode [`RS_SIZE-1:0];
    reg [`FUNCT3_WID] funct3 [`RS_SIZE-1:0];
    reg funct7 [`RS_SIZE-1:0];
    reg [`ROB_ID_WID] rs1_rob_id [`RS_SIZE-1:0];
    reg [`DATA_WID] rs1_val [`RS_SIZE-1:0];
    reg [`ROB_ID_WID] rs2_rob_id [`RS_SIZE-1:0];
    reg [`DATA_WID] rs2_val [`RS_SIZE-1:0];
    reg [`ADDR_WID] pc [`RS_SIZE-1:0];
    reg [`DATA_WID] imm [`RS_SIZE-1:0];

    reg ready [`RS_SIZE-1:0];
    reg [`RS_ID_WID] ready_pos, free_pos;
    reg [`RS_ID_WID] empty_count;
    always @(*) begin
        free_pos = `RS_NONE;
        ready_pos = `RS_NONE;
        empty_count = 0;
        rs_nxt_full = 1;
        for (i = 0; i < `RS_SIZE; i = i + 1) begin
            ready[i] = 0;
            if (!busy[i]) begin
                free_pos = i;
                empty_count = empty_count + 1;
            end
            if (busy[i] && rs1_rob_id[i][4] == 0 && rs2_rob_id[i][4] == 0) begin
                ready[i]  = 1;
                ready_pos = i;
            end
        end
        if(!(issue && empty_count - 1 == 0)) rs_nxt_full = 0;
    end
    always @(posedge clk) begin
        if (rst || rollback) begin
            for (i = 0; i < `RS_SIZE; i = i + 1) begin
                busy[i] <= 0;
            end
            alu_en <= 0;
        end else if (rdy) begin
            //update
            if (alu_result)begin
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (rs1_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
                        rs1_rob_id[i] <= 0;
                        rs1_val[i] <= alu_result_val;
                    end
                    if (rs2_rob_id[i] == {1'b1, alu_result_rob_pos}) begin
                        rs2_rob_id[i] <= 0;
                        rs2_val[i] <= alu_result_val;
                    end
                end
            end
            if (lsb_result)begin
                for (i = 0; i < `RS_SIZE; i = i + 1) begin
                    if (rs1_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
                        rs1_rob_id[i] <= 0;
                        rs1_val[i] <= lsb_result_val;
                    end
                    if (rs2_rob_id[i] == {1'b1, lsb_result_rob_pos}) begin
                        rs2_rob_id[i] <= 0;
                        rs2_val[i] <= lsb_result_val;
                        
                    end
                end
            end
            //decoder issues to rs
            if (issue) begin
                busy[free_pos] <= 1;
                opcode[free_pos] <= issue_opcode;
                funct3[free_pos] <= issue_funct3;
                funct7[free_pos] <= issue_funct7;
                rs1_rob_id[free_pos] <= issue_rs1_rob_id;
                rs1_val[free_pos] <= issue_rs1_val;
                rs2_rob_id[free_pos] <= issue_rs2_rob_id;
                rs2_val[free_pos] <= issue_rs2_val;
                pc[free_pos] <= issue_pc;
                imm[free_pos] <= issue_imm;
                rob_pos[free_pos] <= issue_rob_pos;
            end
            //rs issues to alu
            alu_en <= 0;
            if (ready_pos != `RS_NONE) begin
                alu_en <= 1;
                alu_opcode <= opcode[ready_pos];
                alu_funct3 <= funct3[ready_pos];
                alu_funct7 <= funct7[ready_pos];
                alu_val1 <= rs1_val[ready_pos];
                alu_val2 <= rs2_val[ready_pos];
                alu_imm <= imm[ready_pos];
                alu_pc <= pc[ready_pos];
                alu_rob_pos <= rob_pos[ready_pos];
                busy[ready_pos] <= 0;
            end
        end
    end

endmodule
`endif