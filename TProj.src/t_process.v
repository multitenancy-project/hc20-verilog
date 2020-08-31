`timescale 1ns / 1ps

module t_process #(
	// Slave AXI parameters
	parameter C_S_AXI_DATA_WIDTH = 32,
	parameter C_S_AXI_ADDR_WIDTH = 12,
	parameter C_BASEADDR = 32'h80000000,
	// AXI Stream parameters
	// Slave
	parameter C_S_AXIS_DATA_WIDTH = 256,
	parameter C_S_AXIS_TUSER_WIDTH = 128,
	// Master
	parameter C_M_AXIS_DATA_WIDTH = 256,
	// self-defined
	parameter PHV_ADDR_WIDTH = 4
)
(
	input									clk,		// axis clk
	input									aresetn,	

	// input Slave AXI Stream
	input [C_S_AXIS_DATA_WIDTH-1:0]			s_axis_tdata,
	input [((C_S_AXIS_DATA_WIDTH/8))-1:0]	s_axis_tkeep,
	input [C_S_AXIS_TUSER_WIDTH-1:0]		s_axis_tuser,
	input									s_axis_tvalid,
	output									s_axis_tready,
	input									s_axis_tlast,

	// output Master AXI Stream
	output reg [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata,
	output reg [((C_S_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tkeep,
	output reg [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
	output reg									m_axis_tvalid,
	input										m_axis_tready,
	output reg									m_axis_tlast

	// for debug use
	
);

/****** function definitions ******/
//integer idx;
//
//function [255:0] pad_suffix_zeros (
//	input [6:0] pos
//);
//begin
//	pad_suffix_zeros = 0;
//	for (idx=0; idx<256; idx=idx+1)
//		if (idx >= pos)
//			pad_suffix_zeros[idx] = 1;
//end
//endfunction
////
//function [255:0] pad_suffix_ones (
//	input [6:0] pos
//);
//begin
//	pad_suffix_ones = 0;
//	for (idx=0; idx<256; idx=idx+1)
//		if (idx < pos)
//			pad_suffix_ones[idx] = 1;
//end
//endfunction
//
//// count number of 1-bit
//function [6:0] count_ones (
//	input [256/8-1:0] data
//);
//begin
//	count_ones = 0;
//	for (idx=0; idx<256/8; idx=idx+1)
//		count_ones = count_ones + data[idx];
//end
//endfunction
/*==== [END] definitions of functions ====*/

/*=================================================*/
// TODO: pkt vec width may change
localparam PKT_VEC_WIDTH = 1024+7+24*8+20*5+256;
// pkt fifo
reg									pkt_fifo_rd_en;
wire								pkt_fifo_nearly_full;
wire								pkt_fifo_empty;
wire [C_S_AXIS_DATA_WIDTH-1:0]		tdata_fifo;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		tuser_fifo;
wire [C_S_AXIS_DATA_WIDTH/8-1:0]	tkeep_fifo;
wire								tlast_fifo;
// phv fifo
wire								phv_valid;
wire [PKT_VEC_WIDTH-1:0]			phv_in;
wire [PKT_VEC_WIDTH-1:0]			phv_fifo;
reg									phv_rd_en;
wire								phv_empty;
// 

/*=================================================*/
assign s_axis_tready = !pkt_fifo_nearly_full;


fallthrough_small_fifo #(
	.WIDTH(C_S_AXIS_DATA_WIDTH + C_S_AXIS_TUSER_WIDTH + C_S_AXIS_DATA_WIDTH/8 + 1),
	.MAX_DEPTH_BITS(6)
)
pkt_fifo
(
	.din									({s_axis_tdata, s_axis_tuser, s_axis_tkeep, s_axis_tlast}),
	.wr_en									(s_axis_tvalid & ~pkt_fifo_nearly_full),
	.rd_en									(pkt_fifo_rd_en),
	.dout									({tdata_fifo, tuser_fifo, tkeep_fifo, tlast_fifo}),
	.full									(),
	.prog_full								(),
	.nearly_full							(pkt_fifo_nearly_full),
	.empty									(pkt_fifo_empty),
	.reset									(~aresetn),
	.clk									(clk)
);

fallthrough_small_fifo #(
	.WIDTH(PKT_VEC_WIDTH),
	.MAX_DEPTH_BITS(6)
)
paser_done_fifo
(
	.din									(phv_in),
	.wr_en									(phv_valid),
	.rd_en									(phv_rd_en),
	.dout									(phv_fifo),
	.full									(),
	.prog_full								(),
	.nearly_full							(),
	.empty									(phv_empty),
	.reset									(~aresetn),
	.clk									(clk)
);

// for debug use
wire [127:0] phv_fifo_dbg;
assign phv_fifo_dbg = phv_fifo[127:0];
//

packet_header_parser
parser (
	// clk
	.axis_clk								(clk),
	.aresetn								(aresetn),

	// input axis data
	.s_axis_tdata							(s_axis_tdata),
	.s_axis_tuser							(s_axis_tuser),
	.s_axis_tkeep							(s_axis_tkeep),
	.s_axis_tvalid							(s_axis_tvalid & s_axis_tready),
	.s_axis_tlast							(s_axis_tlast),
	// output to phv fifo
	.parser_valid							(phv_valid),
	.pkt_hdr_vec							(phv_in)
);

// reassemble the packets
//
// TODO: the position may change
localparam TOT_LENGTH_POS = 24*8+20*5+256;
localparam PKT_START_POS = 7+TOT_LENGTH_POS;
localparam PKT_START_POS_PKT0 = PKT_START_POS;
localparam PKT_START_POS_PKT1 = PKT_START_POS+256;
localparam PKT_START_POS_PKT2 = PKT_START_POS+512;
localparam PKT_START_POS_PKT3 = PKT_START_POS+768;
localparam WAIT_TILL_PARSE_DONE=0, PKT_1=1, PKT_2=2, PKT_3=3, FLUSH_PKT=4;
//
localparam TRIM_PKT0=0, TRIM_PKT1=1, TRIM_PKT2=2, TRIM_PKT3=3;
localparam ALL_VALID=32'hffff_ffff;

reg [2:0] state, state_next;

reg [255:0] pkt_0, pkt_0_next;
reg [255:0] pkt_1, pkt_1_next;
reg [255:0] pkt_2, pkt_2_next;
reg [255:0] pkt_3, pkt_3_next;
reg [31:0] pkt_keep;
reg [6:0] tot_length, tot_length_next;
//
reg [1:0] trim_case_indicator;

always @(*) begin
	if (tot_length>32 && tot_length<=32*2) begin
		trim_case_indicator = TRIM_PKT1;
		pkt_keep = ALL_VALID << (32*2-tot_length);
	end
	else if (tot_length>32*2 && tot_length<=32*3) begin
		trim_case_indicator = TRIM_PKT2;
		pkt_keep = ALL_VALID << (32*3-tot_length);
	end
	else if (tot_length>32*3 && tot_length<=32*4) begin
		trim_case_indicator = TRIM_PKT3;
		pkt_keep = ALL_VALID << (32*3-tot_length);
	end
	else begin
		trim_case_indicator = TRIM_PKT0; // not valid, may never happen
		pkt_keep = 0;
	end

end

always @(*) begin
	m_axis_tdata = tdata_fifo;
	m_axis_tuser = tuser_fifo;
	m_axis_tkeep = tkeep_fifo;
	m_axis_tlast = tlast_fifo;

	// 
	m_axis_tvalid = 0;
	pkt_fifo_rd_en = 0;
	phv_rd_en = 0;

	//
	state_next = state;
	//
	pkt_0 = phv_fifo[PKT_START_POS_PKT0+:256];
	pkt_1 = phv_fifo[PKT_START_POS_PKT1+:256];
	pkt_2 = phv_fifo[PKT_START_POS_PKT2+:256];
	pkt_3 = phv_fifo[PKT_START_POS_PKT3+:256];
	tot_length_next = phv_fifo[TOT_LENGTH_POS+:7];
	//

	case (state)
		WAIT_TILL_PARSE_DONE: begin
			if (!pkt_fifo_empty && !phv_empty) begin // both pkt and phv fifo are not empty
				if (m_axis_tready) begin // we can downstream pkt, the 1st packet

					m_axis_tdata = pkt_0;
					m_axis_tuser[15:0] = tot_length_next;
					m_axis_tuser[31:24] = 8'h04; // for any packet, output to port 1
					m_axis_tvalid = 1;
					pkt_fifo_rd_en = 1;

					state_next = PKT_1;
				end
			end
		end
		PKT_1: begin
			if (!pkt_fifo_empty && !phv_empty) begin
				if (m_axis_tready) begin // the 2nd segment
					// update state machine
					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
					end
					else begin
						state_next = PKT_2;
					end

					if (trim_case_indicator == TRIM_PKT1) begin
						m_axis_tdata = pkt_1;
						m_axis_tkeep = {pkt_keep[0], pkt_keep[1], pkt_keep[2], pkt_keep[3], pkt_keep[4], pkt_keep[5],
										pkt_keep[6], pkt_keep[7], pkt_keep[8], pkt_keep[9], pkt_keep[10], pkt_keep[11],
										pkt_keep[12], pkt_keep[13], pkt_keep[14], pkt_keep[15], pkt_keep[16], pkt_keep[17],
										pkt_keep[18], pkt_keep[19], pkt_keep[20], pkt_keep[21], pkt_keep[22], pkt_keep[23],
										pkt_keep[24], pkt_keep[25], pkt_keep[26], pkt_keep[27], pkt_keep[28], pkt_keep[29],
										pkt_keep[30], pkt_keep[31] };

						state_next = FLUSH_PKT;
						phv_rd_en = 1;
						m_axis_tlast = 1;
					end
					else begin
						m_axis_tdata = pkt_1;
					end

					m_axis_tvalid= 1;
					pkt_fifo_rd_en = 1;
				end
			end
		end
		PKT_2: begin
			if (!pkt_fifo_empty && !phv_empty) begin
				if (m_axis_tready) begin // the 3nd segment
					// update state machine
					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
					end
					else begin
						state_next = PKT_3;
					end

					if (trim_case_indicator == TRIM_PKT2) begin
						m_axis_tdata = pkt_2;
						m_axis_tkeep = {pkt_keep[0], pkt_keep[1], pkt_keep[2], pkt_keep[3], pkt_keep[4], pkt_keep[5],
										pkt_keep[6], pkt_keep[7], pkt_keep[8], pkt_keep[9], pkt_keep[10], pkt_keep[11],
										pkt_keep[12], pkt_keep[13], pkt_keep[14], pkt_keep[15], pkt_keep[16], pkt_keep[17],
										pkt_keep[18], pkt_keep[19], pkt_keep[20], pkt_keep[21], pkt_keep[22], pkt_keep[23],
										pkt_keep[24], pkt_keep[25], pkt_keep[26], pkt_keep[27], pkt_keep[28], pkt_keep[29],
										pkt_keep[30], pkt_keep[31] };

						state_next = FLUSH_PKT;
						phv_rd_en = 1;
						m_axis_tlast = 1;
					end
					else begin
						m_axis_tdata = pkt_2;
					end

					m_axis_tvalid= 1;
					pkt_fifo_rd_en = 1;
				end
			end
		end
		PKT_3: begin
			if (!pkt_fifo_empty && !phv_empty) begin
				if (m_axis_tready) begin // the 4th segment
					// update state machine
					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
					end
					else begin
						state_next = FLUSH_PKT;
					end

					if (trim_case_indicator == TRIM_PKT3) begin
						m_axis_tdata = pkt_3;
						m_axis_tkeep = {pkt_keep[0], pkt_keep[1], pkt_keep[2], pkt_keep[3], pkt_keep[4], pkt_keep[5],
										pkt_keep[6], pkt_keep[7], pkt_keep[8], pkt_keep[9], pkt_keep[10], pkt_keep[11],
										pkt_keep[12], pkt_keep[13], pkt_keep[14], pkt_keep[15], pkt_keep[16], pkt_keep[17],
										pkt_keep[18], pkt_keep[19], pkt_keep[20], pkt_keep[21], pkt_keep[22], pkt_keep[23],
										pkt_keep[24], pkt_keep[25], pkt_keep[26], pkt_keep[27], pkt_keep[28], pkt_keep[29],
										pkt_keep[30], pkt_keep[31] };

						state_next = FLUSH_PKT;
						phv_rd_en = 1;
						m_axis_tlast = 1;
					end
					else begin
						m_axis_tdata = pkt_3;
					end

					m_axis_tvalid= 1;
					pkt_fifo_rd_en = 1;
				end
			end
		end
		FLUSH_PKT: begin
			state_next = FLUSH_PKT;
			// trim pkt for HW testing, remember to restore it
			m_axis_tvalid = 0;
			// m_axis_tvalid = 1;
			pkt_fifo_rd_en = 1;
			if (tlast_fifo) begin
				state_next = WAIT_TILL_PARSE_DONE;
			end
		end
	endcase
end

always @(posedge clk) begin
	if (~aresetn) begin
		state <= WAIT_TILL_PARSE_DONE;
		//
		tot_length <= 0;
		// trim_case_indicator <= 0;
	end
	else begin
		state <= state_next;
		//
		tot_length <= tot_length_next;
	end
end

endmodule
