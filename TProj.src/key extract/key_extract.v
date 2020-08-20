`timescale 1ns / 1ps

module key_extract #(
    parameter KEY_LEN  = 896,
    parameter MASK_LEN = 896,
    parameter KEY_LEN_1 = 896-512,
    parameter KEY_LEN_2 = 512,
    parameter PKT_HDR_LEN = 1024+7+24*8+5*20+256
)
(
    input       axis_clk,
    input       aresetn,

    //output from parser
    input                       parser_valid,
    input [PKT_HDR_LEN-1:0]     pkt_hdr_vec,

    //key for lookup table
    output reg                  key_valid,
    output reg [KEY_LEN-1:0]    extract_key,

    //mask for lookup
    output reg                  key_mask_valid,
    output reg [MASK_LEN-1:0]   key_mask
);

/********intermediate variables declared here********/
localparam HDR_OFF  = 711;
localparam CONT_OFF = 512;
localparam width_2B = 16;
localparam width_4B = 32;
localparam width_8B = 64;
//the number of values in the PHV
localparam VAL_NUM  = 8;

reg []
reg [KEY_LEN-1:0] key_reg;
reg [MASK_LEN-1:0] mask_reg;

//store the 
//restore the offset
/********intermediate variables declared here********/

/********generate the key*******/ 
always @(posedge axis_clk or negedge aresetn) begin
    if (~aresetn) begin
        key_reg <= 512'b0;
        mask_reg <= 512'b0
    end

    else begin
        if(parser_valid == 1'b1) begin
            //start to extract keys, this can be done in parallel
            key_reg[0 +: width_2B] <= pkt_hdr_vec[HDR_OFF +: ]
            //at the same time, we need to build up the mask
            
        end
    end
end
/********generate the key*******/ 



endmodule