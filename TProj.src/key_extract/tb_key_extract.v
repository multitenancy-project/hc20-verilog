`timescale 1ns / 1ps

module tb_key_extract #(
    parameter KEY_LEN = 896,
    parameter MASK_LEN = 896,
    parameter PHV_LEN = 1024+7+24*8+5*20+256
)();

localparam STAGE_P = 0;
reg clk;
reg rst_n;

reg parser_valid;
reg [PHV_LEN-1:0] phv_in;

wire key_out_valid;
wire [KEY_LEN-1:0] key_out;
wire mask_out_valid;
wire [MASK_LEN-1:0] mask_out;

wire cond_flag;
wire [PHV_LEN-1:0] phv_out;

//clk signal
localparam CYCLE = 10;

always begin
    #(CYCLE/2) clk = ~clk;
end

//reset signal
initial begin
    clk = 0;
    rst_n = 1;
    #(10);
    rst_n = 0; //reset all the values
    #(10);
    rst_n = 1;
end


initial begin
    #(2*CYCLE); //after the rst_n, start the test
    #(5)    
    parser_valid <= 1'b1;
    phv_in <= 1579'b10;
    #CYCLE 
    parser_valid <= 1'b0;
    phv_in <= 1579'b11;
    #(2*CYCLE)
    //test comparator
    parser_valid <= 1'b1;
    phv_in <= {1024'b0, 7'b0,  192'b0, 80'b0, 2'b01, 9'b110101010, 9'b111010100, 256'b0};
    #CYCLE
    parser_valid <= 1'b0;
    phv_in <= 1579'b0;
    #(2*CYCLE)
    //test key generator
    parser_valid <= 1'b1;
    phv_in <= {4'b1111, 1020'b0, 7'b0, 8'b1, 184'b0, 356'b0};
    #(CYCLE)
    parser_valid <= 1'b0;
    phv_in <= 1579'b0;
end


key_extract #(
	.STAGE(STAGE_P)
) key_extract(
    .axis_clk(clk),
    .aresetn(rst_n),

    //output from parser
    .parser_valid(parser_valid),
    .pkt_hdr_vec(phv_in),

    //key for lookup table
    .key_valid(key_out_valid),
    .extract_key(key_out),

    //mask for lookup
    .key_mask_valid(mask_out_valid),
    .key_mask(mask_out),

    //conditional flag: 1 for true, 0 for false.
    .cond_flag(cond_flag),
    .pkt_hdr_vec_out(phv_out)
);

endmodule