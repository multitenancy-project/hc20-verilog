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
	input									CLK_156,		// axis clk
	input									ARESETN_156,	
	input									CLK_1XX,
	input									ARESETN_1XX,

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
integer idx;
//
function [255:0] pad_suffix_zeros (
	input [6:0] pos
);
begin
	pad_suffix_zeros = 0;
	for (idx=0; idx<256; idx=idx+1)
		if (idx >= pos)
			pad_suffix_zeros[idx] = 1;
end
endfunction
//
function [255:0] pad_suffix_ones (
	input [6:0] pos
);
begin
	pad_suffix_ones = 0;
	for (idx=0; idx<256; idx=idx+1)
		if (idx < pos)
			pad_suffix_ones[idx] = 1;
end
endfunction

// count number of 1-bit
function [6:0] count_ones (
	input [256/8-1:0] data
);
begin
	count_ones = 0;
	for (idx=0; idx<256/8; idx=idx+1)
		count_ones = count_ones + data[idx];
end
endfunction

//

/*=================================================*/
localparam PKT_VEC_WIDTH = 1024+7+24*8+512;
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
	.reset									(~ARESETN_156),
	.clk									(CLK_156)
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
	.reset									(~ARESETN_156),
	.clk									(CLK_156)
);


packet_header_parser
parser (
	// clk
	.axis_clk								(CLK_156),
	.aresetn								(ARESETN_156),

	// input axis data
	.s_axis_tdata							(s_axis_tdata),
	.s_axis_tkeep							(s_axis_tkeep),
	.s_axis_tvalid							(s_axis_tvalid & s_axis_tready),
	.s_axis_tlast							(s_axis_tlast),
	// output to phv fifo
	.parser_valid							(phv_valid),
	.pkt_hdr_vec							(phv_in)
);

// reassemble the packets
//

localparam TOT_LENGTH_POS = 24*8+512;
localparam PKT_START_POS = 7+TOT_LENGTH_POS;
localparam WAIT_TILL_PARSE_DONE=0, PKT_1=1, PKT_2=2, PKT_3=3, FLUSH_PKT=4;

reg [2:0] state, state_next;
reg [6:0] bytes_cnt, bytes_cnt_next, last_bytes;
wire [6:0] w_tot_length;
wire [1023:0] w_pkt_hdr;

assign w_tot_length = phv_fifo[TOT_LENGTH_POS+:7];
assign w_pkt_hdr = phv_fifo[PKT_START_POS+:1024];

// for debug use
wire [255:0] pkt_0;
wire [255:0] pkt_1;
wire [255:0] pkt_2;
wire [255:0] pkt_3;

assign pkt_0 = w_pkt_hdr[0+:256];
assign pkt_1 = w_pkt_hdr[256+:256];
assign pkt_2 = w_pkt_hdr[512+:256];
assign pkt_3 = w_pkt_hdr[768+:256];
// for debug use

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
	bytes_cnt_next = bytes_cnt;
	last_bytes = 0;

	case (state)
		WAIT_TILL_PARSE_DONE: begin
			if (!pkt_fifo_empty && !phv_empty) begin // both pkt and phv fifo are not empty
				if (m_axis_tready) begin // we can downstream pkt, the 1st packet
					bytes_cnt_next = bytes_cnt+count_ones(tkeep_fifo);

					m_axis_tdata = pkt_0;
					m_axis_tvalid = 1;
					pkt_fifo_rd_en = 1;

					state_next = PKT_1;
				end
			end
		end
		PKT_1: begin
			if (!pkt_fifo_empty && !phv_empty) begin
				if (m_axis_tready) begin // the 2nd segment
					bytes_cnt_next = bytes_cnt+count_ones(tkeep_fifo);

					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
						bytes_cnt_next = 0;
					end
					else
						state_next = PKT_2;

					if (bytes_cnt_next >= w_tot_length) begin
						last_bytes = w_tot_length+count_ones(tkeep_fifo)-bytes_cnt_next;
						m_axis_tdata = (tdata_fifo & pad_suffix_zeros(last_bytes*8)) | (pkt_1 & pad_suffix_ones(last_bytes*8));
						state_next = FLUSH_PKT;
						phv_rd_en = 1;
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
				if (m_axis_tready) begin // the 2nd segment
					bytes_cnt_next = bytes_cnt+count_ones(tkeep_fifo);

					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
						bytes_cnt_next = 0;
					end
					else
						state_next = PKT_3;

					if (bytes_cnt_next >= w_tot_length) begin
						last_bytes = w_tot_length+count_ones(tkeep_fifo)-bytes_cnt_next;
						m_axis_tdata = (tdata_fifo & pad_suffix_zeros(last_bytes*8)) | (pkt_2 & pad_suffix_ones(last_bytes*8));
						state_next = FLUSH_PKT;
						phv_rd_en = 1;
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
				if (m_axis_tready) begin // the 2nd segment
					bytes_cnt_next = bytes_cnt+count_ones(tkeep_fifo);

					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
						bytes_cnt_next = 0;
					end
					else
						state_next = FLUSH_PKT;

					if (bytes_cnt_next >= w_tot_length) begin
						last_bytes = w_tot_length+count_ones(tkeep_fifo)-bytes_cnt_next;
						m_axis_tdata = (tdata_fifo & pad_suffix_zeros(last_bytes*8)) | (pkt_3 & pad_suffix_ones(last_bytes*8));
						state_next = FLUSH_PKT;
						phv_rd_en = 1;
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
			m_axis_tvalid = 1;
			pkt_fifo_rd_en = 1;
			if (tlast_fifo) begin
				state_next = WAIT_TILL_PARSE_DONE;
				bytes_cnt_next = 0;
			end
		end
	endcase
end

always @(posedge CLK_156) begin
	if (~ARESETN_156) begin
		state <= WAIT_TILL_PARSE_DONE;
		bytes_cnt <= 0;
	end
	else begin
		state <= state_next;
		bytes_cnt <= bytes_cnt_next;
	end
end

endmodule
