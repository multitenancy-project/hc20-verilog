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
	parameter C_VALID_NUM_HDR_PKTS = 4,			// 4*32B = 128B = 1024b
	parameter PKT_HDR_LEN = 1024+7+24*8+5*20+256, // 1024 at-most 4 segments, 7 total length in byte, 24*(1+7) phv, 5*20 conditional, 256 bits
	parameter PARSE_ACT_RAM_WIDTH = 267 // original 167 bits + 100 conditional block bits
)
(
	input									axis_clk,
	input									aresetn,

	// input slvae axi stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input [C_S_AXIS_DATA_WIDTH/8-1:0]		s_axis_tkeep,
	input									s_axis_tvalid,
	input									s_axis_tlast,

	// output
	output reg								parser_valid,
	output [PKT_HDR_LEN-1:0]				pkt_hdr_vec
);

integer idx;

/*==== definitions of functions ====*/
/*==== [END] definitions of functions ====*/

localparam TOT_HDR_LEN = 1024; // assume at-most 128B (46B+82B) header
wire [TOT_HDR_LEN-1:0] w_pkts;
reg [3:0] pkt_cnt;
reg [C_S_AXIS_DATA_WIDTH-1:0] pkts[0:C_VALID_NUM_HDR_PKTS-1];
reg [C_S_AXIS_TUSER_WIDTH-1:0] tuser_1st;

/****** store all or at-most 4 pkt segments ******/
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
		end

		tuser_1st <= 0;
	end
	else if (hdr_window && pkt_cnt==0) begin
		for (idx=1; idx<8; idx=idx+1) begin
			pkts[idx] <= 0;
		end
		pkts[pkt_cnt] <= s_axis_tdata;
		tuser_1st <= s_axis_tuser;
	end
	else if (hdr_window) begin
		pkts[pkt_cnt] <= s_axis_tdata;
	end
end
/****** store all or at-most 4 pkt segments ******/

/****** parse ******/
// all the Ether, VLAN, IP, UDP headers are static
assign w_pkts = {pkts[3], pkts[2], pkts[1], pkts[0]};

// Eth and vlan
wire [47:0] dst_mac_addr;
wire [47:0] src_mac_addr;
wire [31:0] vlan_hdr;
wire [15:0] eth_type;
assign dst_mac_addr = w_pkts[0+:48]; // 48
assign src_mac_addr = w_pkts[48+:48]; // 96
assign vlan_hdr = w_pkts[96+:32]; // 128
assign eth_type = w_pkts[128+:16]; // 144

// IP header
// localparam POS_IP_HDR = 48*2+32+16;
// localparam POS_IP_PROT = POS_IP_HDR+72;			// 144+72 = 216
// localparam POS_IP_SRC_ADDR = POS_IP_HDR+96;		// 144+96 = 240
// localparam POS_IP_DST_ADDR = POS_IP_HDR+128;	// 144+128 = 272

wire [7:0] ip_prot;
wire [31:0] ip_src_addr;
wire [31:0] ip_dst_addr;
assign ip_prot = w_pkts[216+:8]; // 240
assign ip_src_addr = w_pkts[240+:32];
assign ip_dst_addr = w_pkts[272+:32];


// UDP header
// localparam POS_UDP_HDR = 48*2+32+16+160;		// 144+160 = 304
// localparam POS_UDP_SRC_PORT = POS_UDP_HDR;		// 304
// localparam POS_UDP_DST_PORT = POS_UDP_HDR+16;	// 320

wire [15:0] udp_src_port;
wire [15:0] udp_dst_port;
assign udp_src_port = w_pkts[304+:16];
assign udp_dst_port = w_pkts[320+:16];

// whole length
localparam TOT_COMMON_HDR_LEN = (18+20+8)*8; // 368
localparam RIGHT_SHIFT_NUM = TOT_COMMON_HDR_LEN-C_S_AXIS_DATA_WIDTH; // (368-256=) 112
localparam [2:0] IDLE=0, START_PARSE=1, DONE_PARSE=2;

reg [2:0] parse_state;
// 
wire [PARSE_ACT_RAM_WIDTH-1:0] parse_act_data_out;
reg [3:0] initial_state;

//
wire match;
reg match_d1;
wire [3:0] match_addr;


// PHV containers
reg [7:0] r_off_con_2B_0;
reg [7:0] r_off_con_2B_1;
reg [7:0] r_off_con_2B_2;
reg [7:0] r_off_con_2B_3;
reg [7:0] r_off_con_2B_4;
reg [7:0] r_off_con_2B_5;
reg [7:0] r_off_con_2B_6;
reg [7:0] r_off_con_2B_7;
reg [7:0] r_off_con_4B_0;
reg [7:0] r_off_con_4B_1;
reg [7:0] r_off_con_4B_2;
reg [7:0] r_off_con_4B_3;
reg [7:0] r_off_con_4B_4;
reg [7:0] r_off_con_4B_5;
reg [7:0] r_off_con_4B_6;
reg [7:0] r_off_con_4B_7;
reg [7:0] r_off_con_8B_0;
reg [7:0] r_off_con_8B_1;
reg [7:0] r_off_con_8B_2;
reg [7:0] r_off_con_8B_3;
reg [7:0] r_off_con_8B_4;
reg [7:0] r_off_con_8B_5;
reg [7:0] r_off_con_8B_6;
reg [7:0] r_off_con_8B_7;
reg [6:0] r_tot_length;
// parse act unit
wire [15:0] w_parse_act_unit_0;
wire [15:0] w_parse_act_unit_1;
wire [15:0] w_parse_act_unit_2;
wire [15:0] w_parse_act_unit_3;
wire [15:0] w_parse_act_unit_4;
wire [15:0] w_parse_act_unit_5;
wire [15:0] w_parse_act_unit_6;
wire [15:0] w_parse_act_unit_7;
wire [15:0] w_parse_act_unit_8;
wire [15:0] w_parse_act_unit_9;
wire [6:0] w_tot_length;
// conditional blocks
reg [19:0] r_cond_blk_0;
reg [19:0] r_cond_blk_1;
reg [19:0] r_cond_blk_2;
reg [19:0] r_cond_blk_3;
reg [19:0] r_cond_blk_4;
//
assign w_parse_act_unit_0 = parse_act_data_out[100+:16];
assign w_parse_act_unit_1 = parse_act_data_out[116+:16];
assign w_parse_act_unit_2 = parse_act_data_out[132+:16];
assign w_parse_act_unit_3 = parse_act_data_out[148+:16];
assign w_parse_act_unit_4 = parse_act_data_out[164+:16];
assign w_parse_act_unit_5 = parse_act_data_out[180+:16];
assign w_parse_act_unit_6 = parse_act_data_out[196+:16];
assign w_parse_act_unit_7 = parse_act_data_out[212+:16];
assign w_parse_act_unit_8 = parse_act_data_out[228+:16];
assign w_parse_act_unit_9 = parse_act_data_out[244+:16];
assign w_tot_length = parse_act_data_out[260+:7];
//
//
always @(*) begin
	// we only log down the offset info
	r_off_con_2B_0 = 0;
	r_off_con_2B_1 = 0;
	r_off_con_2B_2 = 0;
	r_off_con_2B_3 = 0;
	r_off_con_2B_4 = 0;
	r_off_con_2B_5 = 0;
	r_off_con_2B_6 = 0;
	r_off_con_2B_7 = 0;
	r_off_con_4B_0 = 0;
	r_off_con_4B_1 = 0;
	r_off_con_4B_2 = 0;
	r_off_con_4B_3 = 0;
	r_off_con_4B_4 = 0;
	r_off_con_4B_5 = 0;
	r_off_con_4B_6 = 0;
	r_off_con_4B_7 = 0;
	r_off_con_8B_0 = 0;
	r_off_con_8B_1 = 0;
	r_off_con_8B_2 = 0;
	r_off_con_8B_3 = 0;
	r_off_con_8B_4 = 0;
	r_off_con_8B_5 = 0;
	r_off_con_8B_6 = 0;
	r_off_con_8B_7 = 0;
	// conditional block
	r_cond_blk_0 = parse_act_data_out[0+:20];
	r_cond_blk_1 = parse_act_data_out[20+:20];
	r_cond_blk_2 = parse_act_data_out[40+:20];
	r_cond_blk_3 = parse_act_data_out[60+:20];
	r_cond_blk_4 = parse_act_data_out[80+:20];
	

	r_tot_length = w_tot_length;

	if (w_parse_act_unit_0[0] == 1'b1) begin // valid
		case (w_parse_act_unit_0[5:4])
			0 : begin
				case (w_parse_act_unit_0[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_0[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_0[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_0[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_0[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_0[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_0[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_0[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_0[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_0[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_0[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_0[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_0[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_0[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_0[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_0[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_0[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_0[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_0[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_0[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_0[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_0[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_0[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_0[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_0[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_0[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_0[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_1[0] == 1'b1) begin // valid
		case (w_parse_act_unit_1[5:4])
			0 : begin
				case (w_parse_act_unit_1[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_1[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_1[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_1[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_1[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_1[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_1[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_1[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_1[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_1[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_1[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_1[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_1[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_1[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_1[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_1[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_1[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_1[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_1[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_1[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_1[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_1[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_1[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_1[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_1[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_1[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_1[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_2[0] == 1'b1) begin // valid
		case (w_parse_act_unit_2[5:4])
			0 : begin
				case (w_parse_act_unit_2[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_2[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_2[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_2[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_2[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_2[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_2[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_2[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_2[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_2[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_2[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_2[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_2[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_2[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_2[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_2[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_2[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_2[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_2[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_2[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_2[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_2[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_2[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_2[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_2[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_2[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_2[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_3[0] == 1'b1) begin // valid
		case (w_parse_act_unit_3[5:4])
			0 : begin
				case (w_parse_act_unit_3[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_3[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_3[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_3[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_3[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_3[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_3[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_3[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_3[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_3[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_3[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_3[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_3[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_3[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_3[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_3[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_3[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_3[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_3[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_3[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_3[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_3[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_3[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_3[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_3[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_3[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_3[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_4[0] == 1'b1) begin // valid
		case (w_parse_act_unit_4[5:4])
			0 : begin
				case (w_parse_act_unit_4[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_4[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_4[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_4[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_4[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_4[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_4[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_4[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_4[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_4[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_4[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_4[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_4[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_4[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_4[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_4[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_4[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_4[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_4[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_4[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_4[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_4[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_4[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_4[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_4[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_4[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_4[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_5[0] == 1'b1) begin // valid
		case (w_parse_act_unit_5[5:4])
			0 : begin
				case (w_parse_act_unit_5[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_5[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_5[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_5[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_5[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_5[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_5[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_5[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_5[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_5[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_5[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_5[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_5[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_5[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_5[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_5[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_5[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_5[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_5[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_5[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_5[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_5[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_5[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_5[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_5[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_5[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_5[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_6[0] == 1'b1) begin // valid
		case (w_parse_act_unit_6[5:4])
			0 : begin
				case (w_parse_act_unit_6[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_6[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_6[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_6[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_6[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_6[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_6[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_6[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_6[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_6[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_6[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_6[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_6[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_6[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_6[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_6[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_6[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_6[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_6[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_6[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_6[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_6[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_6[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_6[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_6[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_6[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_6[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_7[0] == 1'b1) begin // valid
		case (w_parse_act_unit_7[5:4])
			0 : begin
				case (w_parse_act_unit_7[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_7[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_7[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_7[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_7[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_7[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_7[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_7[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_7[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_7[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_7[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_7[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_7[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_7[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_7[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_7[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_7[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_7[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_7[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_7[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_7[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_7[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_7[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_7[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_7[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_7[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_7[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_8[0] == 1'b1) begin // valid
		case (w_parse_act_unit_8[5:4])
			0 : begin
				case (w_parse_act_unit_8[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_8[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_8[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_8[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_8[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_8[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_8[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_8[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_8[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_8[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_8[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_8[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_8[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_8[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_8[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_8[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_8[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_8[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_8[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_8[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_8[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_8[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_8[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_8[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_8[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_8[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_8[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
	if (w_parse_act_unit_9[0] == 1'b1) begin // valid
		case (w_parse_act_unit_9[5:4])
			0 : begin
				case (w_parse_act_unit_9[3:1])
					0: begin
						r_off_con_2B_0[7] = 1'b1;
						r_off_con_2B_0[6:0] = w_parse_act_unit_9[12:6];
					end
					1: begin
						r_off_con_2B_1[7] = 1'b1;
						r_off_con_2B_1[6:0] = w_parse_act_unit_9[12:6];
					end
					2: begin
						r_off_con_2B_2[7] = 1'b1;
						r_off_con_2B_2[6:0] = w_parse_act_unit_9[12:6];
					end
					3: begin
						r_off_con_2B_3[7] = 1'b1;
						r_off_con_2B_3[6:0] = w_parse_act_unit_9[12:6];
					end
					4: begin
						r_off_con_2B_4[7] = 1'b1;
						r_off_con_2B_4[6:0] = w_parse_act_unit_9[12:6];
					end
					5: begin
						r_off_con_2B_5[7] = 1'b1;
						r_off_con_2B_5[6:0] = w_parse_act_unit_9[12:6];
					end
					6: begin
						r_off_con_2B_6[7] = 1'b1;
						r_off_con_2B_6[6:0] = w_parse_act_unit_9[12:6];
					end
					7: begin
						r_off_con_2B_7[7] = 1'b1;
						r_off_con_2B_7[6:0] = w_parse_act_unit_9[12:6];
					end
					default: begin
						r_off_con_2B_0 = 0; r_off_con_2B_1 = 0; r_off_con_2B_2 = 0; r_off_con_2B_3 = 0;
						r_off_con_2B_4 = 0; r_off_con_2B_5 = 0; r_off_con_2B_6 = 0; r_off_con_2B_7 = 0;
					end
				endcase
			end
			1 : begin
				case (w_parse_act_unit_9[3:1])
					0: begin
						r_off_con_4B_0[7] = 1'b1;
						r_off_con_4B_0[6:0] = w_parse_act_unit_9[12:6];
					end
					1: begin
						r_off_con_4B_1[7] = 1'b1;
						r_off_con_4B_1[6:0] = w_parse_act_unit_9[12:6];
					end
					2: begin
						r_off_con_4B_2[7] = 1'b1;
						r_off_con_4B_2[6:0] = w_parse_act_unit_9[12:6];
					end
					3: begin
						r_off_con_4B_3[7] = 1'b1;
						r_off_con_4B_3[6:0] = w_parse_act_unit_9[12:6];
					end
					4: begin
						r_off_con_4B_4[7] = 1'b1;
						r_off_con_4B_4[6:0] = w_parse_act_unit_9[12:6];
					end
					5: begin
						r_off_con_4B_5[7] = 1'b1;
						r_off_con_4B_5[6:0] = w_parse_act_unit_9[12:6];
					end
					6: begin
						r_off_con_4B_6[7] = 1'b1;
						r_off_con_4B_6[6:0] = w_parse_act_unit_9[12:6];
					end
					7: begin
						r_off_con_4B_7[7] = 1'b1;
						r_off_con_4B_7[6:0] = w_parse_act_unit_9[12:6];
					end
					default: begin
						r_off_con_4B_0 = 0; r_off_con_4B_1 = 0; r_off_con_4B_2 = 0; r_off_con_4B_3 = 0;
						r_off_con_4B_4 = 0; r_off_con_4B_5 = 0; r_off_con_4B_6 = 0; r_off_con_4B_7 = 0;
					end
				endcase
			end
			2 : begin
				case (w_parse_act_unit_9[3:1])
					0: begin
						r_off_con_8B_0[7] = 1'b1;
						r_off_con_8B_0[6:0] = w_parse_act_unit_9[12:6];
					end
					1: begin
						r_off_con_8B_1[7] = 1'b1;
						r_off_con_8B_1[6:0] = w_parse_act_unit_9[12:6];
					end
					2: begin
						r_off_con_8B_2[7] = 1'b1;
						r_off_con_8B_2[6:0] = w_parse_act_unit_9[12:6];
					end
					3: begin
						r_off_con_8B_3[7] = 1'b1;
						r_off_con_8B_3[6:0] = w_parse_act_unit_9[12:6];
					end
					4: begin
						r_off_con_8B_4[7] = 1'b1;
						r_off_con_8B_4[6:0] = w_parse_act_unit_9[12:6];
					end
					5: begin
						r_off_con_8B_5[7] = 1'b1;
						r_off_con_8B_5[6:0] = w_parse_act_unit_9[12:6];
					end
					6: begin
						r_off_con_8B_6[7] = 1'b1;
						r_off_con_8B_6[6:0] = w_parse_act_unit_9[12:6];
					end
					7: begin
						r_off_con_8B_7[7] = 1'b1;
						r_off_con_8B_7[6:0] = w_parse_act_unit_9[12:6];
					end
					default: begin
						r_off_con_8B_0 = 0; r_off_con_8B_1 = 0; r_off_con_8B_2 = 0; r_off_con_8B_3 = 0;
						r_off_con_8B_4 = 0; r_off_con_8B_5 = 0; r_off_con_8B_6 = 0; r_off_con_8B_7 = 0;
					end
				endcase
			end
		endcase
	end
end

always @(posedge axis_clk) begin
	if (~aresetn) begin
		// 
		parse_state <= IDLE;
		//
		initial_state <= 'hf;
		parser_valid <= 0;
	end
	else begin
		case (parse_state)
			IDLE: begin
				if (pkt_cnt>=C_VALID_NUM_HDR_PKTS || w_tlast==1'b1) begin
					if (eth_type==`TYPE_IPV4 && ip_prot==`PROT_UDP) begin
						parse_state <= START_PARSE;

						initial_state <= vlan_hdr[27:24];
					end
				end
			end
			START_PARSE: begin
				if (match_d1==1'b1) begin // act_data_out is also valid now
					//
					parser_valid <= 1;
					// state transition
					parse_state <= DONE_PARSE;
				end
			end
			DONE_PARSE: begin
				//
				parse_state <= IDLE;
				//
				initial_state <= 'hf;
				parser_valid <= 0;
			end
		endcase
	end
end

// 1024, 7, 24*8, 512
assign pkt_hdr_vec = {w_pkts,
					r_tot_length,
					r_off_con_2B_0,
					r_off_con_2B_1,
					r_off_con_2B_2,
					r_off_con_2B_3,
					r_off_con_2B_4,
					r_off_con_2B_5,
					r_off_con_2B_6,
					r_off_con_2B_7,
					r_off_con_4B_0,
					r_off_con_4B_1,
					r_off_con_4B_2,
					r_off_con_4B_3,
					r_off_con_4B_4,
					r_off_con_4B_5,
					r_off_con_4B_6,
					r_off_con_4B_7,
					r_off_con_8B_0,
					r_off_con_8B_1,
					r_off_con_8B_2,
					r_off_con_8B_3,
					r_off_con_8B_4,
					r_off_con_8B_5,
					r_off_con_8B_6,
					r_off_con_8B_7,
					r_cond_blk_0,	// conditional block
					r_cond_blk_1,
					r_cond_blk_2,
					r_cond_blk_3,
					r_cond_blk_4,
					{128{1'b0}},
					tuser_1st};

// update TCAM match signal
always @(posedge axis_clk) begin
	if (~aresetn) begin
		match_d1 <= 0;
	end
	else begin
		match_d1 <= match;
	end
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
	.CMP_DIN			(initial_state),
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
ram267x16 # (
	.RAM_INIT_FILE ("parse_act_ram_init_file.mif")
)
act_ram
(
	.axi_clk		(),
	.axi_wr_en		(),
	.axi_rd_en		(),
	.axi_wr_addr	(),
	.axi_rd_addr	(),
	.axi_data_in	(),
	.axi_data_out	(),

	.axis_clk		(axis_clk),
	.axis_rd_en		(1'b1),				// always set to 1 for reading
	.axis_rd_addr	(match_addr),
	.axis_data_out	(parse_act_data_out)
);


endmodule
