`timescale 1ns / 1ps

module tb_action_engine #(
    parameter KEY_LEN = 896,
    parameter MASK_LEN = 896,
    parameter PHV_LEN = 1024+7+24*8+5*20+256,
    parameter ACTION_LEN = 25
)();

localparam STAGE_P = 0;
reg clk;
reg rst_n;

reg [ACTION_LEN-1:0] action_in;
reg                  action_in_valid;
reg [PHV_LEN-1:0]    phv_in;

wire [PHV_LEN-1:0]   phv_out;
wire                 phv_out_valid;

//clk signal
localparam CYCLE = 10;

always begin
    #(CYCLE/2) clk = ~clk;
end

//reset signal
initial begin
    clk = 0;
    rst_n = 1;
    #(10);
    rst_n = 0; //reset all the values
    #(10);
    rst_n = 1;
end


initial begin
    #(2*CYCLE); //after the rst_n, start the test
    #(5)    
    action_in_valid <= 1'b1;
    phv_in <= 1579'b10;
    action_in <= 24'b0;
    #CYCLE 
    action_in_valid <= 1'b0;
    action_in <= 25'hff;
    #(2*CYCLE)

    /* 
        test add/sub
    */
    action_in_valid <= 1'b1;
    /***4B[0] = 4B[0] + 4B[1]****/
    action_in <= {4'b0001, 2'b00, 3'b0, 2'b00, 3'b1, 11'b0};
    phv_in <= {4'b1111, 1020'b0, 7'b0, 8'b0, 184'b0, 356'b0};
    #CYCLE
    action_in_valid <= 1'b0;
    phv_in <= 1579'b0;
    #(4*CYCLE);

    /*
        test addi/subi
    */
    action_in_valid <= 1'b1;
    /***4B[0] = 4B[0] + 4B[1]****/
    action_in <= {4'b0011, 2'b00, 3'b0, 16'b11};
    phv_in <= {4'b1111, 1020'b0, 7'b0, 8'b0, 184'b0, 356'b0};
    #CYCLE
    action_in_valid <= 1'b0;
    phv_in <= 1579'b0;
    #(2*CYCLE);


    // /*
    //     TODO test redirect / discard
    // */

    // /*
    //     TODO test store
    // */

    // /*
    //     TODO test load
    // */
end


action_engine #(
    .STAGE(STAGE_P)
) action_engine(
    .axis_clk(clk),
    .aresetn(rst_n),

    //output from lookup engine
    .action_in(action_in),
    .action_in_valid(action_in_valid),
    .phv_in(phv_in),

    //output to the next stage
    .phv_out(phv_out),
    .phv_out_valid(phv_out_valid)
);

endmodule