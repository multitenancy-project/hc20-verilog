////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version: 0.1
//Filename: lookup.v
//Target Device: 
//Dscription: 
//  1)
//  2)
//
//Author : 
//Revision List:
//	rn2:         switch localbus to AXIL
//  date:  	     2020/08/19
//  modifier:    Xiangrui
//  description: disable the ack mechanism and replace localbus with AXIL.

module lookup(
    input  wire          clk,//add module's work clk domin
    input  wire          key_clk,
    input  wire          rst_n,
    
    /*
    * AXI-Lite slave interface
    */
    input  wire [31:0]                  s_axil_awaddr,
    input  wire [2:0]                   s_axil_awprot,
    input  wire                         s_axil_awvalid,
    output wire                         s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]   s_axil_wstrb,
    input  wire                         s_axil_wvalid,
    output wire                         s_axil_wready,
    output wire [1:0]                   s_axil_bresp,
    output wire                         s_axil_bvalid,
    input  wire                         s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    input  wire [2:0]                   s_axil_arprot,
    input  wire                         s_axil_arvalid,
    output wire                         s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    output wire [1:0]                   s_axil_rresp,
    output wire                         s_axil_rvalid,
    input  wire                         s_axil_rready,
    
    input  wire          cfg2lookup_cs_n,//low active
    input  wire          cfg2lookup_wr_rd,//0 write 1:read
    output reg           lookup2cfg_ack_n,//low active
    input  wire [15:0]   cfg2lookup_addr,
    input  wire [31:0]   cfg2lookup_wdata,
    output reg  [31:0]   lookup2cfg_rdata,
    
    input  wire          um2lookup_key_valid,
    input  wire [511:0]  um2lookup_key,
    output wire          lookup2um_key_ready,
    
    output reg           lookup2um_index_valid,
    output reg           lookup2um_hit,
    output reg  [5:0]    lookup2um_index,
    input  wire          um2lookup_alful
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
wire            cfg_valid;

reg  [1*8-1:0]  lookup2entry_cs_n;
reg             lookup2entry_wr_rd;
wire [1*8-1:0]  entry2lookup_ack_n;
reg  [5:0]      lookup2entry_addr;
reg  [31:0]     lookup2entry_wdata;         
wire [32*8-1:0] entry2lookup_rdata;
                
wire [1*8-1:0]  sel_valid;
wire [8*8-1:0]  sel_prior;
wire [8*8-1:0]  sel_index;
                
wire            result_valid;
wire [7:0]      result_prior;
wire [7:0]      result_index;
                
reg  [3:0]      result_dly;

reg             key_fifo_rd;
wire            key_fifo_empty;
wire [4:0]      key_fifo_wrusedw;
wire [511:0]    key_fifo_rdata;

reg             key_state;
localparam      K_READ_S   = 1'b0,
                K_WAIT_S   = 1'b1;
                
reg  [3:0]      cfg_state;

localparam      IDLE_S     = 4'd0,
                PARSE_S    = 4'd1,
                WAIT_ACK_S = 4'd2,
                RELEASE_S  = 4'd3;
                

//***************************************************
//                  Lookup Key sync
//***************************************************
assign lookup2um_key_ready = ~key_fifo_wrusedw[4];
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        key_fifo_rd <= 1'b0;
        key_state <= K_READ_S;
    end
    else begin
        case(key_state)
            K_READ_S: begin
                if((key_fifo_empty == 1'b0)&&(um2lookup_alful == 1'b0)) begin
                    key_fifo_rd <= 1'b1;
                    key_state <= K_WAIT_S;
                end
                else begin
                    key_fifo_rd <= 1'b0;
                    key_state <= K_READ_S;
                end
            end
            
            K_WAIT_S: begin//wait fifo's empty update
                key_fifo_rd <= 1'b0;
                key_state <= K_READ_S;
            end
            
            default: begin
                key_fifo_rd <= 1'b0;
                key_state <= K_READ_S;
            end
        endcase
    end
end

//***************************************************
//                  Lookup Cfg
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        lookup2cfg_ack_n <= 1'b1;
        lookup2cfg_rdata <= 32'b0;
        
        lookup2entry_cs_n <= 8'hff;
        lookup2entry_wr_rd <= 1'b0;
        lookup2entry_addr <= 6'b0;
        lookup2entry_wdata <= 32'b0;
        cfg_state <= IDLE_S;
    end
    else begin
        case(cfg_state)
            IDLE_S: begin
                lookup2cfg_ack_n <= 1'b1;
                lookup2entry_cs_n <= 8'hff;
                if((cfg_valid == 1'b1) && (entry2lookup_ack_n == 8'hff)) begin
                    lookup2entry_wr_rd <= cfg2lookup_wr_rd;
                    lookup2entry_addr <= cfg2lookup_addr[7:2];
                    lookup2entry_wdata <= cfg2lookup_wdata;
                    cfg_state <= PARSE_S;
                end
                else begin
                    lookup2entry_wr_rd <= lookup2entry_wr_rd;
                    lookup2entry_addr <= lookup2entry_addr;
                    lookup2entry_wdata <= lookup2entry_wdata;
                    cfg_state <= IDLE_S;
                end
            end
            
            PARSE_S: begin
                case(cfg2lookup_addr[15:8])                                            
                    8'h0: begin lookup2entry_cs_n[0] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h1: begin lookup2entry_cs_n[1] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h2: begin lookup2entry_cs_n[2] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h3: begin lookup2entry_cs_n[3] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h4: begin lookup2entry_cs_n[4] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h5: begin lookup2entry_cs_n[5] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h6: begin lookup2entry_cs_n[6] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    8'h7: begin lookup2entry_cs_n[7] <= 1'b0; cfg_state <= WAIT_ACK_S; end
                    default: begin lookup2entry_cs_n <= 8'hff;      cfg_state <= RELEASE_S; end
                endcase
            end
            
            WAIT_ACK_S: begin
                if((&entry2lookup_ack_n) == 1'b0)begin
                    lookup2entry_cs_n <= 8'hff;
                    casez(lookup2entry_cs_n)
                        8'b????_???0: lookup2cfg_rdata <= entry2lookup_rdata[32*0+31:32*0];
                        8'b????_??01: lookup2cfg_rdata <= entry2lookup_rdata[32*1+31:32*1];
                        8'b????_?011: lookup2cfg_rdata <= entry2lookup_rdata[32*2+31:32*2];
                        8'b????_0111: lookup2cfg_rdata <= entry2lookup_rdata[32*3+31:32*3];
                        8'b???0_1111: lookup2cfg_rdata <= entry2lookup_rdata[32*4+31:32*4];
                        8'b??01_1111: lookup2cfg_rdata <= entry2lookup_rdata[32*5+31:32*5];
                        8'b?011_1111: lookup2cfg_rdata <= entry2lookup_rdata[32*6+31:32*6];
                        8'b0111_1111: lookup2cfg_rdata <= entry2lookup_rdata[32*7+31:32*7];
                        default:      lookup2cfg_rdata <= lookup2cfg_rdata;
                    endcase
                    cfg_state <= RELEASE_S;
                end
                else begin
                    lookup2entry_cs_n <= lookup2entry_cs_n;
                    cfg_state <= WAIT_ACK_S;
                end
            end
            
            RELEASE_S: begin
                if(cfg_valid == 1'b1) begin
                    lookup2cfg_ack_n <= 1'b0;
                    cfg_state <= RELEASE_S;
                end
                else begin
                    lookup2cfg_ack_n <= 1'b1;
                    cfg_state <= IDLE_S;
                end
            end
            
            default: begin
                lookup2cfg_ack_n <= 1'b1;
                lookup2cfg_rdata <= 32'b0;
                
                lookup2entry_cs_n <= 8'hff;
                lookup2entry_wr_rd <= 1'b0;
                lookup2entry_addr <= 6'b0;
                lookup2entry_wdata <= 32'b0;
                cfg_state <= IDLE_S;
            end
        endcase
    end
end

//***************************************************
//                  Lookup Result
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        result_dly <= 4'b0;
        //no matter if hit,the result will come out after delay 4 cycle
        //delay 4 cycle is (1 entry + 3 layer sel branch)
    end
    else begin
        result_dly[0] <= key_fifo_rd;
        result_dly[3:1] <= result_dly[2:0];
    end
end

always @(posedge key_clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        lookup2um_index_valid <= 1'b0;
        lookup2um_hit <= 1'b0;
        lookup2um_index <= 6'b0;
    end
    else begin
        if(result_dly[3] == 1'b1) begin
            lookup2um_index_valid <= 1'b1;
            if(result_valid == 1'b1) begin
                lookup2um_hit <= 1'b1;
                lookup2um_index <= result_index[5:0];
            end
            else begin
                lookup2um_hit <= 1'b0;
                lookup2um_index <= 6'h3f;
            end
        end
        else begin
            lookup2um_index_valid <= 1'b0;
            lookup2um_hit <= 1'b0;
            lookup2um_index <= lookup2um_index;
        end
    end
end

//***************************************************
//                  Other IP Instance
//***************************************************
//likely fifo/ram/async block.... 
//should be instantiated below here 
sync_sig sync_sig_inst(
    .clk(clk),
    .rst_n(rst_n),
    
    .in_sig(~cfg2lookup_cs_n),
    .out_sig(cfg_valid)
);

generate 
    genvar i;
    for(i=0; i<8; i=i+1) begin : Prior_1_Branch
        entry_blk entry_blk_inst(
            .clk(clk),//add module's work clk domin
            .rst_n(rst_n),

            .entry_id(i),

            .cfg2entry_cs_n(lookup2entry_cs_n[i]),//low active
            .cfg2entry_wr_rd(lookup2entry_wr_rd),//0 write 1:read
            .entry2cfg_ack_n(entry2lookup_ack_n[i]),//low active
            .cfg2entry_addr(lookup2entry_addr),
            .cfg2entry_wdata(lookup2entry_wdata),
            .entry2cfg_rdata(entry2lookup_rdata[32*i+31:32*i]),

            .key_valid(key_fifo_rd),
            .key(key_fifo_rdata),

            .hit(sel_valid[i]),
            .prior(sel_prior[8*i+7:8*i]),
            .index(sel_index[8*i+7:8*i])
        );
    end
endgenerate

tree_8prior_sel tree_8prior_sel_inst(
    .clk(clk),//add module's work clk domin
    .rst_n(rst_n),

    .sel_valid(sel_valid),
    .sel_prior(sel_prior),
    .sel_index(sel_index),

    .result_valid(result_valid),
    .result_prior(result_prior),
    .result_index(result_index)
);

async_w512_d32_fifo key_fifo(
   .wr_clk(key_clk),
   .rd_clk(clk),
   .rst(~rst_n),
   
   .wr_en(um2lookup_key_valid),
   .din(um2lookup_key),
   .rd_en(key_fifo_rd),
   .dout(key_fifo_rdata),
   .wr_data_count(key_fifo_wrusedw),
   .rd_data_count(),
   .full(),
   .empty(key_fifo_empty)
);
endmodule
/*
lookup lookup_inst(
    .clk(),//add module's work clk domin
    .rst_n(),

    .cfg2lookup_cs_n(),//low active
    .cfg2lookup_wr_rd(),//0 write 1:read
    .lookup2cfg_ack_n(),//low active
    .cfg2lookup_addr(),
    .cfg2lookup_wdata(),
    .lookup2cfg_rdata(),

    .um2lookup_key_valid(),
    .um2lookup_key(),

    .lookup2um_index_valid(),
    .lookup2um_hit(),
    .lookup2um_index()       
);
*/