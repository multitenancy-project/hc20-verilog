`timescale 1ns / 1ps

module stage #(
    parameter KEY_LEN  = 896,
    parameter MASK_LEN = 896,
    parameter PHV_LEN = 1024+7+24*8+5*20+256,
    parameter STAGE_P = 0  //valid: 0-4
)
(
    input                        axis_clk,
    input                        aresetn,

    input      [PHV_LEN-1:0]     phv_in,
    input                        phv_in_valid,
    output [PHV_LEN-1:0]     phv_out,
    output phv_out_valid
);

//key_extract to lookup_engine
wire [KEY_LEN-1:0] key2lookup_key;
wire               key2lookup_key_valid;
wire               key2lookup_cond_flag;
wire [PHV_LEN-1:0] key2lookup_phv;

//lookup_engine to action_engine
wire [24:0]        lookup2action_action;
wire               lookup2action_action_valid;
wire [PHV_LEN-1:0] lookup2action_phv;

//
wire				key2lookup_key_valid_w;
reg					key2lookup_key_valid_r;
//

key_extract #(
	.STAGE(STAGE_P)
) key_extract(
    .axis_clk(axis_clk),
    .aresetn(aresetn),

    //output from parser
    .parser_valid(phv_in_valid),
    .pkt_hdr_vec(phv_in),

    //key for lookup table
    .key_valid(key2lookup_key_valid),
    .extract_key(key2lookup_key),

    //mask for lookup
    .key_mask_valid(),
    .key_mask(),

    //conditional flag: 1 for true, 0 for false.
    .cond_flag(key2lookup_cond_flag),
    .pkt_hdr_vec_out(key2lookup_phv)
);

lookup_engine #(
    .STAGE(STAGE_P)
) lookup_engine(
    .axis_clk(axis_clk),
    .aresetn(aresetn),

    //output from key extractor
    .extract_key(key2lookup_key),
    .key_valid(key2lookup_key_valid_w),
    .cond_flag(key2lookup_cond_flag),
    .pkt_hdr_vec(key2lookup_phv),

    //output to the action engine
    .action(lookup2action_action),
    .action_valid(lookup2action_action_valid),
    .pkt_hdr_vec_out(lookup2action_phv),

    //control channel
    .lookup_din(),
    .lookup_din_mask(),
    .lookup_din_addr(),
    .lookup_din_en(),

    //control channel (action ram)
    .action_data_in(),
    .action_en(),
    .action_addr()
);

action_engine #(
    .STAGE(STAGE_P)
) action_engine(
    .axis_clk(axis_clk),
    .aresetn(aresetn),

    //output from lookup engine
    .action_in(lookup2action_action),
    .action_in_valid(lookup2action_action_valid),
    .phv_in(lookup2action_phv),

    //output to the next stage
    .phv_out(phv_out),
    .phv_out_valid(phv_out_valid)
);


always @(posedge axis_clk) begin
	if (~aresetn) begin
		key2lookup_key_valid_r <= 0;
	end
	else begin
		key2lookup_key_valid_r <= key2lookup_key_valid;
	end
end

endmodule
