`timescale 1ns / 1ps

module lookup_engine #(
    parameter KEY_LEN  = 896,
    parameter MASK_LEN = 896,
    parameter PKT_HDR_LEN = 1024+7+24*8+5*20+256,
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
wire busy;
wire [3:0] match_addr;
wire match;
wire [24:0] action_wire;


reg [PHV_LEN-1:0] phv_reg;
reg [1:0] lookup_state;
/********intermediate variables declared here********/



//here, the output should be controlled.
localparam IDLE_S = 2'd0,
           WAIT1_S = 2'd1,
           WAIT2_S = 2'd2,
           TRANS_S = 2'd3;

always @(posedge axi_clk or negedge aresetn) begin
    if (~arestn) begin
        phv_reg <= 1579'b0;
        lookup_state <= IDLE_S;
    end

    else begin
        case(lookup_state)
            IDLE_S: begin
                //wait 3 cycles
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
                if(match == 1'b0) begin
                    action <= 24'h0x3f; //0x3f represents default action
                    action_valid <= 1'b0;
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
        //matched, wait 3 cycles and output the result.
        if(match == 1'b1) begin

        end
    end
end


//control channel (maybe future?)


// tcam for lookup
cam_top # ( 
	.C_DEPTH			(16),
	.C_WIDTH			(1024),
	.C_MEM_INIT_FILE	() //currently there is no mem_init
)
cam
(
	.CLK				(axis_clk),
	.CMP_DIN			(extract_key), //feed 896b into 1024b
	.CMP_DATA_MASK		(4'b0000),
	.BUSY				(busy),
	.MATCH				(match),
	.MATCH_ADDR			(match_addr),
	.WE					(lookup_din_en),
	.WR_ADDR			(lookup_din_addr),
	.DATA_MASK			(lookup_din_mask),
	.DIN				(lookup_din),
	.EN					(1'b1)
);

//ram for action
//2 cycles to get action after given match_addr & match
ram1024x16 # (
	//.RAM_INIT_FILE ("parse_act_ram_init_file.mif")
    .RAM_INIT_FILE ()
)
act_ram
(
	.axi_clk		(axis_clk),
	.axi_wr_en		(action_en),
	.axi_rd_en		(),
	.axi_wr_addr	(action_addr),
	.axi_rd_addr	(),
	.axi_data_in	(action_data_in),
	.axi_data_out	(),

	.axis_clk		(axis_clk),
	.axis_rd_en		(match),				// always set to 1 for reading
	.axis_rd_addr	(match_addr),
	.axis_data_out	(action_wire)
);


endmodule