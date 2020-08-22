`timescale 1ns / 1ps

module key_extract #(
    parameter KEY_LEN  = 896,
    parameter MASK_LEN = 896,
    parameter PHV_LEN = 1024+7+24*8+5*20+256,
    parameter STAGE = 0
)
(
    input       axis_clk,
    input       aresetn,

    //output from parser
    input                       parser_valid,
    input [PHV_LEN-1:0]         pkt_hdr_vec,

    //key for lookup table
    output reg                  key_valid,
    output reg [KEY_LEN-1:0]    extract_key,

    //mask for lookup
    output reg                  key_mask_valid,
    output reg [MASK_LEN-1:0]   key_mask,

    //conditional flag: 1 for true, 0 for false.
    output reg                  cond_flag,
    output reg [PHV_LEN-1:0]    pkt_hdr_vec_out;
);

/********intermediate variables declared here********/
integer i;

//offset for pkt header
localparam HDR_OFF  = 555;
//offset for containers
localparam CONT_OFF_8B = 356;
localparam CONT_OFF_4B = 356+8*8;
localparam CONT_OFF_2B = 356+16*8;
//offset for conditional regs  
localparam COND_OFF = 256;

localparam width_2B = 16;
localparam width_4B = 32;
localparam width_8B = 64;

reg [PHV_LEN-1:0]  phv_reg;
reg [KEY_LEN-1:0]  key_reg;
reg [MASK_LEN-1:0] mask_reg;

reg [15:0] val_2B [0:7];
reg [31:0] val_4B [0:7];
reg [63:0] val_8B [0:7];
//condition operands
reg [7:0] com_op1;
reg [7:0] com_op2;
reg [1:0] com_op;

wire [1023:0] pkt_header;
wire [6:0]    header_len;

//24 fields to be retrived from the pkt header
wire [7:0]    offset_2B [0:7];
wire [7:0]    offset_4B [0:7];
wire [7:0]    offset_8B [0:7];

wire [19:0]  condition;


/********intermediate variables declared here********/

assign pkt_header = pkt_hdr_vec[HDR_OFF +: 1024];
assign header_len = pkt_hdr_vec[HDR_OFF -: 7];

assign offset_2B[0] = pkt_hdr_vec[CONT_OFF_2B +: 8];
assign offset_2B[1] = pkt_hdr_vec[CONT_OFF_2B+8 +: 8];
assign offset_2B[2] = pkt_hdr_vec[CONT_OFF_2B+2*8 +: 8];
assign offset_2B[3] = pkt_hdr_vec[CONT_OFF_2B+3*8 +: 8];
assign offset_2B[4] = pkt_hdr_vec[CONT_OFF_2B+4*8 +: 8];
assign offset_2B[5] = pkt_hdr_vec[CONT_OFF_2B+5*8 +: 8];
assign offset_2B[6] = pkt_hdr_vec[CONT_OFF_2B+6*8 +: 8];
assign offset_2B[7] = pkt_hdr_vec[CONT_OFF_2B+7*8 +: 8];

assign offset_4B[0] = pkt_hdr_vec[CONT_OFF_4B +: 8];
assign offset_4B[1] = pkt_hdr_vec[CONT_OFF_4B+8 +: 8];
assign offset_4B[2] = pkt_hdr_vec[CONT_OFF_4B+2*8 +: 8];
assign offset_4B[3] = pkt_hdr_vec[CONT_OFF_4B+3*8 +: 8];
assign offset_4B[4] = pkt_hdr_vec[CONT_OFF_4B+4*8 +: 8];
assign offset_4B[5] = pkt_hdr_vec[CONT_OFF_4B+5*8 +: 8];
assign offset_4B[6] = pkt_hdr_vec[CONT_OFF_4B+6*8 +: 8];
assign offset_4B[7] = pkt_hdr_vec[CONT_OFF_4B+7*8 +: 8];

assign offset_8B[0] = pkt_hdr_vec[CONT_OFF_8B +: 8];
assign offset_8B[1] = pkt_hdr_vec[CONT_OFF_8B+8 +: 8];
assign offset_8B[2] = pkt_hdr_vec[CONT_OFF_8B+2*8 +: 8];
assign offset_8B[3] = pkt_hdr_vec[CONT_OFF_8B+3*8 +: 8];
assign offset_8B[4] = pkt_hdr_vec[CONT_OFF_8B+4*8 +: 8];
assign offset_8B[5] = pkt_hdr_vec[CONT_OFF_8B+5*8 +: 8];
assign offset_8B[6] = pkt_hdr_vec[CONT_OFF_8B+6*8 +: 8];
assign offset_8B[7] = pkt_hdr_vec[CONT_OFF_8B+7*8 +: 8];

assign condition = pkt_hdr_vec[COND_OFF +: 20];

reg [1:0] key_state;
reg [1:0] com_state;

/********generate the key*******/ 

localparam  IDLE_S = 2'd0,
            EXTRA_S = 2'd1,
            KEY_S = 2'd2;

always @(posedge axis_clk or negedge aresetn) begin
    if (~aresetn) begin
        key_reg <= 896'b0;
        mask_reg <= 896'b0;
        phv_reg <= 1579'b0;
        pkt_hdr_vec_out <= 1579'b0;
        key_state <= IDLE_S;
    end

    else begin
        case(key_state)
            IDLE_S: begin
                if(parser_valid == 1'b0) begin
                    phv_reg <= 1579'b0;
                    key_state <= IDLE_S;
                end
                else begin
                    phv_reg <= pkt_hdr_vec;
                    //retrive the fields to containers
                    for (i=1; i<8; i+=1) begin
                        val_2B[i] <= pkt_header[offset_2B[i] -: 16];
                        val_4B[i] <= pkt_header[offset_4B[i] -: 32];
                        val_8B[i] <= pkt_header[offset_8B[i] -: 64];
                    end
                    key_state <= KEY_S;
                end
            end
            KEY_S: begin
                extract_key <= {val_2B[0],val_2B[1],val_2B[2],val_2B[3],val_2B[4],val_2B[5],val_2B[6],val_2B[7],
                val_4B[0],val_4B[1],val_4B[2],val_4B[3],val_4B[4],val_4B[5],val_4B[6],val_4B[7]
                val_8B[0],val_8B[1],val_8B[2],val_8B[3],val_8B[4],val_8B[5],val_8B[6],val_8B[7]};

                key_valid <= 1'b1;
                key_state <= IDLE_S;
                pkt_hdr_vec_out <= phv_reg;
            end

        endcase
    end
end
/********generate the key*******/ 

/********comparator operation*******/
localparam IDLE_C = 2'b0,
           COM_C  = 2'b1;

always @(posedge axis_clk or negedge aresetn) begin
    if (~aresetn) begin
        com_op1 <= 8'b0;
        com_op2 <= 8'b0;
        com_op  <= 2'b0;
        //default is true
        cond_flag <= 1'b1;
    end

    else begin
        case(com_state)
            IDLE_C: begin
                if(parser_valid == 1'b1) begin
                    //retrive the conditions
                    if (condition[17] == 1'b1) begin
                        com_op1 <= condition[16:9]; 
                    end
                    else begin
                        com_op1 <= pkt_header[condition[16:9] -: 8];
                    end
                    if (condition[8] == 1'b1) begin
                        com_op2 <= condition[7:0]; 
                    end
                    else begin
                        com_op2 <= pkt_header[condition[7:0] -: 8];
                    end
                    com_op <= condition[19:18];

                    com_state <= COM_C;
                end
                else begin
                    com_op1 <= 8'b0;
                    com_op2 <= 8'b0;
                    com_op  <= 2'b0;
                    //default is true
                    cond_flag <= 1'b1;
                    com_state <= IDLE_C;
                end
            end

            COM_C: begin
                case(com_op)
                    2'b00: begin
                        cond_flag <= (com_op1>com_op2)?1'b1:1'b0;
                    end
                    2'b01 begin
                        cond_flag <= (com_op1>=com_op2)?1'b1:1'b0;
                    end
                    2'b10 begin
                        cond_flag <= (com_op1==com_op2)?1'b1:1'b0;
                    end
                    default: begin
                        cond_flag <= 1'b1;
                    end
                endcase
                com_state <= IDLE_C;
            end
        endcase
        
    end
end

/********comparator operation*******/
endmodule