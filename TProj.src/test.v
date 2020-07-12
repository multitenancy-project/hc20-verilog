`timescale 1ns / 1ps


module testbench (
);


reg clk;
reg wr_en;
reg [3:0] addr;
reg [3:0] axis_addr;
reg [31:0] data;
wire [31:0] data_out;
reg [31:0] data_out_dd;

reg [3:0] data_cmp;
wire match;
wire [3:0] match_addr;

// cam
cam_top # (
	.C_DEPTH		(16),
	.C_WIDTH		(4),
	.C_MEM_INIT_FILE	("./cam_init_file.mif")
)
cam
(
	.CLK			(clk),
	.CMP_DIN		(data_cmp),
	.CMP_DATA_MASK	(4'h0),
	.BUSY			(),
	.MATCH			(match),
	.MATCH_ADDR			(match_addr),
	.WE				(),
	.WR_ADDR		(),
	.DATA_MASK		(),
	.DIN			(),
	.EN				(1'b1)
);

// ram
ram16x32 # (
	.MEM_INIT_FILE ("rams_init_file.data")
)
ram
(
	.axi_clk		(clk),
	.axi_wr_en		(wr_en),
	.axi_addr		(addr),
	.axi_data_in	(data),
	.axi_data_out	(),

	.axis_clk		(clk),
	.axis_wr_en		(),
	.axis_addr		(match_addr),
	.axis_data_out	(data_out),
	.axis_data_in	()
);


always
begin
	#1 clk = ~clk;
end


// always @(posedge clk) begin
// 	data_out_dd <= data_out;
// end
// 
// always @(posedge clk) begin
// 	data_cmp <= data_out_dd[3:0];
// end

initial begin
	clk = 0;
	data_cmp = 4'b0001;
	#10 data_cmp = 4'b0010;
	#15 data_cmp = 4'b0011;
	#20 data_cmp = 4'b0100;

	#100 $stop;
end

endmodule
