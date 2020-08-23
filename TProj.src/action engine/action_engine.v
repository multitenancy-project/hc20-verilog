`timescale 1ns / 1ps
module action_engine #(
    parameter PHV_LEN = 1024+7+24*8+5*20+256,
    parameter STAGE = 0,
    parameter ACTION_LEN = 25
)
(
    input       axis_clk,
    input       aresetn,

    //output from lookup engine
    input      [ACTION_LEN-1:0]  action_in,
    input                        action_in_valid,
    input      [PHV_LEN-1:0]     phv_in,

    //output to the next stage
    output reg [PHV_LEN-1:0]     phv_out,
    output reg                   phv_out_valid
);

/********intermediate variables declared here********/

integer              i;
//offset for pkt header
localparam           HDR_OFF  = 555;
//offset for containers
localparam           CONT_OFF_8B = 356;
localparam           CONT_OFF_4B = 356+8*8;
localparam           CONT_OFF_2B = 356+16*8;
localparam           PHV_LENS = PHV_LEN-1;

reg [ACTION_LEN-1:0] action_e1_reg;
reg [PHV_LEN-1:0]    phv_e1_reg;
reg [ACTION_LEN-1:0] action_e2_reg;
reg [PHV_LEN-1:0]    phv_e2_reg;
reg [63:0]           op_1_e1;
reg [7:0]            op_1_e1_off;
reg [63:0]           op_2_e1;
reg [7:0]            op_2_e1_off;
reg [63:0]           op_1_e2;
reg [7:0]            op_1_e2_off;
reg [63:0]           op_2_e2;
reg [7:0]            op_2_e2_off;

wire [1023:0]        pkt_header;
wire [6:0]           header_len;

//24 fields to be retrived from the packet header
wire [7:0]           offset_2B [0:7];
wire [7:0]           offset_4B [0:7];
wire [7:0]           offset_8B [0:7];

reg [2:0]            action_op_e1_state;
reg [2:0]            action_op_e2_state;
// 00 for nothing, 11 for two phv, 10 for phv/imm, 01 for phv/mem.
reg [1:0]            operand_type;
// 00 for 2B (default), 01 for 4B, 10 for 8B.
reg [1:0]            operand_wide;

//e1 & e2 are the 2 engines for execution.
reg                  e1_finish;
reg                  e2_finish;

//RAM-related
reg                  store_en;
wire  [31:0]         load_data;

/********intermediate variables declared here********/

assign pkt_header = phv_in[HDR_OFF +: 1024];
assign header_len = phv_in[HDR_OFF -: 7];

assign offset_2B[0] = phv_in[CONT_OFF_2B +: 8];
assign offset_2B[1] = phv_in[CONT_OFF_2B+8 +: 8];
assign offset_2B[2] = phv_in[CONT_OFF_2B+2*8 +: 8];
assign offset_2B[3] = phv_in[CONT_OFF_2B+3*8 +: 8];
assign offset_2B[4] = phv_in[CONT_OFF_2B+4*8 +: 8];
assign offset_2B[5] = phv_in[CONT_OFF_2B+5*8 +: 8];
assign offset_2B[6] = phv_in[CONT_OFF_2B+6*8 +: 8];
assign offset_2B[7] = phv_in[CONT_OFF_2B+7*8 +: 8];

assign offset_4B[0] = phv_in[CONT_OFF_4B +: 8];
assign offset_4B[1] = phv_in[CONT_OFF_4B+8 +: 8];
assign offset_4B[2] = phv_in[CONT_OFF_4B+2*8 +: 8];
assign offset_4B[3] = phv_in[CONT_OFF_4B+3*8 +: 8];
assign offset_4B[4] = phv_in[CONT_OFF_4B+4*8 +: 8];
assign offset_4B[5] = phv_in[CONT_OFF_4B+5*8 +: 8];
assign offset_4B[6] = phv_in[CONT_OFF_4B+6*8 +: 8];
assign offset_4B[7] = phv_in[CONT_OFF_4B+7*8 +: 8];

assign offset_8B[0] = phv_in[CONT_OFF_8B +: 8];
assign offset_8B[1] = phv_in[CONT_OFF_8B+8 +: 8];
assign offset_8B[2] = phv_in[CONT_OFF_8B+2*8 +: 8];
assign offset_8B[3] = phv_in[CONT_OFF_8B+3*8 +: 8];
assign offset_8B[4] = phv_in[CONT_OFF_8B+4*8 +: 8];
assign offset_8B[5] = phv_in[CONT_OFF_8B+5*8 +: 8];
assign offset_8B[6] = phv_in[CONT_OFF_8B+6*8 +: 8];
assign offset_8B[7] = phv_in[CONT_OFF_8B+7*8 +: 8];


/*
8 operations to support:

1. add/sub:   0001/0010
              extract 2 operands from pkt header, add(sub) and write back.

3. addi/subi: 0011/0100
              extract op1 from pkt header, op2 from action, add(sub) and write back.
5: load:      0101
              load data from RAM, write to pkt header according to addr in action.
6. store:     0110
              read data from pkt header, write to ram according to addr in action.
7. redirect:  1000
              redirect the packet to specific port.
8. discard:   1001
              discard the current packet.
*/


/*
1. prepare operand 1 and 2 (may include RAM read);
2. do the calc (may include RAM read);
3. write data to phv or ram.
*/

localparam  IDLE_OP_E1_S  =  3'd0,
            GET_OP_E1_S   =  3'd1,
            CALC_OP_E1_S  =  3'd2;

/******PREPARE OPERANDS********/
always @(posedge axis_clk or negedge aresetn) begin
    if(~aresetn) begin
        action_e1_reg <= 25'b0;
        phv_e1_reg <= 1579'b0;
        op_1_e1 <= 64'b0;
        op_2_e1 <= 64'b0;
        op_1_e1_off <= 8'b0;
        op_2_e1_off <= 8'b0;
        operand_type <= 2'b0;
        operand_wide <= 2'b0;
        e1_finish <= 1'b0;
        store_en <= 1'b0;

        action_op_e1_state <= IDLE_OP_E1_S;
        
    end

    else begin
        case(action_op_e1_state)
            IDLE_OP_E1_S: begin
                if(action_in_valid && action_in[24:21]!=4b'0101
                 && action_in[24:21]!=4b'0110) begin
                    //in GET_OP_E1_S, locate the actual operands.
                    action_op_e1_state <= GET_OP_E1_S;
                    
                    action_e1_reg <= action_in;
                    phv_e1_reg <= phv_in;
                    /*
                    4 types of operand extraction:
                        1. obtain 2 operands from phv;
                        2. obtain 1st operand from phv, 2nd from immidiate;
                        3. obtain 1st operand from phv, 2nd from BRAM; (store)
                        4. nothing to obtain, just record the action.
                    */
                    case(action_in[24:21])
                        4'b0001, 4'b0010: begin
                            //operand type: phv/phv
                            operand_type <= 2'b11;

                            case(action_in[20:19])
                                2'b00: begin
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_2B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_2B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_2B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_2B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_2B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_2B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_2B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_2B[7];
                                        end
                                    endcase
                                end
                                2'b01: begin
                                    operand_wide <= 2'b01;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_4B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_4B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_4B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_4B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_4B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_4B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_4B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_4B[7];
                                        end
                                    endcase
                                end
                                2'b10: begin
                                    operand_wide <= 2'b10;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_8B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_8B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_8B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_8B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_8B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_8B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_8B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_8B[7];
                                        end
                                    endcase
                                end
                                default: begin
                                    //TODO need a debug info here.
                                end
                            endcase
                            case (action_in[15:14])
                                2'b00: begin
                                    
                                    case(action_in[13:11])
                                        3'b000: begin
                                            op_2_e1_off <= offset_2B[0];
                                        end
                                        3'b001: begin
                                            op_2_e1_off <= offset_2B[1];
                                        end
                                        3'b010: begin
                                            op_2_e1_off <= offset_2B[2];
                                        end
                                        3'b011: begin
                                            op_2_e1_off <= offset_2B[3];
                                        end
                                        3'b100: begin
                                            op_2_e1_off <= offset_2B[4];
                                        end
                                        3'b101: begin
                                            op_2_e1_off <= offset_2B[5];
                                        end
                                        3'b110: begin
                                            op_2_e1_off <= offset_2B[6];
                                        end
                                        3'b111: begin
                                            op_2_e1_off <= offset_2B[7];
                                        end
                                    endcase
                                end
                                2'b01: begin
                                    
                                    case(action_in[13:11])
                                        3'b000: begin
                                            op_2_e1_off <= offset_4B[0];
                                        end
                                        3'b001: begin
                                            op_2_e1_off <= offset_4B[1];
                                        end
                                        3'b010: begin
                                            op_2_e1_off <= offset_4B[2];
                                        end
                                        3'b011: begin
                                            op_2_e1_off <= offset_4B[3];
                                        end
                                        3'b100: begin
                                            op_2_e1_off <= offset_4B[4];
                                        end
                                        3'b101: begin
                                            op_2_e1_off <= offset_4B[5];
                                        end
                                        3'b110: begin
                                            op_2_e1_off <= offset_4B[6];
                                        end
                                        3'b111: begin
                                            op_2_e1_off <= offset_4B[7];
                                        end
                                    endcase
                                end
                                2'b10: begin
                                    case(action_in[13:11])
                                        3'b000: begin
                                            op_2_e1_off <= offset_8B[0];
                                        end
                                        3'b001: begin
                                            op_2_e1_off <= offset_8B[1];
                                        end
                                        3'b010: begin
                                            op_2_e1_off <= offset_8B[2];
                                        end
                                        3'b011: begin
                                            op_2_e1_off <= offset_8B[3];
                                        end
                                        3'b100: begin
                                            op_2_e1_off <= offset_8B[4];
                                        end
                                        3'b101: begin
                                            op_2_e1_off <= offset_8B[5];
                                        end
                                        3'b110: begin
                                            op_2_e1_off <= offset_8B[6];
                                        end
                                        3'b111: begin
                                            op_2_e1_off <= offset_8B[7];
                                        end
                                    endcase
                                end
                                default: begin
                                    //TODO need a debug info here.
                                end
                            endcase
                        end
                        4'b0011, 4'b0100: begin
                            //operand type: phv/immi
                            operand_type <= 2'b10;

                            case(action_in[20:19])
                                2'b00: begin
                                    operand_wide <= 2'b00;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_2B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_2B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_2B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_2B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_2B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_2B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_2B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_2B[7];
                                        end
                                    endcase
                                end
                                2'b01: begin
                                    operand_wide <= 2'b01;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_4B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_4B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_4B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_4B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_4B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_4B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_4B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_4B[7];
                                        end
                                    endcase
                                end
                                2'b10: begin
                                    operand_wide <= 2'b10;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_8B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_8B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_8B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_8B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_8B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_8B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_8B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_8B[7];
                                        end
                                    endcase
                                end
                                default: begin
                                    //TODO need a debug info here.
                                end
                            endcase
                            //get the 2nd operand (immidiate)
                            op_2_e1 <= action_in[15:0];

                        end
                        4'b0110: begin
                            operand_type <= 2'b01;
                            case(action_in[20:19])
                                2'b00: begin
                                    operand_wide <= 2'b00;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_2B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_2B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_2B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_2B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_2B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_2B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_2B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_2B[7];
                                        end
                                    endcase
                                end
                                2'b01: begin
                                    operand_wide <= 2'b01;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_4B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_4B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_4B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_4B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_4B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_4B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_4B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_4B[7];
                                        end
                                    endcase
                                end
                                2'b10: begin
                                    operand_wide <= 2'b10;
                                    case(action_in[18:16])
                                        3'b000: begin
                                            op_1_e1_off <= offset_8B[0];
                                        end
                                        3'b001: begin
                                            op_1_e1_off <= offset_8B[1];
                                        end
                                        3'b010: begin
                                            op_1_e1_off <= offset_8B[2];
                                        end
                                        3'b011: begin
                                            op_1_e1_off <= offset_8B[3];
                                        end
                                        3'b100: begin
                                            op_1_e1_off <= offset_8B[4];
                                        end
                                        3'b101: begin
                                            op_1_e1_off <= offset_8B[5];
                                        end
                                        3'b110: begin
                                            op_1_e1_off <= offset_8B[6];
                                        end
                                        3'b111: begin
                                            op_1_e1_off <= offset_8B[7];
                                        end
                                    endcase
                                end
                                default: begin
                                    //TODO need a debug info here.
                                end
                            endcase
                            //get the 2nd operand (address)
                            op_2_e1 <= action_in[15:0];
                        end

                        4'b1000, 4'b1001: begin
                            //operand type: nothing
                            operand_type <= 2'b00;
                            //this is for debug.
                            op_1_e1_off <= 8'h3f;
                            op_2_e1_off <= 8'h3f;
                        end
                        default: begin
                            //TODO what to do with default? need error msg 4 unsupported op.
                            action_op_e1_state <= IDLE_OP_E1_S;
                        end
                    endcase
                end
                else begin
                    op_1_e1 <= 64'b0;
                    op_2_e1 <= 64'b0;
                    op_1_e1_off <= 8'b0;
                    op_2_e1_off <= 8'b0;
                    e1_finish <= 1'b0;
                    operand_wide <= 2'b00;
                    operand_type <= 2'b00;
                    store_en <= 1'b0;
                    action_op_e1_state <= IDLE_OP_E1_S;
                end
            end
            GET_OP_E1_S: begin
                action_op_e1_state <= CALC_OP_E1_S;
                case(operand_type)
                    2'b11: begin
                        case(operand_wide)
                            //2B type
                            2'b00: begin
                                op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 16];
                                op_2_e1 <= phv_e1_reg[PHV_LENS-op_2_e1_off -: 16];
                            end
                            //4B type
                            2'b01: begin
                                op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 32];
                                op_2_e1 <= phv_e1_reg[PHV_LENS-op_2_e1_off -: 32];
                            end
                            //8B type
                            2'b10: begin
                                op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 64];
                                op_2_e1 <= phv_e1_reg[PHV_LENS-op_2_e1_off -: 64];
                            end
                        endcase
                    end
                    2'b10: begin
                        case(operand_wide)
                            //2B type
                            2'b00: begin
                                op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 16];
                                op_2_e1 <= op_2_e1;
                            end
                            //4B type
                            2'b01: begin
                                op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 32];
                                op_2_e1 <= op_2_e1;
                            end
                            2'b10: begin
                                op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 64];
                                op_2_e1 <= op_2_e1;
                            end
                        endcase
                    end
                    2'b01: begin
                        op_1_e1 <= phv_e1_reg[PHV_LENS-op_1_e1_off -: 32];
                        op_2_e1 <= op_2_e1;
                        store_en <= 1'b1;
                    end
                    2'b00: begin
                        //do nothing
                        action_op_e1_state <= GET_OP_E1_S;
                    end
                endcase
            end
            CALC_OP_E1_S: begin
                //FINISHING IN NEXT CYCLE.
                e1_finish <= 1'b1;
                op_1_e1 <= 64'b0;
                op_2_e1 <= 64'b0;
                op_1_e1_off <= 8'b0;
                op_2_e1_off <= 8'b0;
                store_en <= 1'b0;
                action_op_e1_state <= IDLE_OP_E1_S;

                case(action_e1_reg[24:21])
                    /**** ADD/ADDI *****/
                    4'b0001, 4'b0011: begin
                        case(operand_wide)
                            2'b00: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 16] <= op_1_e1 + op_2_e1;
                            end
                            2'b01: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 32] <= op_1_e1 + op_2_e1;
                            end
                            2'b10: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 64] <= op_1_e1 + op_2_e1;
                            end
                            default: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 16] <= op_1_e1 + op_2_e1;
                            end
                        endcase
                    end
                    /**** SUB/SUBI *****/
                    4'b0010, 4'b0100: begin
                        case(operand_wide)
                            2'b00: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 16] <= op_1_e1 - op_2_e1;
                            end
                            2'b01: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 32] <= op_1_e1 - op_2_e1;
                            end
                            2'b10: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 64] <= op_1_e1 - op_2_e1;
                            end
                            default: begin
                                phv_e1_reg[PHV_LENS-op_1_e1_off -: 16] <= op_1_e1 - op_2_e1;
                            end
                        endcase
                    end
                    /**** REDIRECT ****/
                    4'b1000: begin
                        phv_e1_reg[31:24] <= action_e1_reg[20:13];
                    end
                    /**** DISCARD ****/
                    4'b1001: begin
                        phv_e1_reg[128] <= action_e1_reg[12];
                    end
                    /**** STORE & DEFAULT ****/
                    default:begin
                        phv_e1_reg <= phv_e1_reg;
                    end
                endcase
            end
        endcase
    end
end

//localparam  IDLE_OP_E1_S  =  3'd0,

//this is for LOAD & STORE exclusively.
localparam  IDLE_OP_E2_S  =  3'd0,
            GET_OP_E2_S   =  3'd1,
            WAIT1_OP_E2_S =  3'd2,
            CALC_OP_E2_S  =  3'd3;
 
always @(posedge axis_clk or negedge aresetn) begin
    if(~aresetn) begin
        action_e2_reg <= 25'b0;
        phv_e2_reg <= 1579'b0;
        op_1_e2 <= 64'b0;
        op_2_e2 <= 64'b0;
        op_1_e2_off <= 8'b0;
        op_2_e2_off <= 8'b0;
        e2_finish <= 1'b0;

        action_op_e1_state <= IDLE_OP_E2_S;
    end
    else begin
        case(action_op_e2_state)
            IDLE_OP_E2_S: begin
                if(action_in_valid && action_in[24:21] == 4'b0101) begin
                    action_e2_reg <= action_in;
                    phv_e2_reg <= phv_in;
                    action_op_e2_state <= GET_OP_E2_S;
                    case(action_in[20:19])
                        2'b00: begin
                            case(action_in[18:16])
                                3'b000: begin
                                    op_1_e2_off <= offset_2B[0];
                                end
                                3'b001: begin
                                    op_1_e2_off <= offset_2B[1];
                                end
                                3'b010: begin
                                    op_1_e2_off <= offset_2B[2];
                                end
                                3'b011: begin
                                    op_1_e2_off <= offset_2B[3];
                                end
                                3'b100: begin
                                    op_1_e2_off <= offset_2B[4];
                                end
                                3'b101: begin
                                    op_1_e2_off <= offset_2B[5];
                                end
                                3'b110: begin
                                    op_1_e2_off <= offset_2B[6];
                                end
                                3'b111: begin
                                    op_1_e2_off <= offset_2B[7];
                                end
                            endcase
                        end
                        2'b01: begin
                            operand_wide <= 2'b01;
                            case(action_in[18:16])
                                3'b000: begin
                                    op_1_e2_off <= offset_4B[0];
                                end
                                3'b001: begin
                                    op_1_e2_off <= offset_4B[1];
                                end
                                3'b010: begin
                                    op_1_e2_off <= offset_4B[2];
                                end
                                3'b011: begin
                                    op_1_e2_off <= offset_4B[3];
                                end
                                3'b100: begin
                                    op_1_e2_off <= offset_4B[4];
                                end
                                3'b101: begin
                                    op_1_e2_off <= offset_4B[5];
                                end
                                3'b110: begin
                                    op_1_e2_off <= offset_4B[6];
                                end
                                3'b111: begin
                                    op_1_e2_off <= offset_4B[7];
                                end
                            endcase
                        end
                        2'b10: begin
                            operand_wide <= 2'b10;
                            case(action_in[18:16])
                                3'b000: begin
                                    op_1_e2_off <= offset_8B[0];
                                end
                                3'b001: begin
                                    op_1_e2_off <= offset_8B[1];
                                end
                                3'b010: begin
                                    op_1_e2_off <= offset_8B[2];
                                end
                                3'b011: begin
                                    op_1_e2_off <= offset_8B[3];
                                end
                                3'b100: begin
                                    op_1_e2_off <= offset_8B[4];
                                end
                                3'b101: begin
                                    op_1_e2_off <= offset_8B[5];
                                end
                                3'b110: begin
                                    op_1_e2_off <= offset_8B[6];
                                end
                                3'b111: begin
                                    op_1_e2_off <= offset_8B[7];
                                end
                            endcase
                        end
                        default: begin
                            //TODO need a debug info here.
                        end
                    endcase
                    op_2_e2 <= action_in[15:0];
                end

                else begin
                    op_1_e2 <= 64'b0;
                    op_2_e2 <= 64'b0;
                    op_1_e2_off <= 8'b0;
                    op_2_e2_off <= 8'b0;
                    e2_finish <= 1'b0;

                    action_op_e1_state <= IDLE_OP_E2_S;
                end
            end
            GET_OP_E2_S: begin
                op_1_e2 <= phv_e2_reg[PHV_LENS-op_1_e2_off -: 32];
                op_2_e2 <= op_2_e2;
                action_op_e2_state <= CALC_OP_E2_S;
            end
            CALC_OP_E2_S: begin
                phv_e2_reg[PHV_LENS-op_1_e2_off -: 32] <= load_data;
                e2_finish <= 1'b1;
                op_1_e2 <= 64'b0;
                op_2_e2 <= 64'b0;
                op_1_e2_off <= 8'b0;
                op_2_e2_off <= 8'b0;
                action_op_e2_state <= IDLE_OP_E2_S;
            end

        endcase
    end
end


//this is to generate PHV_OUT.
always @(posedge axis_clk) begin
    case({e1_finish,e2_finish})
        2'b00: begin
            phv_out <= 1579'b0;
            phv_out_valid <= 1'b0;
        end
        2'b10: begin
            phv_out <= phv_e1_reg;
            phv_out_valid <= 1'b1;
        end
        2'b01: begin
            phv_out <= phv_e2_reg;
            phv_out_valid <= 1'b1;
        end
        default: begin
            phv_out <= 1579'b0;
            phv_out_valid <= 1'b0;
        end
    endcase
end

//ram for key-value
//2 cycles to get value
ram32x32 # (
	//.RAM_INIT_FILE ("parse_act_ram_init_file.mif")
    .RAM_INIT_FILE ()
)
act_ram
(
	.axi_clk		(axis_clk),
	.axi_wr_en		(store_en),
	.axi_rd_en		(1'b1),
	.axi_wr_addr	(op_2_e1[4:0]),
	.axi_rd_addr	(op_2_e2[4:0]),
	.axi_data_in	(op_1_e1[31:0]),
	.axi_data_out	(load_data),

	.axis_clk		(),
	.axis_rd_en		(),
	.axis_rd_addr	(),
	.axis_data_out	()
);

endmodule