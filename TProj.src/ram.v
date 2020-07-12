`timescale 1ns / 1ps



module ram16x32 # (
	parameter MEM_INIT_FILE = ""
)
(
	// axi, update
	input				axi_clk,
	input				axi_wr_en,
	input [3:0]			axi_addr,
	input [31:0]		axi_data_in,
	output [31:0]		axi_data_out,
	// axis, read
	input				axis_clk,
	input				axis_wr_en,
	input [3:0]			axis_addr,
	input [31:0]		axis_data_in,
	output [31:0]		axis_data_out
);

reg [31:0] ram[0:15];
reg [31:0] axi_data_out_reg;
reg [31:0] axis_data_out_reg;

// I/O connection
assign axi_data_out = axi_data_out_reg;
assign axis_data_out = axis_data_out_reg;

// process axi update req
always @(posedge axi_clk) begin
	if (axi_wr_en == 1'b1)
		ram[axi_addr] <= axi_data_in;
	else // wr_en == 1'b0
		axi_data_out_reg <= ram[axi_addr];
end

// process axis read req
always @(posedge axis_clk) begin
	if (axis_wr_en == 1'b1)
		ram[axis_addr] <= axis_data_in;
	else // axis_wr_en == 1'b0
		axis_data_out_reg <= ram[axis_addr];
end

initial begin
	if (MEM_INIT_FILE != "") begin
		$readmemh(MEM_INIT_FILE, ram);
	end
end


endmodule
