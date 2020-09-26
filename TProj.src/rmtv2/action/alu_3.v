/****************************************************/
//	Module name: alu_3
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/25
//	Function outline: 3rd type ALU (metadata modification) in RMT
/****************************************************/
`timescale 1ns / 1ps
module alu_3 #(
    parameter OUT_LEN = 16,
    parameter STAGE = 0,
    parameter ACTION_LEN = 25,
    parameter META_LEN = 256,
    parameter COMP_LEN = 100
)(
    input clk,
    input rst_n,
    //the input data shall be metadata & com_ins
    input [META_LEN+COMP_LEN-1:0]       comp_meta_data_in,
    input                               comp_meta_data_valid_in,
    input [ACT_LEN-1:0]                 action_in,
    input                               action_valid_in,

    //output is the modified metadata plus comp_ins
    output reg [META_LEN+COMP_LEN-1:0]  comp_meta_data_out,
    output reg                          comp_meta_data_valid_out     
);

/********intermediate variables declared here********/
integer i;

reg [META_LEN+COMP_LEN-1:0]  comp_meta_data_delay;
reg                          comp_meta_data_valid_delay;

/********intermediate variables declared here********/

//need delay for one cycle before the result pushed out
/*
action format:
    [24:20]: opcode;
    [19:12]: dst_port;
    [11]:    discard_flag;
    [10:5]:  next_table_id;
    [4:0]:   reserverd_bit;
*/
/*
metadata fields that are related:
    TODO: next table id is not supported yet.
    [255:250]: next_table_id;
    [249:129]: reservered for other use;
    [128]:     discard_field;
    [127:0]:   copied from NetFPGA's md;
    
*/
always @(posedge clk) begin
    comp_meta_data_out <= comp_meta_data_delay;
    comp_meta_data_valid_out <= comp_meta_data_valid_delay;    
end

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        comp_meta_data_out <= 0;
        comp_meta_data_valid_out <= 1'b0;
        comp_meta_data_delay <= 0;
        comp_meta_data_valid_delay <= 1'b0;
    end

    else begin
        if(action_valid_in) begin
            comp_meta_data_valid_delay <= comp_meta_data_valid_in;
            case(comp_meta_data_in[24:20])
                4'b1100: begin
                    comp_meta_data_delay[355:32] <= {action_in[10:5],comp_meta_data_in[349:32]};
                    comp_meta_data_delay[31:24]  <= action_in[19:12];
                    comp_meta_data_delay[23:0]   <= comp_meta_data_in[23:0];
                end
                4'b1101: begin
                    comp_meta_data_delay[355:129] <= {action_in[10:5],comp_meta_data_in[349:129]};
                    comp_meta_data_delay[128] <= action_in[128];
                    comp_meta_data_delay[127:0] <= comp_meta_data_in[127:0];
                end
                default: begin
                    comp_meta_data_delay <= comp_meta_data_in;
                end
            endcase
        end
    end
end

endmodule