/****************************************************/
//	Module name: alu_1
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/23
//	Function outline: 1st type ALU (no load/store) module in RMT
/****************************************************/

`timescale 1ns / 1ps

module alu_1 #(
    parameter OUT_LEN = 16,
    parameter STAGE = 0,
    parameter ACTION_LEN = 25,
    parameter DATA_WIDTH = 48  //data width of the ALU
)
(
    input clk,
    input rst_n,

    //input from sub_action
    input [ACTION_LEN-1:0]            action_in;
    input                             action_valid;
    input [DATA_WIDTH-1:0]            operand_1_in;
    input [DATA_WIDTH-1:0]            operand_2_in;

    //output to form PHV
    output reg [DATA_WIDTH-1:0]       container_out;
    output reg                        container_out_valid;

);

/********intermediate variables declared here********/
integer i;

localparam width_6B = 48;
localparam width_4B = 32;
localparam width_2B = 16;

reg [DATA_WIDTH-1:0]  container_out_delay;
reg                   container_out_valid_delay;

/********intermediate variables declared here********/

always @(posedge clk) begin
    container_out <= container_out_delay;
    container_out_valid <= container_out_valid_delay;
end

/*
8 operations to support:

1,2. add/sub:   0001/0010
              extract 2 operands from pkt header, add(sub) and write back.

3,4. addi/subi: 0011/0100
              extract op1 from pkt header, op2 from action, add(sub) and write back.
*/

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        container_out_delay <= 0;
        container_out <= 0;
    end

    else begin
        if(action_valid) begin
            case(action_in[24:21])
                4'b0001, 4'b1001: begin:
                    container_out_delay <= operand_1_in + operand_2_in;
                    container_out_valid_delay <= action_valid;
                end
                4'b0010, 4'b1010: begin:
                    container_out_delay <= operand_1_in - operand_2_in;
                    container_out_valid_delay <= action_valid;
                end
            endcase
        end
    end
end

endmodule