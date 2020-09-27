/****************************************************/
//	Module name: action_engine.v
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/25
//	Function outline: the action execution engine in RMT
/****************************************************/

module action_engine #(
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
    .phv_remain_data(alu_in_phv_remain_data)
);



//ALU_1
genvar gen_i;
generate
    //initialize 8 6B containers 
    for(gen_i = 7; gen_i >= 0; gen_i = gen_i - 1) begin
        alu_1 #(
            .STAGE(STAGE),
            .ACTION_LEN(),
            .DATA_WIDTH(width_6B)
        )alu_1_0(
            .clk(clk),
            .rst_n(rst_n),
            .action_in(action_in[(gen_i+8+8+1)*ACT_LEN-1 +: ACT_LEN]),
            .action_valid(action_valid_in),
            .operand_1_in(alu_in_6B_1[gen_i * width_6B -1 +: width_6B]),
            .operand_2_in(alu_in_6B_2[gen_i * width_6B -1 +: width_6B]),
            .container_out(phv_out[width_4B*8+width_2B*8+355+width_6B*gen_i-1 +: width_6B]),
            .container_out_valid(phv_valid_bit[gen_i])
        );

        alu_1 #(
            .STAGE(STAGE),
            .ACTION_LEN(),
            .DATA_WIDTH(width_2B)
        )alu_1_1(
            .clk(clk),
            .rst_n(rst_n),
            .action_in(action_in[(gen_i+1)*ACT_LEN-1 +: ACT_LEN]]),
            .action_valid(action_valid_in),
            .operand_1_in(alu_in_2B_1[gen_i * width_2B -1 +: width_2B]),
            .operand_2_in(alu_in_2B_2[gen_i * width_2B -1 +: width_2B]),
            .container_out(phv_out[355+width_2B*gen_i -1 +: width_2B]),
            .container_out_valid()
        );

        alu_2 #(
            .STAGE(STAGE),
            .ACTION_LEN(),
            .DATA_WIDTH(width_4B)  //data width of the ALU
        )alu_2_0(
            .clk(clk),
            .rst_n(rst_n),
            //input from sub_action
            .action_in(action_in[(gen_i+8+1)*ACT_LEN-1 +: ACT_LEN]]),
            .action_valid(action_in_valid),
            .operand_1_in(alu_in_4B_1[gen_i * width_4B -1 +: width_4B]),
            .operand_2_in(alu_in_4B_2[gen_i * width_4B -1 +: width_4B]),
            .operand_3_in(alu_in_4B_3[gen_i * width_4B -1 +: width_4B]),
            //output to form PHV
            .container_out(phv_out[width_2B*8+355+width_4B*gen_i-1 +: width_4B]),
            .container_out_valid()
        );

    end
endgenerate

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
    .comp_meta_data_in(phv_in[355:0]),
    .comp_meta_data_valid_in(phv_valid_in),
    .action_in(action_in[24:0]),
    .action_valid_in(action_valid_in),

    //output is the modified metadata plus comp_ins
    .comp_meta_data_out(phv_out[355:0]),
    .comp_meta_data_valid_out()
);

endmodule