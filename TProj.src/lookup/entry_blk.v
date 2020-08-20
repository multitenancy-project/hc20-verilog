////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
//////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version: 0.1
//Filename: entry_blk.v
//Target Device: 
//Dscription: 
//  1)
//  2)
//
//Author : 
//Revision List:
//	rn2:	date:	modifier:	description:
//	rn2:	date:	modifier:	description:
//
module entry_blk(
    input  wire          clk,//add module's work clk domin
    input  wire          rst_n,

 input  wire [7:0]    entry_id,

 input  wire          cfg2entry_cs_n,//low active
 input  wire          cfg2entry_wr_rd,//0 write 1:read
 output reg           entry2cfg_ack_n,//low active
 input  wire [5:0]    cfg2entry_addr,
 input  wire [31:0]   cfg2entry_wdata,
 output reg  [31:0]   entry2cfg_rdata,

 input  wire          key_valid,
 input  wire [511:0]  key,

 output reg           hit,
 output reg  [7:0]    prior,
 output wire [7:0]    index
);

//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
reg  [511:0] entry;
reg  [511:0] mask;
reg          entry_valid;

reg  [1:0]   entry_state;

localparam   IDLE_S  = 2'd0,
             WRITE_S = 2'd1,
             READ_S  = 2'd2,
             ACK_S   = 2'd3;
//***************************************************
//                Entry Config
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        entry <= 512'b0;
        mask <= 512'b0;
        prior <= 8'b0;
        entry_valid <= 1'b0;
        
        entry2cfg_ack_n <= 1'b1;
        entry2cfg_rdata <= 32'b0;
        entry_state <= IDLE_S;
    end
    else begin
        case(entry_state)
            IDLE_S: begin
                entry2cfg_ack_n <= 1'b1;
                if(cfg2entry_cs_n == 1'b0)begin
                    if(cfg2entry_wr_rd == 1'b0) begin//write
                        entry_state <= WRITE_S;
                    end
                    else begin
                        entry_state <= READ_S;
                    end
                end
                else begin
                    entry_state <= IDLE_S;
                end
            end
            
            WRITE_S: begin
                case(cfg2entry_addr[5:0])
                    6'h00: entry[32*0+31:32*0]   <= cfg2entry_wdata;
                    6'h01: entry[32*1+31:32*1]   <= cfg2entry_wdata;
                    6'h02: entry[32*2+31:32*2]   <= cfg2entry_wdata;
                    6'h03: entry[32*3+31:32*3]   <= cfg2entry_wdata;
                    6'h04: entry[32*4+31:32*4]   <= cfg2entry_wdata;
                    6'h05: entry[32*5+31:32*5]   <= cfg2entry_wdata;
                    6'h06: entry[32*6+31:32*6]   <= cfg2entry_wdata;
                    6'h07: entry[32*7+31:32*7]   <= cfg2entry_wdata;
                    6'h08: entry[32*8+31:32*8]   <= cfg2entry_wdata;
                    6'h09: entry[32*9+31:32*9]   <= cfg2entry_wdata;
                    6'h0a: entry[32*10+31:32*10] <= cfg2entry_wdata;
                    6'h0b: entry[32*11+31:32*11] <= cfg2entry_wdata;
                    6'h0c: entry[32*12+31:32*12] <= cfg2entry_wdata;
                    6'h0d: entry[32*13+31:32*13] <= cfg2entry_wdata;
                    6'h0e: entry[32*14+31:32*14] <= cfg2entry_wdata;
                    6'h0f: entry[32*15+31:32*15] <= cfg2entry_wdata;
                    
                    6'h10: mask[32*0+31:32*0]    <= cfg2entry_wdata;
                    6'h11: mask[32*1+31:32*1]    <= cfg2entry_wdata;
                    6'h12: mask[32*2+31:32*2]    <= cfg2entry_wdata;
                    6'h13: mask[32*3+31:32*3]    <= cfg2entry_wdata;
                    6'h14: mask[32*4+31:32*4]    <= cfg2entry_wdata;
                    6'h15: mask[32*5+31:32*5]    <= cfg2entry_wdata;
                    6'h16: mask[32*6+31:32*6]    <= cfg2entry_wdata;
                    6'h17: mask[32*7+31:32*7]    <= cfg2entry_wdata;
                    6'h18: mask[32*8+31:32*8]    <= cfg2entry_wdata;
                    6'h19: mask[32*9+31:32*9]    <= cfg2entry_wdata;
                    6'h1a: mask[32*10+31:32*10]  <= cfg2entry_wdata;
                    6'h1b: mask[32*11+31:32*11]  <= cfg2entry_wdata;
                    6'h1c: mask[32*12+31:32*12]  <= cfg2entry_wdata;
                    6'h1d: mask[32*13+31:32*13]  <= cfg2entry_wdata;
                    6'h1e: mask[32*14+31:32*14]  <= cfg2entry_wdata;
                    6'h1f: mask[32*15+31:32*15]  <= cfg2entry_wdata;
                    
                    6'h20: prior                 <= cfg2entry_wdata[7:0];
                    6'h21: entry_valid           <= cfg2entry_wdata[0];
                    default: begin
                        entry <= entry;
                        mask <= mask;
                        prior <= prior;
                        entry_valid <= entry_valid;
                    end
                endcase
                entry_state <= ACK_S;
            end
            
            READ_S: begin
                case(cfg2entry_addr[5:0])
                    6'h00: entry2cfg_rdata <= entry[32*0+31:32*0];
                    6'h01: entry2cfg_rdata <= entry[32*1+31:32*1];
                    6'h02: entry2cfg_rdata <= entry[32*2+31:32*2];
                    6'h03: entry2cfg_rdata <= entry[32*3+31:32*3];
                    6'h04: entry2cfg_rdata <= entry[32*4+31:32*4];
                    6'h05: entry2cfg_rdata <= entry[32*5+31:32*5];
                    6'h06: entry2cfg_rdata <= entry[32*6+31:32*6];
                    6'h07: entry2cfg_rdata <= entry[32*7+31:32*7];
                    6'h08: entry2cfg_rdata <= entry[32*8+31:32*8];
                    6'h09: entry2cfg_rdata <= entry[32*9+31:32*9];
                    6'h0a: entry2cfg_rdata <= entry[32*10+31:32*10];
                    6'h0b: entry2cfg_rdata <= entry[32*11+31:32*11];
                    6'h0c: entry2cfg_rdata <= entry[32*12+31:32*12];
                    6'h0d: entry2cfg_rdata <= entry[32*13+31:32*13];
                    6'h0e: entry2cfg_rdata <= entry[32*14+31:32*14];
                    6'h0f: entry2cfg_rdata <= entry[32*15+31:32*15];
                           
                    6'h10: entry2cfg_rdata <= mask[32*0+31:32*0];
                    6'h11: entry2cfg_rdata <= mask[32*1+31:32*1];
                    6'h12: entry2cfg_rdata <= mask[32*2+31:32*2];
                    6'h13: entry2cfg_rdata <= mask[32*3+31:32*3];
                    6'h14: entry2cfg_rdata <= mask[32*4+31:32*4];
                    6'h15: entry2cfg_rdata <= mask[32*5+31:32*5];
                    6'h16: entry2cfg_rdata <= mask[32*6+31:32*6];
                    6'h17: entry2cfg_rdata <= mask[32*7+31:32*7];
                    6'h18: entry2cfg_rdata <= mask[32*8+31:32*8];
                    6'h19: entry2cfg_rdata <= mask[32*9+31:32*9];
                    6'h1a: entry2cfg_rdata <= mask[32*10+31:32*10];
                    6'h1b: entry2cfg_rdata <= mask[32*11+31:32*11];
                    6'h1c: entry2cfg_rdata <= mask[32*12+31:32*12];
                    6'h1d: entry2cfg_rdata <= mask[32*13+31:32*13];
                    6'h1e: entry2cfg_rdata <= mask[32*14+31:32*14];
                    6'h1f: entry2cfg_rdata <= mask[32*15+31:32*15];
                    
                    6'h20: entry2cfg_rdata <= {56'b0,prior};
                    6'h21: entry2cfg_rdata <= {63'b0,entry_valid};
                    default: begin
                        entry <= entry;
                        mask <= mask;
                        prior <= prior;
                        entry_valid <= entry_valid;
                    end
                endcase
                entry_state <= ACK_S;
            end
            
            ACK_S: begin
                if(cfg2entry_cs_n == 1'b0)begin
                    entry2cfg_ack_n <= 1'b0;
                    entry_state <= ACK_S;
                end
                else begin
                    entry2cfg_ack_n <= 1'b1;
                    entry_state <= IDLE_S;
                end
            end
            
            default: begin
                entry <= 512'b0;
                mask <= 512'b0;
                entry_valid <= 1'b0;
                
                entry2cfg_ack_n <= 1'b1;
                entry2cfg_rdata <= 32'b0;
                entry_state <= IDLE_S;
            end
        endcase
    end
end

//***************************************************
//                Entry Lookup
//***************************************************
assign index = entry_id;

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        hit <= 1'b0;
    end
    else begin
        if((key_valid == 1'b1) && (entry_valid == 1'b1)) begin
            if(((entry ^ key) & mask) == 512'b0) begin
                hit <= 1'b1;
            end
            else begin
                hit <= 1'b0;
            end
        end
        else begin
            hit <= 1'b0;
        end
    end
end

endmodule
/*
entry_blk entry_blk_inst(
    .clk(),//add module's work clk domin
    .rst_n(),

    .entry_id(),

    .cfg2entry_cs_n(),//low active
    .cfg2entry_wr_rd(),//0 write 1:read
    .entry2cfg_ack_n(),//low active
    .cfg2entry_addr(),
    .cfg2entry_wdata(),
    .entry2cfg_rdata(),

    .key_valid(),
    .key(),

    .hit(),
    .prior(),
    .index()
);
*/