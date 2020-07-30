`timescale 1ns / 1ps



module ram167x16 # (
	parameter RAM_INIT_FILE = ""
)
(
	// axi, update
	input								axi_clk,
	input								axi_wr_en,
	input								axi_rd_en,
	input [3:0]							axi_wr_addr,
	input [3:0]							axi_rd_addr,
	input [166:0]						axi_data_in,
	output [166:0]					axi_data_out,
	// axis, read
	input								axis_clk,
	input								axis_rd_en,
	input [3:0]							axis_rd_addr,
	output [166:0]					axis_data_out
);

reg [166:0] mem[0:15];
reg [166:0] axi_data_out_reg;
reg [166:0] axis_data_out_reg;

// I/O connection
assign axi_data_out = axi_data_out_reg;
assign axis_data_out = axis_data_out_reg;

// process axi update req
always @(posedge axi_clk) begin
	if (axi_wr_en == 1'b1)
		mem[axi_wr_addr] <= axi_data_in;
	if (axi_rd_en == 1'b1)
		axi_data_out_reg <= mem[axi_rd_addr];
end

// process axis read req
always @(posedge axis_clk) begin
	if (axis_rd_en == 1'b1)
		axis_data_out_reg <= mem[axis_rd_addr];
end

initial begin
	if (RAM_INIT_FILE != "") begin
		$readmemh(RAM_INIT_FILE, mem);
	end
end


endmodule
