`ifndef DECODER
`define DECODER
`include "setsize.v"

module Decoder ( //totally combinational
    input wire rst,
    input wire rdy,

    input wire rollback,

    //issue
    output reg issue,
    output reg [`ROB_POS_WID] rob_pos,
    output reg [`OPCODE_WID] opcode,
    output reg is_store,
    output reg [`FUNCT3_WID] funct3,
    output reg funct7,
    output reg [`DATA_WID] rs1_val,
    output reg [`ROB_ID_WID] rs1_rob_id,
    output reg [`DATA_WID] rs2_val,
    output reg [`ROB_ID_WID] rs2_rob_id,
    output reg [`DATA_WID] imm,
    output reg [`REG_POS_WID] rd,
    output reg [`ADDR_WID] pc,
    output reg pred_jump,
    output reg is_ready,

    //from ifetch
    input wire inst_rdy,
    input wire [`INST_WID] inst,
    input wire [`ADDR_WID] inst_pc,
    input wire inst_pred_jump,

    //from regfile
    output wire [`REG_POS_WID] reg_rs1,
    input  wire [`DATA_WID] reg_rs1_val,
    input  wire [`ROB_ID_WID] reg_rs1_rob_id,
    output wire [`REG_POS_WID] reg_rs2,
    input  wire [`DATA_WID] reg_rs2_val,
    input  wire [`ROB_ID_WID] reg_rs2_rob_id,

    //from rob
    output wire [`ROB_POS_WID] rob_rs1_pos,
    input  wire rob_rs1_ready,
    input  wire [`DATA_WID] rob_rs1_val,
    output wire [`ROB_POS_WID] rob_rs2_pos,
    input  wire rob_rs2_ready,
    input  wire [`DATA_WID] rob_rs2_val,

    output reg rs_en,
    output reg lsb_en,

    input wire [`ROB_POS_WID] nxt_rob_pos,

    //broadcast
    //from rs
    input wire alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [`DATA_WID] alu_result_val,
    //from lsb
    input wire lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [`DATA_WID] lsb_result_val
);

    assign reg_rs1 = inst[`RS1_RANGE];
    assign reg_rs2 = inst[`RS2_RANGE];
    assign rob_rs1_pos = reg_rs1_rob_id[`ROB_POS_WID];
    assign rob_rs2_pos = reg_rs2_rob_id[`ROB_POS_WID];

    always @(*) begin
        opcode = inst[`OPCODE_RANGE];
        funct3 = inst[`FUNCT3_RANGE];
        funct7 = inst[30];
        rd = inst[`RD_RANGE];
        imm = 0;
        pc = inst_pc;
        pred_jump = inst_pred_jump;
        rob_pos = nxt_rob_pos;
        issue = 0;
        lsb_en = 0;
        rs_en = 0;
        is_ready = 0;
        rs1_val = 0;
        rs1_rob_id = 0;
        rs2_val = 0;
        rs2_rob_id = 0;

        if (!rst && !rollback && rdy && inst_rdy) begin
            issue = 1;

            rs1_rob_id = 0;
            if (reg_rs1_rob_id[4] == 0) rs1_val = reg_rs1_val;
            else if (rob_rs1_ready) rs1_val = rob_rs1_val;
            else if (alu_result && rob_rs1_pos == alu_result_rob_pos) rs1_val = alu_result_val;
            else if (lsb_result && rob_rs1_pos == lsb_result_rob_pos) rs1_val = lsb_result_val;
            else begin
                rs1_val = 0;
                rs1_rob_id = reg_rs1_rob_id;
            end
            rs2_rob_id = 0;
            if (reg_rs2_rob_id[4] == 0)rs2_val = reg_rs2_val;
            else if (rob_rs2_ready)rs2_val = rob_rs2_val;
            else if (alu_result && rob_rs2_pos == alu_result_rob_pos)rs2_val = alu_result_val;
            else if (lsb_result && rob_rs2_pos == lsb_result_rob_pos)rs2_val = lsb_result_val;
            else begin
                rs2_val = 0;
                rs2_rob_id = reg_rs2_rob_id;
            end

            is_store = 0;
            //if set zero, then it is unused.
            case (inst[`OPCODE_RANGE])
                `OPCODE_L: begin
                    lsb_en = 1;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{21{inst[31]}}, inst[30:20]};
                end
                `OPCODE_S: begin
                    lsb_en = 1;
                    is_ready = 1;//If store,then set ready so that it can be committed directly.
                    rd = 0;
                    imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
                    is_store = 1;
                end
                `OPCODE_CALCU: rs_en = 1;
                `OPCODE_CALCUI: begin
                    rs_en = 1;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{21{inst[31]}}, inst[30:20]};
                end
                `OPCODE_JAL: begin
                    rs_en = 1;
                    rs1_rob_id = 0;
                    rs1_val = 0;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
                end
                `OPCODE_JALR: begin
                    rs_en = 1;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {{21{inst[31]}}, inst[30:20]};
                end
                `OPCODE_BR: begin
                    rs_en = 1;
                    rd = 0;
                    imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
                end
                `OPCODE_LUI, `OPCODE_AUIPC: begin
                    rs_en = 1;
                    rs1_rob_id = 0;
                    rs1_val = 0;
                    rs2_rob_id = 0;
                    rs2_val = 0;
                    imm = {inst[31:12], 12'b0};
                end
            endcase
        end
    end

endmodule
`endif