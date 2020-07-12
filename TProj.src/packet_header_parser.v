`timescale 1ns / 1ps

`define DEF_MAC_ADDR	48
`define DEF_VLAN		32
`define DEF_ETHTYPE		16

`define TYPE_IPV4		16'h0008
`define TYPE_ARP		16'h0608

`define PROT_ICMP		8'h01
`define PROT_TCP		8'h06
`define PROT_UDP		8'h11


module packet_header_parser #(
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128
)
(
	input									axis_clk,
	input									aresetn,

	// input slvae axi stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input									s_axis_tvalid,
	input									s_axis_tlast
);

integer idx;

function [31:0] pad_ones (
	input [3:0] data
);
begin
	pad_ones = 0;
	for (idx=0; idx<32; idx=idx+1)
		if (idx<(data+1)*8 && idx<32)
			pad_ones[idx] = 1;
end
endfunction

function [4:0] count_ones (
	input [C_S_AXIS_DATA_WIDTH-1:0] data
);
begin
	count_ones = 0;
	for (idx=0; idx<C_S_AXIS_DATA_WIDTH; idx=idx+1)
		count_ones = count_ones + data[idx];
end
endfunction



localparam TOT_HDR_LEN = 2048; // assume at-most 256B header
localparam [1:0] IDLE=2'b00, START=2'b01, DONE=2'b10;

reg [TOT_HDR_LEN-1:0] pkt_hdr;
reg [C_S_AXIS_DATA_WIDTH-1:0] pkts[0:7];
reg [3:0] pkt_cnt;
reg [1:0] parse_state;

reg tlast_d1;

// 
always @(posedge axis_clk) begin
	if (~aresetn) begin
		tlast_d1 <= 0;
	end
	else begin
		tlast_d1 <= s_axis_tvalid & s_axis_tlast;
	end
end

//
wire w_tlast = (s_axis_tvalid & s_axis_tlast) & ~tlast_d1;

// update pkt_cnt;
always @(posedge axis_clk) begin
	if (~aresetn) begin
		pkt_cnt <= 0;
	end
	else if (tlast_d1) begin
		pkt_cnt <= 0;
	end
	else if (pkt_cnt > 4) begin
		pkt_cnt <= pkt_cnt;
	end
	else if (s_axis_tvalid) begin
		pkt_cnt <= pkt_cnt+1;
	end
end

// hdr_window, #pkt_cnt 
wire hdr_window = s_axis_tvalid && pkt_cnt<=4;
// store into pkts
always @(posedge axis_clk) begin
	if (~aresetn) begin
		for (idx=0; idx<8; idx=idx+1) begin
			pkts[idx] <= 0;
		end
	end
	else if (hdr_window && pkt_cnt==0) begin
		for (idx=1; idx<8; idx=idx+1) begin
			pkts[idx] <= 0;
		end
		pkts[pkt_cnt] <= s_axis_tdata;
	end
	else if (s_axis_tvalid) begin
		pkts[pkt_cnt] <= s_axis_tdata;
	end
end

// parse 
// all the Ether, VLAN, IP, UDP headers are static
wire [TOT_HDR_LEN-1:0] hdr_info = {pkts[7], pkts[6], pkts[5], pkts[4],
									pkts[3], pkts[2], pkts[1], pkts[0]};

// Eth and vlan
wire [47:0] dst_mac_addr = hdr_info[0+:48];
wire [47:0] src_mac_addr = hdr_info[48+:48];
wire [31:0] vlan_hdr = hdr_info[96+:32];
wire [15:0] eth_type = hdr_info[128+:16];

// IP header
localparam POS_IP_HDR = 48*2+32+16;
localparam POS_IP_PROT = POS_IP_HDR+72;
localparam POS_IP_SRC_ADDR = POS_IP_HDR+96;
localparam POS_IP_DST_ADDR = POS_IP_HDR+128;

wire [7:0] ip_prot = hdr_info[POS_IP_PROT+:8];
wire [31:0] ip_src_addr = hdr_info[POS_IP_SRC_ADDR+:32];
wire [31:0] ip_dst_addr = hdr_info[POS_IP_DST_ADDR+:32];


// UDP header
localparam POS_UDP_HDR = 48*2+32+16+160;
localparam POS_UDP_SRC_PORT = POS_UDP_HDR;
localparam POS_UDP_DST_PORT = POS_UDP_HDR+16;

wire [15:0] udp_src_port = hdr_info[POS_UDP_SRC_PORT+:16];
wire [15:0] udp_dst_port = hdr_info[POS_UDP_DST_PORT+:16];

// whole length
localparam TOT_COMMON_HDR_LEN = (18+20+8)*8;


wire w_parser_en = w_tlast || pkt_cnt==4;
// indicate whether those headers are validate
reg r_parser_en;

always @(posedge axis_clk) begin
	if (~aresetn) begin
		r_parser_en <= 0;
	end
	else begin
		r_parser_en <= w_parser_en;
	end
end



//
// TODO: just an example
// from action ram
wire [31:0] act_data_out;
wire [3:0] w_wr_addr;
wire [5:0] w_shift;
reg [3:0] next_state;
reg store_wr_en;
// to store ram
wire [31:0] w_store_data_in;
assign w_shift = act_data_out[7:4];
assign w_wr_addr = act_data_out[11:8];
assign w_store_data_in = (pkt_hdr >> (act_data_out[15:12]*8)) & pad_ones(act_data_out[19:16]);
//
wire match;
wire [3:0] match_addr;
// 
always @(posedge axis_clk) begin
	if (~aresetn) begin
		// initialization for pkt_hdr
		pkt_hdr <= 0;
		//
		parse_state <= IDLE;
		next_state <= 'hf;
	end
	else begin
		case (parse_state)
			IDLE: begin
				// we only need to parse more if it is a UDP header
				if (r_parser_en && ip_prot==`PROT_UDP) begin
					parse_state <= START;
					pkt_hdr <= hdr_info >> TOT_COMMON_HDR_LEN;
					next_state <= vlan_hdr[27:24];
				end
			end
			// start to parse custom
			START: begin
				next_state <= act_data_out[3:0];
				// 
				if (pkt_hdr==0 || next_state=='hf) begin
					parse_state <= DONE;
				end
			end
			DONE: begin
				next_state <= 'hf;
				parse_state <= IDLE;
			end
		endcase
	end
end

// update such shits
/*
always @(posedge axis_clk) begin
	if (~aresetn) begin
		next_state <= 'hf;
	end
	else begin
		case (parse_state)
			IDLE: begin
				if (r_parser_en && ip_prot==`PROT_UDP) begin
					next_state <= vlan_hdr[27:24];
				end
			end
			START: begin
				next_state <= act_data_out[3:0];
				shift <= act_data_out[7:4];
				wr_addr <= act_data_out[11:8];
				store_data_in <= (pkt_hdr >> (act_data_out[15:12]*8)) & pad_ones(act_data_out[19:16]);
			end
		endcase
	end
end
*/


always @(posedge axis_clk) begin
	if (~aresetn) begin
		store_wr_en <= 0;
	end
	else 
		store_wr_en <= match;
end

// cam 
cam_top # ( 
	.C_DEPTH			(16),
	.C_WIDTH			(4),
	.C_MEM_INIT_FILE	("./cam_init_file.mif")
)
cam
(
	.CLK				(axis_clk),
	.CMP_DIN			(next_state),
	.CMP_DATA_MASK		(4'b0000),
	.BUSY				(),
	.MATCH				(match),
	.MATCH_ADDR			(match_addr),
	.WE					(),
	.WR_ADDR			(),
	.DATA_MASK			(),
	.DIN				(),
	.EN					(1'b1)
);

// action ram
ram16x32 # (
	.MEM_INIT_FILE ("rams_init_file.mif")
)
act_ram
(
	.axi_clk		(),
	.axi_wr_en		(),
	.axi_addr		(),
	.axi_data_in	(),
	.axi_data_out	(),

	.axis_clk		(axis_clk),
	.axis_wr_en		(),
	.axis_addr		(match_addr),
	.axis_data_out	(act_data_out),
	.axis_data_in	()
);

// store ram
ram16x32 # (
)
store_ram
(
	.axi_clk		(),
	.axi_wr_en		(),
	.axi_addr		(),
	.axi_data_in	(),
	.axi_data_out	(),

	.axis_clk		(axis_clk),
	.axis_wr_en		(store_wr_en),
	.axis_addr		(w_wr_addr),
	.axis_data_out	(),
	.axis_data_in	(w_store_data_in)
);

endmodule
