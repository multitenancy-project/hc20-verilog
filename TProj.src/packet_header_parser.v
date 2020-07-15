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
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter C_VALID_NUM_HDR_PKTS = 4
)
(
	input									axis_clk,
	input									aresetn,

	// input slvae axi stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		s_axis_tkeep,
	input									s_axis_tvalid,
	input									s_axis_tlast
);

integer idx;

/*==== definitions of functions ====*/
// extract field
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

// count number of 1-bit
function [5:0] count_ones (
	input [C_S_AXIS_DATA_WIDTH/8-1:0] data
);
begin
	count_ones = 0;
	for (idx=0; idx<C_S_AXIS_DATA_WIDTH/8; idx=idx+1)
		count_ones = count_ones + data[idx];
end
endfunction
//

localparam TOT_HDR_LEN = 2048; // assume at-most 256B header
localparam [2:0] IDLE=0, PKT_1=1, START=2, DONE=3;

reg [TOT_HDR_LEN-1:0] pkt_hdr;
wire [TOT_HDR_LEN-1:0] w_pkts;
reg [10:0] pkt_hdr_len;
reg [C_S_AXIS_DATA_WIDTH-1:0] pkts[0:7];
reg [C_S_AXIS_DATA_WIDTH/8-1:0] pkts_len[0:7];
reg [3:0] pkt_cnt;
reg [3:0] pkt_idx_reg;
reg [2:0] parse_state;

reg tlast_d1; // indicate whether the last valid packet 
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
wire w_tlast = (s_axis_tvalid & s_axis_tlast) & ~tlast_d1; // same as s_axis_tlast

// update pkt_cnt;
always @(posedge axis_clk) begin
	if (~aresetn) begin
		pkt_cnt <= 0;
	end
	else if (tlast_d1) begin
		pkt_cnt <= 0;
	end
	else if (pkt_cnt > C_VALID_NUM_HDR_PKTS) begin
		pkt_cnt <= pkt_cnt;
	end
	else if (s_axis_tvalid) begin
		pkt_cnt <= pkt_cnt+1;
	end
end

// hdr_window, #pkt_cnt 
wire hdr_window = s_axis_tvalid && pkt_cnt<=C_VALID_NUM_HDR_PKTS;
// store into pkts
always @(posedge axis_clk) begin
	if (~aresetn) begin
		for (idx=0; idx<8; idx=idx+1) begin
			pkts[idx] <= 0;
			pkts_len[idx] <= 0;
		end
	end
	else if (hdr_window && pkt_cnt==0) begin
		for (idx=1; idx<8; idx=idx+1) begin
			pkts[idx] <= 0;
			pkts_len[idx] <= 0;
		end
		pkts[pkt_cnt] <= s_axis_tdata;
		pkts_len[pkt_cnt] <= count_ones(s_axis_tkeep)*8;
	end
	else if (hdr_window) begin
		pkts[pkt_cnt] <= s_axis_tdata;
		pkts_len[pkt_cnt] <= count_ones(s_axis_tkeep)*8;
	end
end

// parse 
// all the Ether, VLAN, IP, UDP headers are static
assign w_pkts = pkts[pkt_idx_reg];

// Eth and vlan
reg [47:0] dst_mac_addr;
reg [47:0] src_mac_addr;
reg [31:0] vlan_hdr;
reg [15:0] eth_type;

// IP header
// localparam POS_IP_HDR = 48*2+32+16;
// localparam POS_IP_PROT = POS_IP_HDR+72;			// 144+72 = 216
// localparam POS_IP_SRC_ADDR = POS_IP_HDR+96;		// 144+96 = 240
// localparam POS_IP_DST_ADDR = POS_IP_HDR+128;	// 144+128 = 272

reg [7:0] ip_prot;
reg [31:0] ip_src_addr;
reg [31:0] ip_dst_addr;


// UDP header
// localparam POS_UDP_HDR = 48*2+32+16+160;		// 144+160 = 304
// localparam POS_UDP_SRC_PORT = POS_UDP_HDR;		// 304
// localparam POS_UDP_DST_PORT = POS_UDP_HDR+16;	// 320

reg [15:0] udp_src_port;
reg [15:0] udp_dst_port;

// whole length
localparam TOT_COMMON_HDR_LEN = (18+20+8)*8; // 368
localparam RIGHT_SHIFT_NUM = TOT_COMMON_HDR_LEN-C_S_AXIS_DATA_WIDTH; // (368-256=) 112

//
// TODO: just an example
// from action ram
wire [31:0] act_data_out;
wire [3:0] w_wr_addr;
wire [3:0] w_shift;
reg [3:0] next_state;
reg store_wr_en; // CAM match indicator
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
		pkt_hdr_len <= 0;
		//
		parse_state <= IDLE;
		next_state <= 'hf;
		//
		pkt_idx_reg <= 0;
	end
	else begin
		case (parse_state)
			IDLE: begin
				// we have one packet now
				if (hdr_window==1'b1 && pkt_cnt==1) begin
					// parse the first 32 bytes
					dst_mac_addr <= pkts[pkt_idx_reg][0+:48]; // 48
					src_mac_addr <= pkts[pkt_idx_reg][48+:48]; // 96
					vlan_hdr <= pkts[pkt_idx_reg][96+:32]; // 128
					eth_type <= pkts[pkt_idx_reg][128+:16]; // 144
					ip_prot <= pkts[pkt_idx_reg][216+:8]; // 240
					ip_src_addr[15:0] <= pkts[pkt_idx_reg][240+:16];

					pkt_idx_reg <= pkt_idx_reg+1;
					parse_state <= PKT_1;
				end
			end
			PKT_1: begin
				if (eth_type==`TYPE_IPV4 && ip_prot==`PROT_UDP) begin // we only consider UDP packet
					ip_src_addr[31:16] <= pkts[pkt_idx_reg][0+:16];
					ip_dst_addr <= pkts[pkt_idx_reg][16+:32];

					udp_src_port <= pkts[pkt_idx_reg][48+:16];
					udp_dst_port <= pkts[pkt_idx_reg][64+:16];
					// 
					pkt_hdr <= pkts[pkt_idx_reg] >> RIGHT_SHIFT_NUM;
					pkt_hdr_len <= pkts_len[pkt_idx_reg]-RIGHT_SHIFT_NUM;
					pkt_idx_reg <= pkt_idx_reg+1;
					parse_state <= START;
					next_state <= vlan_hdr[27:24];
				end
				else begin
					parse_state <= DONE;
				end
			end
			// start to parse custom headers
			START: begin
				next_state <= act_data_out[3:0];
				if (pkt_hdr_len < w_shift*8) begin
					if (pkt_idx_reg < pkt_cnt) begin // put more data here
						pkt_hdr <= (w_pkts << pkt_hdr_len) | pkt_hdr;
						pkt_hdr_len <= pkt_hdr_len+pkts_len[pkt_idx_reg];
						pkt_idx_reg <= pkt_idx_reg+1;
					end
					else begin // no more data
						parse_state <= DONE;
					end
				end
				else if (store_wr_en == 1'b1) begin // one-clk delayed match signal
					// right shift
					pkt_hdr <= pkt_hdr >> (w_shift*8);
					pkt_hdr_len <= pkt_hdr_len-w_shift*8;
				end
				else begin
					pkt_hdr <= pkt_hdr;
					pkt_hdr_len <= pkt_hdr_len;
				end
				// 
				if (pkt_hdr==0 || next_state=='hf) begin
					parse_state <= DONE;
				end
			end
			DONE: begin
				// zero out all pkt-related infos
				next_state <= 'hf;
				parse_state <= IDLE;
				pkt_idx_reg <= 0;
				pkt_hdr_len <= 0;
			end
		endcase
	end
end

// dealy one clk for writing into PHV ram
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
