`ifndef MEM_CTRL
`define MEM_CTRL
`include "setsize.v"
module MemCtrl (
    input wire clk,
    input wire rst,
    input wire rdy,

    input wire rollback,

    input  wire [ 7:0] mem_din,   // data input bus
    output reg  [ 7:0] mem_dout,  // data output bus
    output reg  [31:0] mem_a,     // address bus (only 17:0 is used)
    output reg         mem_wr,    // write/read signal (1 for write)

    input wire io_buffer_full,  // 1 if uart buffer is full

    // instruction fetch
    input  wire if_en,
    input  wire [`ADDR_WID] if_pc,
    output reg if_done,
    output wire [`IF_DATA_WID] if_data,//connected to if_data_arr

    // Load Store Buffer
    input  wire lsb_en,
    input  wire lsb_wr,
    input  wire [`ADDR_WID] lsb_addr,
    input  wire [2:0] lsb_len,
    input  wire [`DATA_WID] lsb_w_data,
    output reg lsb_done,
    output reg [`DATA_WID] lsb_r_data
);
    reg [1:0] status;//01 for if, 10 for load, 11 for store
    reg [`MEM_CTRL_LEN_WID] stage;
    reg [`MEM_CTRL_LEN_WID] len;
    reg [`ADDR_WID] store_addr;
    reg [7:0] if_data_arr[`MEM_CTRL_IF_DATA_LEN-1:0];//read from memory

    genvar x;
    generate
        for (x = 0; x < `MEM_CTRL_IF_DATA_LEN; x = x + 1)
            assign if_data[x * 8 + 7 : x * 8] = if_data_arr[x];
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            status <= 2'b0;
            if_done <= 0;
            lsb_done <= 0;
            mem_wr <= 0;
            mem_a <= 0;
        end else if (!rdy) begin
            if_done <= 0;
            lsb_done <= 0;
            mem_wr <= 0;
            mem_a <= 0;
        end else begin
            mem_wr <= 0;
            case (status)
                2'b01: begin//ifetch
                    if_data_arr[stage-1] <= mem_din;
                    if (stage + 1 == len) mem_a <= 0;
                    else mem_a <= mem_a + 1;
                    if (stage == len) begin
                        if_done <= 1;
                        mem_wr <= 0;
                        mem_a <= 0;
                        stage <= 0;
                        status <= 2'b0;
                    end else begin
                        stage <= stage + 1;
                    end
                end
                2'b10: begin//load
                    if (rollback) begin
                        lsb_done <= 0;
                        mem_wr <= 0;
                        mem_a <= 0;
                        stage <= 0;
                        status <= 2'b0;
                    end else begin
                        case (stage)
                        1: lsb_r_data[7:0] <= mem_din;
                        2: lsb_r_data[15:8] <= mem_din;
                        3: lsb_r_data[23:16] <= mem_din;
                        4: lsb_r_data[31:24] <= mem_din;
                        endcase
                        if (stage + 1 == len) mem_a <= 0;
                        else mem_a <= mem_a + 1;
                        if (stage == len) begin
                            lsb_done <= 1;
                            mem_wr <= 0;
                            mem_a <= 0;
                            stage <= 0;
                            status <= 2'b0;
                        end else begin
                            stage <= stage + 1;
                        end
                    end
                end
                2'b11: begin//store
                    if (store_addr[17:16] != 2'b11 || !io_buffer_full) begin
                        mem_wr <= 1;
                        case (stage)
                        0: mem_dout <= lsb_w_data[7:0];
                        1: mem_dout <= lsb_w_data[15:8];
                        2: mem_dout <= lsb_w_data[23:16];
                        3: mem_dout <= lsb_w_data[31:24];
                        endcase
                        if (stage == 0) mem_a <= store_addr;
                        else mem_a <= mem_a + 1;
                        if (stage == len) begin
                            lsb_done <= 1;
                            mem_wr <= 0;
                            mem_a <= 0;
                            stage <= 0;
                            status <= 2'b0;
                        end else begin
                            stage <= stage + 1;
                        end
                    end
                end
                2'b0: begin//idle
                    if (if_done || lsb_done) begin
                        if_done <= 0;
                        lsb_done <= 0;
                    end else if (!rollback) begin
                        if (lsb_en) begin
                            if (lsb_wr) begin
                                status <= 2'b11;
                                store_addr <= lsb_addr;
                            end else begin
                                status <= 2'b10;
                                mem_a <= lsb_addr;
                                lsb_r_data <= 0;
                            end
                            stage <= 0;
                            len <= {4'b0, lsb_len};
                        end else if (if_en) begin
                            status <= 2'b01;
                            mem_a <= if_pc;
                            stage <= 0;
                            len <= `MEM_CTRL_IF_DATA_LEN;
                        end
                    end
                end
            endcase
        end
    end
endmodule
`endif