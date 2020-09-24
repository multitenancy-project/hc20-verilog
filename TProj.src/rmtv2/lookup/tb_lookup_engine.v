`timescale 1ns / 1ps

module tb_lookup_engine #(
    parameter KEY_LEN = 896,
    parameter MASK_LEN = 896,
    parameter PHV_LEN = 1024+7+24*8+5*20+256,
    parameter ACTION_LEN = 25
)();

localparam STAGE_P = 0;
reg clk;
reg rst_n;

reg [KEY_LEN-1:0]       extract_key;
reg                     key_valid;
reg                     cond_flag;
reg [PHV_LEN-1:0]       pkt_hdr_vec;

wire [ACTION_LEN-1:0]   action;
wire                    action_valid;
wire [PHV_LEN-1:0]      pkt_hdr_vec_out;

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
    key_valid <= 1'b1;
    cond_flag <= 1'b1;
    extract_key <= {8'hff, 888'h0};
    pkt_hdr_vec <= {4'b1111, 1020'b0, 7'b0, 8'b0, 184'b0, 356'b0};
    #CYCLE 
    key_valid <= 1'b0;
    cond_flag <= 1'b0;
    extract_key <= 896'b1;
    pkt_hdr_vec <= 1579'b0;
    #(3*CYCLE)

    /* 
        TODO hit
    */
    key_valid <= 1'b1;
    cond_flag <= 1'b1;
    extract_key <= {8'hff, 888'h0};
    pkt_hdr_vec <= {4'b1111, 1020'b0, 7'b0, 8'b0, 184'b0, 356'b0};
    #CYCLE
    key_valid <= 1'b0;
    cond_flag <= 1'b0;
    extract_key <= 896'b1;
    pkt_hdr_vec <= 1579'b0;
    #(4*CYCLE);

    /* 
        TODO miss
    */
    key_valid <= 1'b1;
    cond_flag <= 1'b1;
    extract_key <= 896'b11;
    pkt_hdr_vec <= {4'b1111, 1020'b0, 7'b0, 8'b0, 184'b0, 356'b0};
    #CYCLE
    key_valid <= 1'b0;
    cond_flag <= 1'b0;
    extract_key <= 896'b1;
    pkt_hdr_vec <= 1579'b0;
    #(4*CYCLE);


end


lookup_engine #(
    .STAGE(STAGE_P)
) lookup_engine(
    .axis_clk(clk),
    .aresetn(rst_n),

    //output from key extractor
    .extract_key(extract_key),
    .key_valid(key_valid),
    .cond_flag(cond_flag),
    .pkt_hdr_vec(pkt_hdr_vec),

    //output to the action engine
    .action(action),
    .action_valid(action_valid),
    .pkt_hdr_vec_out(pkt_hdr_vec_out),

    //control channel
    .lookup_din(),
    .lookup_din_mask(),
    .lookup_din_addr(),
    .lookup_din_en(),

    //control channel (action ram)
    .action_data_in(),
    .action_en(),
    .action_addr()
);

endmodule