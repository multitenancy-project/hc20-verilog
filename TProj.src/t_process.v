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

/*=================================================*/
localparam PKT_VEC_WIDTH = (6+4+2)*8*8+20*5+256;
// pkt fifo
reg									pkt_fifo_rd_en;
wire								pkt_fifo_nearly_full;
wire								pkt_fifo_empty;
wire [C_S_AXIS_DATA_WIDTH-1:0]		tdata_fifo;
wire [C_S_AXIS_TUSER_WIDTH-1:0]		tuser_fifo;
wire [C_S_AXIS_DATA_WIDTH/8-1:0]	tkeep_fifo;
wire								tlast_fifo;
// phv fifo
reg									phv_fifo_rd_en;
wire								phv_fifo_nearly_full;
wire								phv_fifo_empty;
wire [PKT_VEC_WIDTH-1:0]			phv_fifo_in;
wire [PKT_VEC_WIDTH-1:0]			phv_fifo_out;
//
wire								phv_valid;

/*=================================================*/
assign s_axis_tready = !pkt_fifo_nearly_full;


fallthrough_small_fifo #(
	.WIDTH(C_S_AXIS_DATA_WIDTH + C_S_AXIS_TUSER_WIDTH + C_S_AXIS_DATA_WIDTH/8 + 1),
	.MAX_DEPTH_BITS(8)
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
	.MAX_DEPTH_BITS(8)
)
phv_fifo
(
	.din			(phv_fifo_in),
	.wr_en			(phv_valid),
	.rd_en			(phv_fifo_rd_en),
	.dout			(phv_fifo_out),
	.full			(),
	.prog_full		(),
	.nearly_full	(phv_fifo_nearly_full),
	.empty			(phv_fifo_empty),
	.reset			(~aresetn),
	.clk			(clk)
);

packet_header_parser
phv_parser
(
	.axis_clk		(clk),
	.aresetn		(aresetn),
	// input slvae axi stream
	.s_axis_tdata	(s_axis_tdata),
	.s_axis_tuser	(s_axis_tuser),
	.s_axis_tkeep	(s_axis_tkeep),
	.s_axis_tvalid	(s_axis_tvalid & s_axis_tready),
	.s_axis_tlast	(s_axis_tlast),

	// output
	.parser_valid	(phv_valid),
	.pkt_hdr_vec	(phv_fifo_in)
);

localparam WAIT_TILL_PARSE_DONE = 0, FLUSH_PKT = 1;

reg [2:0] state, state_next;

always @(*) begin
	m_axis_tdata = tdata_fifo;
	m_axis_tuser = tuser_fifo;
	m_axis_tkeep = tkeep_fifo;
	m_axis_tlast = tlast_fifo;

	// 
	m_axis_tvalid = 0;
	pkt_fifo_rd_en = 0;
	phv_fifo_rd_en = 0;

	state_next = state;
	//
	case (state)
		WAIT_TILL_PARSE_DONE: begin
			if (!pkt_fifo_empty && !phv_fifo_empty) begin // both pkt and phv fifo are not empty
				m_axis_tvalid = 1;
				m_axis_tdata = tdata_fifo;
				m_axis_tuser[31:24] = 8'h04; // for any packet, output to port 1
				if (m_axis_tready) begin // we can downstream pkt, the 1st packet
					pkt_fifo_rd_en = 1;
					phv_fifo_rd_en = 1;
					state_next = FLUSH_PKT;
				end
			end
		end
		FLUSH_PKT: begin
			if (!pkt_fifo_empty) begin
				m_axis_tvalid = 1;
				if(m_axis_tready) begin
					pkt_fifo_rd_en = 1;
					if (tlast_fifo) begin
						state_next = WAIT_TILL_PARSE_DONE;
					end
					else begin
						state_next = FLUSH_PKT;
					end
				end
			end
		end
	endcase
end

always @(posedge clk) begin
	if (~aresetn) begin
		state <= WAIT_TILL_PARSE_DONE;
	end
	else begin
		state <= state_next;
	end
end

endmodule
