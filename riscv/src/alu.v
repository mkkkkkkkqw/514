`ifndef ALU
`define ALU
`include "setsize.v"
module ALU (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    //from RS
    input wire alu_en,
    input wire [`ROB_POS_WID] rob_pos,
    input wire [`OPCODE_WID] opcode,
    input wire [`FUNCT3_WID] funct3,
    input wire funct7,
    input wire [`DATA_WID] val1,
    input wire [`DATA_WID] val2,
    input wire [`DATA_WID] imm,
    input wire [`ADDR_WID] pc,

    //broadcast
    output reg result,
    output reg [`ROB_POS_WID] result_rob_pos,
    output reg [`DATA_WID] result_val,
    output reg result_jump,
    output reg [`ADDR_WID] result_pc
);

    wire [`DATA_WID] num1 = val1;
    wire [`DATA_WID] num2 = opcode == `OPCODE_CALCU ? val2 : imm;
    reg [`DATA_WID] ans;
    //caculate in combinational logic
    always @(*) begin
        case (funct3)
        `FUNCT3_ADD:
            if (opcode == `OPCODE_CALCU && funct7) ans = num1 - num2;
            else ans = num1 + num2;
        `FUNCT3_XOR: ans = num1 ^ num2;
        `FUNCT3_OR: ans = num1 | num2;
        `FUNCT3_AND: ans = num1 & num2;
        `FUNCT3_SLL: ans = num1 << num2;
        `FUNCT3_SRL:
            if (funct7) ans = $signed(num1) >> num2[5:0];
            else ans = num1 >> num2[5:0];
        `FUNCT3_SLT: ans = ($signed(num1) < $signed(num2));
        `FUNCT3_SLTU: ans = (num1 < num2);
        endcase
    end

    reg jump;
    always @(*) begin
        case (funct3)
        `FUNCT3_BEQ: jump = (val1 == val2);
        `FUNCT3_BNE: jump = (val1 != val2);
        `FUNCT3_BLT: jump = ($signed(val1) < $signed(val2));
        `FUNCT3_BGE: jump = ($signed(val1) >= $signed(val2));
        `FUNCT3_BLTU: jump = (val1 < val2);
        `FUNCT3_BGEU: jump = (val1 >= val2);
        default: jump = 0;
        endcase
    end

    always @(posedge clk) begin
        if (rst || rollback) begin
            result <= 0;
            result_rob_pos <= 0;
            result_val <= 0;
            result_jump <= 0;
            result_pc <= 0;
        end
        else if (rdy)begin
            result <= 0;
            if (alu_en) begin
                result <= 1;
                result_rob_pos <= rob_pos;
                result_jump <= 0;
                case (opcode)
                `OPCODE_CALCU, `OPCODE_CALCUI: result_val <= ans;
                `OPCODE_BR:
                    if (jump) begin
                        result_jump <= 1;
                        result_pc <= pc + imm;
                    end else begin
                        result_pc <= pc + 4;
                    end
                `OPCODE_JAL: begin
                    result_jump <= 1;
                    result_val <= pc + 4;
                    result_pc <= pc + imm;
                end
                `OPCODE_JALR: begin
                    result_jump <= 1;
                    result_val <= pc + 4;
                    result_pc <= val1 + imm;
                end
                `OPCODE_LUI: result_val <= imm;
                `OPCODE_AUIPC: result_val <= pc + imm;
                endcase
            end
        end
    end
endmodule
`endif