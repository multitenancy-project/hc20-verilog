/****************************************************/
//	Module name: action_engine.v
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/25
//	Function outline: the action execution engine in RMT
/****************************************************/

module action_engine_2 #(
    parameter STAGE = 0,
    parameter PHV_LEN = 48*8+32*8+16*8+5*20+256,
    parameter ACT_LEN = 25
)(
    input clk,
    input rst_n,

    //signals from lookup to ALUs
    input [PHV_LEN-1:0]       phv_in,
    input                     phv_valid_in,
    input [ACT_LEN*25-1:0]    action_in,
    input                     action_valid_in,

    //signals output from ALUs
    output [PHV_LEN-1:0]      phv_out,
    output                    phv_valid_out
);

/********intermediate variables declared here********/
integer i;

localparam width_2B = 16;
localparam width_4B = 32;
localparam width_6B = 48;

wire                        alu_in_valid;
wire [width_6B*8-1:0]       alu_in_6B_1;
wire [width_6B*8-1:0]       alu_in_6B_2;
wire [width_4B*8-1:0]       alu_in_4B_1;
wire [width_4B*8-1:0]       alu_in_4B_2;
wire [width_4B*8-1:0]       alu_in_4B_3;
wire [width_2B*8-1:0]       alu_in_2B_1;
wire [width_2B*8-1:0]       alu_in_2B_2;
wire [355:0]                alu_in_phv_remain_data;

wire [7:0]                  phv_valid_bit;

wire [ACT_LEN*25-1:0]       alu_in_action;
wire                        alu_in_action_valid;


assign phv_valid_out = phv_valid_bit[7];
/********intermediate variables declared here********/

/********IPs instancilzed here*********/

//crossbar
crossbar #(
    .STAGE(STAGE),
    .PHV_LEN(),
    .ACT_LEN(),
    .width_2B(),
    .width_4B(),
    .width_6B()
)cross_bar(
    .clk(clk),
    .rst_n(rst_n),
    //input from PHV
    .phv_in(phv_in),
    .phv_in_valid(phv_valid_in),
    //input from action
    .action_in(action_in),
    .action_in_valid(action_valid_in),
    //output to the ALU
    .alu_in_valid(alu_in_valid),
    .alu_in_6B_1(alu_in_6B_1),
    .alu_in_6B_2(alu_in_6B_2),
    .alu_in_4B_1(alu_in_4B_1),
    .alu_in_4B_2(alu_in_4B_2),
    .alu_in_4B_3(alu_in_4B_3),
    .alu_in_2B_1(alu_in_2B_1),
    .alu_in_2B_2(alu_in_2B_2),
    .phv_remain_data(alu_in_phv_remain_data),
    .action_out(alu_in_action),
    .action_valid_out(alu_in_action_valid)
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_7_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(7+18)*25-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(7+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(7+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(7+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[7])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_6_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(6+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(6+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(6+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(6+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[6])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_5_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(5+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(5+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(5+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(5+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[5])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_4_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(4+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(4+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(4+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(4+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[4])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_3_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(3+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(3+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(3+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(3+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[3])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_2_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(2+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(2+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(2+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(2+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[2])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_1_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(1+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(1+1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(1+1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(1+1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[1])
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_6B)
)alu_0_6B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_6B_1[(1) * width_6B -1 -: width_6B]),
    .operand_2_in(alu_in_6B_2[(1) * width_6B -1 -: width_6B]),
    .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(1)-1 -: width_6B]),
    .container_out_valid(phv_valid_bit[0])
);


/*
    ALU_1 2B segments
*/

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_7_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(7+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(7+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(7+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(7+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_6_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(6+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(6+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(6+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(6+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_5_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(5+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(5+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(5+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(5+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_4_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(4+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(4+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(4+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(4+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_3_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(3+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(3+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(3+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(3+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_2_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(2+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(2+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(2+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(2+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_1_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(1+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(1+1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(1+1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(1+1) -1 -: width_2B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_2B)
)alu_0_2B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_2B_1[(1) * width_2B -1 -: width_2B]),
    .operand_2_in(alu_in_2B_2[(1) * width_2B -1 -: width_2B]),
    .container_out(phv_out[356+width_2B*(1) -1 -: width_2B]),
    .container_out_valid()
);

/*
    ALU_1 4B segments
*/

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_6_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(6+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(6+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(6+1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(6+1) -1 -: width_4B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_5_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(5+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(5+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(5+1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(5+1) -1 -: width_4B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_4_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(4+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(4+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(4+1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(4+1) -1 -: width_4B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_3_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(3+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(3+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(3+1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(3+1) -1 -: width_4B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_2_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(2+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(2+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(2+1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(2+1) -1 -: width_4B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_1_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(1+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(1+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(1+1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(1+1) -1 -: width_4B]),
    .container_out_valid()
);

alu_1 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)
)alu_0_4B(
    .clk(clk),
    .rst_n(rst_n),
    .action_in(alu_in_action[(1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(1) * width_4B -1 -: width_4B]),
    .container_out(phv_out[width_2B*8+356+width_4B*(1) -1 -: width_4B]),
    .container_out_valid()
);



alu_2 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .DATA_WIDTH(width_4B)  //data width of the ALU
)alu_7_4B(
    .clk(clk),
    .rst_n(rst_n),
    //input from sub_action
    .action_in(alu_in_action[(7+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
    .action_valid(alu_in_action_valid),
    .operand_1_in(alu_in_4B_1[(7+1) * width_4B -1 -: width_4B]),
    .operand_2_in(alu_in_4B_2[(7+1) * width_4B -1 -: width_4B]),
    .operand_3_in(alu_in_4B_3[(7+1) * width_4B -1 -: width_4B]),
    //output to form PHV
    .container_out(phv_out[width_2B*8+356+width_4B*(7+1)-1 -: width_4B]),
    .container_out_valid()
);

// //ALU_1
// genvar gen_i;
// generate
//     //initialize 8 6B containers 
//     for(gen_i = 7; gen_i >= 0; gen_i = gen_i - 1) begin
//         alu_1 #(
//             .STAGE(STAGE),
//             .ACTION_LEN(),
//             .DATA_WIDTH(width_6B)
//         )alu_1_6B(
//             .clk(clk),
//             .rst_n(rst_n),
//             .action_in(alu_in_action[(gen_i+8+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
//             .action_valid(alu_in_action_valid),
//             .operand_1_in(alu_in_6B_1[(gen_i+1) * width_6B -1 -: width_6B]),
//             .operand_2_in(alu_in_6B_2[(gen_i+1) * width_6B -1 -: width_6B]),
//             .container_out(phv_out[width_4B*8+width_2B*8+356+width_6B*(gen_i+1)-1 -: width_6B]),
//             .container_out_valid(phv_valid_bit[gen_i])
//         );

//         alu_1 #(
//             .STAGE(STAGE),
//             .ACTION_LEN(),
//             .DATA_WIDTH(width_2B)
//         )alu_1_2B(
//             .clk(clk),
//             .rst_n(rst_n),
//             .action_in(alu_in_action[(gen_i+1+1)*ACT_LEN-1 -: ACT_LEN]),
//             .action_valid(alu_in_action_valid),
//             .operand_1_in(alu_in_2B_1[(gen_i+1) * width_2B -1 -: width_2B]),
//             .operand_2_in(alu_in_2B_2[(gen_i+1) * width_2B -1 -: width_2B]),
//             .container_out(phv_out[356+width_2B*(gen_i+1) -1 -: width_2B]),
//             .container_out_valid()
//         );
        
//         if(gen_i == 7) begin
//             alu_2 #(
//                 .STAGE(STAGE),
//                 .ACTION_LEN(),
//                 .DATA_WIDTH(width_4B)  //data width of the ALU
//             )alu_2_0(
//                 .clk(clk),
//                 .rst_n(rst_n),
//                 //input from sub_action
//                 .action_in(alu_in_action[(gen_i+8+1+1)*ACT_LEN-1 -: ACT_LEN]),
//                 .action_valid(alu_in_action_valid),
//                 .operand_1_in(alu_in_4B_1[(gen_i+1) * width_4B -1 -: width_4B]),
//                 .operand_2_in(alu_in_4B_2[(gen_i+1) * width_4B -1 -: width_4B]),
//                 .operand_3_in(alu_in_4B_3[(gen_i+1) * width_4B -1 -: width_4B]),
//                 //output to form PHV
//                 .container_out(phv_out[width_2B*8+356+width_4B*(gen_i+1)-1 -: width_4B]),
//                 .container_out_valid()
//             );
//         end

//         else begin
//             alu_1 #(
//                 .STAGE(STAGE),
//                 .ACTION_LEN(),
//                 .DATA_WIDTH(width_4B)
//             )alu_1_4B(
//                 .clk(clk),
//                 .rst_n(rst_n),
//                 .action_in(alu_in_action[(gen_i+1+1)*ACT_LEN-1 -: ACT_LEN]),
//                 .action_valid(alu_in_action_valid),
//                 .operand_1_in(alu_in_4B_1[(gen_i+1) * width_4B -1 -: width_4B]),
//                 .operand_2_in(alu_in_4B_2[(gen_i+1) * width_4B -1 -: width_4B]),
//                 .container_out(phv_out[width_2B*8+356+width_4B*(gen_i+1) -1 -: width_4B]),
//                 .container_out_valid()
//              );
//         end
    
//     end
// endgenerate

//initialize ALU_3 for matedata

alu_3 #(
    .STAGE(STAGE),
    .ACTION_LEN(),
    .META_LEN(),
    .COMP_LEN()
)alu_3_0(
    .clk(clk),
    .rst_n(rst_n),
    //input data shall be metadata & com_ins
    .comp_meta_data_in(alu_in_phv_remain_data),
    .comp_meta_data_valid_in(alu_in_valid),
    .action_in(alu_in_action[24:0]),
    .action_valid_in(alu_in_action_valid),

    //output is the modified metadata plus comp_ins
    .comp_meta_data_out(phv_out[355:0]),
    .comp_meta_data_valid_out()
);

endmodule