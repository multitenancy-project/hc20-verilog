////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version: 0.1
//Filename: prior_sel.v
//Target Device: 
//Dscription: 
//  1)
//  2)
//
//Author : 
//Revision List:
//	rn2:	date:	modifier:	description:
//	rn2:	date:	modifier:	description:
//
module prior_sel(
    input  wire       clk,//add module's work clk domin
    input  wire       rst_n,
                      
    input  wire       sel_a_valid,
    input  wire [7:0] sel_a_prior,
    input  wire [7:0] sel_a_index,
                      
    input  wire       sel_b_valid,
    input  wire [7:0] sel_b_prior,
    input  wire [7:0] sel_b_index,
                      
    output reg        result_valid,
    output reg  [7:0] result_prior,
    output reg  [7:0] result_index 
);

//***************************************************
//                Select Process
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        result_valid <= 1'b0;
        result_prior <= 8'b0;
        result_index <= 8'b0;
    end
    else begin
        case({sel_a_valid,sel_b_valid})
            2'b00: begin
                result_valid <= 1'b0;
                result_prior <= result_prior;
                result_index <= result_index;
            end
            
            2'b01: begin
                result_valid <= 1'b1;
                result_prior <= sel_b_prior;
                result_index <= sel_b_index;
            end
            
            2'b10: begin
                result_valid <= 1'b1;
                result_prior <= sel_a_prior;
                result_index <= sel_a_index;
            end
            
            2'b11: begin
                result_valid <= 1'b1;
                if(sel_a_prior > sel_b_prior) begin
                    result_prior <= sel_a_prior;
                    result_index <= sel_a_index;
                end
                else begin
                    result_prior <= sel_b_prior;
                    result_index <= sel_b_index;
                end
            end
        endcase
    end
end

endmodule
/*
prior_sel prior_sel_inst(
    .clk(),//add module's work clk domin
    .rst_n(),

    .sel_a_valid(),
    .sel_a_prior(),
    .sel_a_index(),

    .sel_b_valid(),
    .sel_b_prior(),
    .sel_b_index(),

    .result_valid(),
    .result_prior(),
    .result_index()
);
*/