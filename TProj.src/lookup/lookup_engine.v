`timescale 1ns / 1ps

module lookup_engine #(
    parameter KEY_LEN  = 896,
    parameter MASK_LEN = 896,
    parameter PHV_LEN = 1024+7+24*8+5*20+256,
    parameter STAGE = 0
)
(
    input axis_clk,
    input aresetn,

    //output from key extractor
    input [KEY_LEN-1:0]           extract_key,
    input                         key_valid,
    input                         cond_flag,
    input [PHV_LEN-1:0]           pkt_hdr_vec,

    //output to the action engine
    output reg [24:0]             action,
    output reg                    action_valid,
    output reg [PHV_LEN-1:0]      pkt_hdr_vec_out, 

    //control channel
    input [1023:0]                lookup_din,
    input [1023:0]                lookup_din_mask,
    input [3:0]                   lookup_din_addr,
    input                         lookup_din_en,

    //control channel (action ram)
    input [24:0]                  action_data_in,
    input                         action_en,
    input [3:0]                   action_addr
);

/********intermediate variables declared here********/
wire        busy            [0:1];
wire [3:0]  match_addr      [0:1];
wire        match           [0:1];

wire [24:0] action_wire;


reg [PHV_LEN-1:0] phv_reg;
reg [1:0] lookup_state;
/********intermediate variables declared here********/



//here, the output should be controlled.
localparam IDLE_S = 2'd0,
           WAIT1_S = 2'd1,
           WAIT2_S = 2'd2,
           TRANS_S = 2'd3;

always @(posedge axis_clk or negedge aresetn) begin
    if (~aresetn) begin
        phv_reg <= 1579'b0;
        lookup_state <= IDLE_S;
    end

    else begin
        case(lookup_state)
            IDLE_S: begin
                //wait 3 cycles
                action_valid <= 1'b0;
                if(key_valid == 1'b1) begin
                    phv_reg <= pkt_hdr_vec;
                    lookup_state <= WAIT1_S;
                end
                else begin
                    lookup_state <= IDLE_S;
                end
            end

            WAIT1_S: begin
                //TCAM missed
                if((match[0] || match[1]) == 1'b0) begin

                    action <= 25'h3f; //0x3f represents default action
                    action_valid <= 1'b1;
                    pkt_hdr_vec_out <= phv_reg;

                    lookup_state <= IDLE_S;
                end
                //TCAM hit
                else begin
                    lookup_state <= WAIT2_S;
                end
            end

            //wait a cycle;
            WAIT2_S: begin
                if(match_addr[1] == match_addr[0]) begin
                    lookup_state <= IDLE_S;
                end

                lookup_state <= TRANS_S;
            end

            TRANS_S: begin
                action <= action_wire;
                action_valid <= 1'b1;
                pkt_hdr_vec_out <= phv_reg;

                lookup_state <= IDLE_S;
            end
            
        endcase
        if(key_valid == 1'b1) begin
            phv_reg <= pkt_hdr_vec;
        end
    end
end


//control channel (maybe future?)



// tcam1 for lookup

cam_top # ( 
	.C_DEPTH			(16),
	.C_WIDTH			(512),
	.C_MEM_INIT_FILE	() //currently there is no mem_init
)
//TODO remember to change it back.
cam
(
	.CLK				(axis_clk),
	.CMP_DIN			(extract_key[895:-512]), //feed 896b into 1024b
	.CMP_DATA_MASK		(512'h0),
	.BUSY				(busy[0]),
	.MATCH				(match[0]),
	.MATCH_ADDR			(match_addr[0]),
	//.WE					(lookup_din_en),
	//.WR_ADDR			(lookup_din_addr),
	//.DATA_MASK			(lookup_din_mask),
	//.DIN				(lookup_din),
    .WE                 (),
    .WR_ADDR            (),
    .DATA_MASK          (),
    .DIN                (),
	.EN					(1'b1)
);


// tcam2 for lookup
cam_top # ( 
	.C_DEPTH			(16),
	.C_WIDTH			(385),
	.C_MEM_INIT_FILE	() //currently there is no mem_init
)
//TODO remember to change it back.
cam
(
	.CLK				(axis_clk),
	.CMP_DIN			({extract_key[383:0], cond_flag}), //feed 896b into 1024b
	.CMP_DATA_MASK		(385'h0),
	.BUSY				(busy[1]),
	.MATCH				(match[1]),
	.MATCH_ADDR			(match_addr[1]),

	//.WE					(lookup_din_en),
	//.WR_ADDR			(lookup_din_addr),
	//.DATA_MASK			(lookup_din_mask),
	//.DIN				(lookup_din),
    .WE                 (),
    .WR_ADDR            (),
    .DATA_MASK          (),
    .DIN                (),
	.EN					(1'b1)
);

//ram for action
blk_mem_gen_1 act_ram_25w_16d
(
    .addra(action_addr),
    .clka(axis_clk),
    .dina(action_data_in),
    .ena(1'b1),
    .wea(action_en),
    .addrb(match_addr[0]),
    .clkb(axis_clk),
    .doutb(action_wire),
    .enb(match[0])
);


endmodule