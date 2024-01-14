`ifndef LSB
`define LSB
`include "setsize.v"

module LSB (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    output wire lsb_nxt_full,

    //mem_ctrl
    output reg mc_en,
    output reg mc_wr,//if true,it means write
    output reg [`ADDR_WID] mc_addr,
    output reg [2:0] mc_len,
    output reg [`DATA_WID] mc_w_data,
    input  wire mc_done,
    input  wire [`DATA_WID] mc_r_data,

    //issue
    input wire issue,
    input wire [`ROB_POS_WID] issue_rob_pos,
    input wire issue_is_store,
    input wire [`FUNCT3_WID] issue_funct3,
    input wire [`DATA_WID] issue_rs1_val,
    input wire [`ROB_ID_WID] issue_rs1_rob_id,
    input wire [`DATA_WID] issue_rs2_val,
    input wire [`ROB_ID_WID] issue_rs2_rob_id,
    input wire [`DATA_WID] issue_imm,

    //broadcast
    output reg result,
    output reg [`ROB_POS_WID] result_rob_pos,
    output reg [`DATA_WID] result_val,
    
    //from Reservation Station
    input wire alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [`DATA_WID] alu_result_val,
    // from Load Store Buffer
    input wire lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [`DATA_WID] lsb_result_val,

    //from rob, commit store
    input wire commit_store,
    input wire [`ROB_POS_WID] commit_rob_pos,

    //for IO
    input wire [`ROB_POS_WID] head_rob_pos
);
    integer i;

    reg [`LSB_POS_WID] head, tail;
    reg [`LSB_ID_WID] last_commit_pos;
    reg busy [`LSB_SIZE-1:0];
    reg empty;
    reg waiting;

    reg is_store [`LSB_SIZE-1:0];
    reg [`FUNCT3_WID] funct3 [`LSB_SIZE-1:0];
    reg [`ROB_ID_WID] rs1_rob_id [`LSB_SIZE-1:0];
    reg [`DATA_WID] rs1_val [`LSB_SIZE-1:0];
    reg [`ROB_ID_WID] rs2_rob_id [`LSB_SIZE-1:0];
    reg [`DATA_WID] rs2_val [`LSB_SIZE-1:0];
    reg [`DATA_WID] imm [`LSB_SIZE-1:0];
    reg [`ROB_POS_WID] rob_pos [`LSB_SIZE-1:0];
    reg committed [`LSB_SIZE-1:0];

    wire [`ADDR_WID] head_addr = rs1_val[head] + imm[head];
    wire head_is_io = head_addr[17:16] == 2'b11;
    wire prepared = !empty && rs1_rob_id[head][4] == 0 && rs2_rob_id[head][4] == 0;
    wire read_ready = !is_store[head] && !rollback && (!head_is_io || rob_pos[head] == head_rob_pos);
    wire write_ready = committed[head];
    wire exec_head = prepared && (read_ready || write_ready);

    wire pop = waiting == 1 && mc_done;
    wire [`LSB_POS_WID] nxt_head = head + pop;
    wire [`LSB_POS_WID] nxt_tail = tail + issue;
    wire nxt_empty = (nxt_head == nxt_tail && (empty || pop && !issue));
    assign lsb_nxt_full = (nxt_head == nxt_tail && !nxt_empty);

    always @(posedge clk) begin
        if (rst || (rollback && last_commit_pos == `LSB_NONE)) begin
            waiting <= 0;
            mc_en <= 0;
            head <= 0;
            tail <= 0;
            last_commit_pos <= `LSB_NONE;
            empty <= 1;
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                busy[i] <= 0;
                is_store[i] <= 0;
                funct3[i] <= 0;
                rs1_rob_id[i] <= 0;
                rs1_val[i] <= 0;
                rs2_rob_id[i] <= 0;
                rs2_val[i] <= 0;
                imm[i] <= 0;
                rob_pos[i] <= 0;
                committed[i] <= 0;
            end
        end else if (rollback) begin
            tail <= last_commit_pos + 1;//throw things behind last commit(store)
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (!committed[i]) begin
                    busy[i] <= 0;
                end
            end
            if (waiting == 1 && mc_done) begin
                busy[head] <= 0;
                committed[head] <= 0;
                waiting <= 0;
                mc_en <= 0;
                head <= head + 1'b1;
                if (last_commit_pos[`LSB_POS_WID] == head) begin//if head is last commit(store)
                    last_commit_pos <= `LSB_NONE;
                    empty <= 1;
                end
            end
        end else if (rdy) begin
            result <= 0;
            
            if(waiting == 0) begin //waiting == 0
                mc_en <= 0;
                mc_wr <= 0;
                if (exec_head) begin
                    mc_en <= 1;
                    mc_addr <= head_addr;
                    case (funct3[head])
                        `FUNCT3_SB, `FUNCT3_LB, `FUNCT3_LBU: mc_len <= 3'd1;
                        `FUNCT3_SH, `FUNCT3_LH, `FUNCT3_LHU: mc_len <= 3'd2;
                        `FUNCT3_SW, `FUNCT3_LW: mc_len <= 3'd4;
                    endcase
                    if (is_store[head]) begin
                        mc_w_data <= rs2_val[head];
                        mc_wr <= 1;
                    end
                    waiting <= 1;
                end
            end
            else if (waiting == 1 && mc_done) begin
                busy[head] <= 0;
                committed[head] <= 0;
                if (!is_store[head]) begin
                    result <= 1;
                    case (funct3[head])
                    `FUNCT3_LB: result_val <= {{24{mc_r_data[7]}}, mc_r_data[7:0]};
                    `FUNCT3_LBU: result_val <= {24'b0, mc_r_data[7:0]};
                    `FUNCT3_LH: result_val <= {{16{mc_r_data[15]}}, mc_r_data[15:0]};
                    `FUNCT3_LHU: result_val <= {16'b0, mc_r_data[15:0]};
                    `FUNCT3_LW: result_val <= mc_r_data;
                    endcase
                    result_rob_pos <= rob_pos[head];
                end
                if (last_commit_pos[`LSB_POS_WID] == head) last_commit_pos <= `LSB_NONE;
                waiting <= 0;
                mc_en  <= 0;
            end 

            //broadcast
            if (alu_result) begin
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
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
            if (lsb_result) begin
                for (i = 0; i < `LSB_SIZE; i = i + 1) begin
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

            if (issue) begin
                busy[tail] <= 1;
                is_store[tail] <= issue_is_store;
                funct3[tail] <= issue_funct3;
                rs1_rob_id[tail] <= issue_rs1_rob_id;
                rs1_val[tail] <= issue_rs1_val;
                rs2_rob_id[tail] <= issue_rs2_rob_id;
                rs2_val[tail] <= issue_rs2_val;
                imm[tail] <= issue_imm;
                rob_pos[tail] <= issue_rob_pos;
                tail <= tail + 1'b1;
            end
            //rob commit store
            if (commit_store) begin
                for (i = 0; i < `LSB_SIZE; i = i + 1)begin
                    if (busy[i] && rob_pos[i] == commit_rob_pos && !committed[i]) begin
                        committed[i] <= 1;
                        last_commit_pos <= {1'b0, i[`LSB_POS_WID]};
                    end
                end
            end

            empty <= nxt_empty;
            head <= nxt_head;
        end
    end
endmodule
`endif