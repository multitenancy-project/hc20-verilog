////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version: 0.1
//Filename: tree_8prior_sel.v
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
module tree_8prior_sel (
    input  wire           clk,//add module's work clk domin
    input  wire           rst_n,
                         
    input  wire [1*8-1:0] sel_valid,
    input  wire [8*8-1:0] sel_prior,
    input  wire [8*8-1:0] sel_index,
    
    output wire           result_valid,
    output wire [7:0]     result_prior,
    output wire [7:0]     result_index 
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
wire [1*4-1:0] branch_1_valid;
wire [8*4-1:0] branch_1_prior;
wire [8*4-1:0] branch_1_index;

wire [1*2-1:0] branch_2_valid;
wire [8*2-1:0] branch_2_prior;
wire [8*2-1:0] branch_2_index;

//***************************************************
//                Tree Branch 1
//***************************************************
generate 
    genvar i;
    for(i=0; i<4; i=i+1) begin : Prior_1_Branch
        prior_sel prior_1_branch_inst(
            .clk(clk),//add module's work clk domin
            .rst_n(rst_n),

            .sel_a_valid(sel_valid[i]),
            .sel_a_prior(sel_prior[8*i+7:8*i]),
            .sel_a_index(sel_index[8*i+7:8*i]),

            .sel_b_valid(sel_valid[i+4]),
            .sel_b_prior(sel_prior[8*(i+4)+7:8*(i+4)]),
            .sel_b_index(sel_index[8*(i+4)+7:8*(i+4)]),
            
            .result_valid(branch_1_valid[i]),
            .result_prior(branch_1_prior[8*i+7:8*i]),
            .result_index(branch_1_index[8*i+7:8*i])
        );
    end
endgenerate

//***************************************************
//                Tree Branch 2
//***************************************************
generate 
    genvar j;
    for(j=0; j<2; j=j+1) begin : prior_2_Branch
        prior_sel prior_2_branch_inst(
            .clk(clk),//add module's work clk domjn
            .rst_n(rst_n),

            .sel_a_valid(branch_1_valid[j]),
            .sel_a_prior(branch_1_prior[8*j+7:8*j]),
            .sel_a_index(branch_1_index[8*j+7:8*j]),

            .sel_b_valid(branch_1_valid[j+2]),
            .sel_b_prior(branch_1_prior[8*(j+2)+7:8*(j+2)]),
            .sel_b_index(branch_1_index[8*(j+2)+7:8*(j+2)]),
            
            .result_valid(branch_2_valid[j]),
            .result_prior(branch_2_prior[8*j+7:8*j]),
            .result_index(branch_2_index[8*j+7:8*j])
        );
    end
endgenerate

//***************************************************
//                Tree Branch end
//***************************************************
prior_sel prior_end_branch_inst(
    .clk(clk),//add module's work clk domin
    .rst_n(rst_n),

    .sel_a_valid(branch_2_valid[0]),
    .sel_a_prior(branch_2_prior[8*0+7:8*0]),
    .sel_a_index(branch_2_index[8*0+7:8*0]),

    .sel_b_valid(branch_2_valid[1]),
    .sel_b_prior(branch_2_prior[8*1+7:8*1]),
    .sel_b_index(branch_2_index[8*1+7:8*1]),

    .result_valid(result_valid),
    .result_prior(result_prior),
    .result_index(result_index)
);

endmodule
/*
tree_8prior_sel tree_8prior_sel_inst(
    .clk(),//add module's work clk domin
    .rst_n(),

    .sel_valid(),
    .sel_prior(),
    .sel_index(),

    .result_valid(),
    .result_prior(),
    .result_index()
);
*/