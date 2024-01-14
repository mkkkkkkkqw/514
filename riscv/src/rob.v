`ifndef ROB
`define ROB
`include "setsize.v"
module ROB (
    input wire clk,
    input wire rst,
    input wire rdy,

    output wire rob_nxt_full,
    output reg rollback,

    //set pc to ifetch
    output reg if_set_pc_en,
    output reg [`ADDR_WID] if_set_pc,

    //issue from other modules
    input wire issue,
    input wire [`REG_POS_WID] issue_rd,
    input wire [`OPCODE_WID] issue_opcode,
    input wire [`ADDR_WID] issue_pc,
    input wire issue_pred_jump,
    input wire issue_is_ready,

    //for IO
    output wire [`ROB_POS_WID] head_rob_pos,

    //commit
    output reg [`ROB_POS_WID] commit_rob_pos,
    //to regfile
    output reg reg_write,
    output reg [`REG_POS_WID] reg_rd,
    output reg [`DATA_WID] reg_val,
    //to lsb
    output reg lsb_store,

    // update predictor
    output reg commit_br,
    output reg commit_br_jump,
    output reg [`ADDR_WID] commit_br_pc,

    //broadcast
    input wire alu_result,
    input wire [`ROB_POS_WID] alu_result_rob_pos,
    input wire [`DATA_WID] alu_result_val,
    input wire alu_result_jump,
    input wire [`ADDR_WID] alu_result_pc,

    input wire lsb_result,
    input wire [`ROB_POS_WID] lsb_result_rob_pos,
    input wire [`DATA_WID] lsb_result_val,

    //query from decoder
    input  wire [`ROB_POS_WID] rs1_pos,
    output wire rs1_ready,
    output wire [`DATA_WID] rs1_val,
    input  wire [`ROB_POS_WID] rs2_pos,
    output wire rs2_ready,
    output wire [`DATA_WID] rs2_val,
    output wire [`ROB_POS_WID] nxt_rob_pos
);

    reg ready [`ROB_SIZE-1:0];
    reg [`REG_POS_WID] rd [`ROB_SIZE-1:0];
    reg [`DATA_WID] val [`ROB_SIZE-1:0];
    reg [`ADDR_WID] pc [`ROB_SIZE-1:0];
    reg [`OPCODE_WID] opcode [`ROB_SIZE-1:0];
    reg pred_jump [`ROB_SIZE-1:0];
    reg res_jump [`ROB_SIZE-1:0];
    reg [`ADDR_WID] res_pc [`ROB_SIZE-1:0];

    reg [`ROB_POS_WID] head, tail;
    reg empty;
    wire commit = !empty && ready[head];
    wire [`ROB_POS_WID] nxt_head = head + commit;
    wire [`ROB_POS_WID] nxt_tail = tail + issue;
    assign nxt_rob_pos = tail;
    wire nxt_empty = (nxt_head == nxt_tail && (empty || commit && !issue));
    assign rob_nxt_full = (nxt_head == nxt_tail && !nxt_empty);

    assign head_rob_pos = head;

    assign rs1_ready = ready[rs1_pos];
    assign rs1_val = val[rs1_pos];
    assign rs2_ready = ready[rs2_pos];
    assign rs2_val = val[rs2_pos];

    integer i;
    always @(posedge clk) begin
        if (rst || rollback) begin
            head <= 0;
            tail <= 0;
            empty <= 1;
            rollback <= 0;
            if_set_pc_en <= 0;
            if_set_pc <= 0;
            for (i = 0; i < `ROB_SIZE; i = i + 1) begin
                ready[i] <= 0;
                rd[i] <= 0;
                val[i] <= 0;
                pc[i] <= 0;
                opcode[i] <= 0;
                pred_jump[i] <= 0;
                res_jump[i] <= 0;
                res_pc[i] <= 0;
            end
            reg_write <= 0;
            lsb_store <= 0;
            commit_br <= 0;
        end else if (rdy) begin

            empty <= nxt_empty;
            if (issue) begin
                rd[tail] <= issue_rd;
                opcode[tail] <= issue_opcode;
                pc[tail] <= issue_pc;
                pred_jump[tail] <= issue_pred_jump;
                ready[tail] <= issue_is_ready;
                tail <= tail + 1'b1;
            end

            //update
            if (alu_result) begin
                val[alu_result_rob_pos] <= alu_result_val;
                ready[alu_result_rob_pos] <= 1;
                res_jump[alu_result_rob_pos] <= alu_result_jump;
                res_pc[alu_result_rob_pos] <= alu_result_pc;
            end
            if (lsb_result) begin
                val[lsb_result_rob_pos] <= lsb_result_val;
                ready[lsb_result_rob_pos] <= 1;
            end

            //commit
            reg_write <= 0;
            lsb_store <= 0;
            commit_br <= 0;
            reg_write <= 0;
            if (commit) begin
                commit_rob_pos <= head;
                if (opcode[head] == `OPCODE_S) begin
                    lsb_store <= 1;
                end else if (opcode[head] != `OPCODE_BR) begin
                    reg_write <= 1;
                    reg_rd <= rd[head];
                    reg_val <= val[head];
                end
                if (opcode[head] == `OPCODE_BR) begin
                    commit_br <= 1;
                    commit_br_jump <= res_jump[head];
                    commit_br_pc <= pc[head];
                    if (pred_jump[head] != res_jump[head]) begin
                        rollback <= 1;
                        if_set_pc_en <= 1;
                        if_set_pc <= res_pc[head];
                    end
                end
                if (opcode[head] == `OPCODE_JALR) begin
                    if (pred_jump[head] != res_jump[head]) begin
                        rollback <= 1;
                        if_set_pc_en <= 1;
                        if_set_pc <= res_pc[head];
                    end
                end
                head <= head + 1'b1;
            end
        end
    end
endmodule
`endif