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
	output [C_S_AXIS_DATA_WIDTH-1:0]		m_axis_tdata,
	output [((C_S_AXIS_DATA_WIDTH/8))-1:0]	m_axis_tkeep,
	output [C_S_AXIS_TUSER_WIDTH-1:0]		m_axis_tuser,
	output									m_axis_tvalid,
	input									m_axis_tready,
	output									m_axis_tlast

	// for debug use
	
);

packet_header_parser
parser (
	// clk
	.axis_clk								(CLK_156),
	.aresetn								(ARESETN_156),

	// input axis data
	.s_axis_tdata							(s_axis_tdata),
	.s_axis_tvalid							(s_axis_tvalid & s_axis_tready),
	.s_axis_tlast							(s_axis_tlast)
);





// Some code snippet for self-defined AXI Lite Master and Slvae communication
/*
wire wr_en;
wire rd_en;
wire [3:0] addr;
wire [31:0] wr_data;
wire init_txn;
wire txn_done;
wire error;

wire [PHV_ADDR_WIDTH-1:0]				axi_awaddr;
wire									axi_awvalid;
wire [C_S_AXI_DATA_WIDTH-1:0]			axi_wdata;
wire [C_S_AXI_DATA_WIDTH/8-1:0]			axi_wstrb;
wire									axi_wvalid;
wire									axi_bready;
wire [PHV_ADDR_WIDTH-1:0]				axi_araddr;
wire									axi_arvalid;
wire									axi_rready;
wire									axi_arready;
wire [C_S_AXI_DATA_WIDTH-1:0]			axi_rdata;
wire [1:0]								axi_rresp;
wire									axi_rvalid;
wire									axi_wready;
wire [1:0]								axi_bresp;
wire									axi_bvalid;
wire									axi_awready;
// not used signals
wire [2:0]								axi_awprot;
wire [2:0]								axi_arprot;

axi_lite_master 
axilite_master0 (
	.wr_en				(wr_en),
	.rd_en				(rd_en),
	.addr				(addr),
	.wr_data			(wr_data),
	.txn_done			(txn_done),
	//
	.INIT_AXI_TXN		(init_txn),
	.ERROR				(error),
	.M_AXI_ACLK			(CLK_156),
	.M_AXI_ARESETN		(ARESETN_156),
	.M_AXI_AWADDR		(axi_awaddr),
	.M_AXI_AWPROT		(axi_awprot),
	.M_AXI_AWVALID		(axi_awvalid),
	.M_AXI_AWREADY		(axi_awready),
	.M_AXI_WDATA		(axi_wdata),
	.M_AXI_WSTRB		(axi_wstrb),
	.M_AXI_WVALID		(axi_wvalid),
	.M_AXI_WREADY		(axi_wready),
	.M_AXI_BRESP		(axi_bresp),
	.M_AXI_BVALID		(axi_bvalid),
	.M_AXI_ARADDR		(axi_araddr),
	.M_AXI_ARPROT		(axi_arprot),
	.M_AXI_ARVALID		(axi_arvalid),
	.M_AXI_ARREADY		(axi_arready),
	.M_AXI_RDATA		(axi_rdata),
	.M_AXI_RRESP		(axi_rresp),
	.M_AXI_RVALID		(axi_rvalid),
	.M_AXI_RREADY		(axi_rready)
);

axi_lite_slave
axilite_slave0 (
	.S_AXI_ACLK			(CLK_156),
	.S_AXI_ARESETN		(ARESETN_156),
	.S_AXI_AWADDR		(axi_awaddr),
	.S_AXI_AWPROT		(axi_awprot),
	.S_AXI_AWVALID		(axi_awvalid),
	.S_AXI_AWREADY		(axi_awready),
	.S_AXI_WDATA		(axi_wdata),
	.S_AXI_WSTRB		(axi_wstrb),
	.S_AXI_WVALID		(axi_wvalid),
	.S_AXI_WREADY		(axi_wready),
	.S_AXI_BRESP		(axi_bresp),
	.S_AXI_BVALID		(axi_bvalid),
	.S_AXI_ARADDR		(axi_araddr),
	.S_AXI_ARPROT		(axi_arprot),
	.S_AXI_ARVALID		(axi_arvalid),
	.S_AXI_ARREADY		(axi_arready),
	.S_AXI_RDATA		(axi_rdata),
	.S_AXI_RRESP		(axi_rresp),
	.S_AXI_RVALID		(axi_rvalid),
	.S_AXI_RREADY		(axi_rready)
);
*/


// simulate
//
//
/*
reg reg_wr_en, reg_rd_en;
reg [3:0] reg_addr;
reg [31:0] reg_wr_data;
reg reg_init_txn;

assign wr_en = reg_wr_en;
assign rd_en = reg_rd_en;
assign addr = reg_addr;
assign wr_data = reg_wr_data;
assign init_txn = reg_init_txn;

initial
begin
#3000	reg_wr_en = 1; reg_init_txn = 1; reg_addr = 3; reg_wr_data = 3;
#100 reg_wr_en = ~reg_wr_en; reg_init_txn = ~reg_init_txn; 
#100 reg_rd_en = 1; reg_init_txn = 1; reg_addr = 3;
#100 reg_rd_en = ~reg_rd_en; reg_init_txn = ~reg_init_txn;

end
*/

endmodule
