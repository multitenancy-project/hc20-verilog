/*
Filename: sync_sig.v
Dscription: 
	1)synchronize signal to Des Clock filed
	2)

Author : lxj
Revision List（修订列表）:
	rn1:	date: 2017/04/13	modifier: lxj
 	description: modify the out_sig's detect, as the older out_sig just synchronize the rise edge, but not the fall edge
                 so if user maybe cause error if use it for fall edge process
	rn2:	date:	modifier:	description:
	rn3:	date:	modifier:	description:
*/
`timescale 1 ns / 1 ps
module sync_sig(
	input clk,
	input rst_n,
	input in_sig,
	output reg out_sig
);
parameter SHIFT_WIDTH = 2;

reg[SHIFT_WIDTH-1:0] sig_dly;

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		sig_dly <= {SHIFT_WIDTH{1'b0}};
	end
	else begin//Sync signal
		sig_dly[0] <= in_sig;
		sig_dly[SHIFT_WIDTH-1:1] <= sig_dly[SHIFT_WIDTH-2:0];
  end
end

always @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		out_sig <= 1'b0;
	end
	else begin//Sync signal
		if((|sig_dly) == 1'b0) begin
            out_sig <= 1'b0;
        end
        else if((&sig_dly) == 1'b1) begin
            out_sig <= 1'b1;
        end
        else begin
            out_sig <= out_sig;
        end
  end
end

endmodule