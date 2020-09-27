/****************************************************/
//	Module name: alu_2
//	Authority @ yangxiangrui (yangxiangrui11@nudt.edu.cn)
//	Last edited time: 2020/09/23
//	Function outline: 2st type ALU (with load/store) module in RMT
/****************************************************/

`timescale 1ns / 1ps

module alu_2 #(
    parameter STAGE = 0,
    parameter ACTION_LEN = 25,
    parameter DATA_WIDTH = 32  //data width of the ALU
)
(
    input clk,
    input rst_n,

    //input from sub_action
    input [ACTION_LEN-1:0]            action_in,
    input                             action_valid,
    input [DATA_WIDTH-1:0]            operand_1_in,
    input [DATA_WIDTH-1:0]            operand_2_in,
    input [DATA_WIDTH-1:0]            operand_3_in,

    //output to form PHV
    output reg [DATA_WIDTH-1:0]       container_out,
    output reg                        container_out_valid
);

/********intermediate variables declared here********/
localparam width_6B = 48;
localparam width_4B = 32;
localparam width_2B = 16;


reg  [3:0]           action_type;
reg  [31:0]          container_reg;

//regs for RAM access
reg                  store_en;
reg  [4:0]           store_addr;
reg  [31:0]          store_din;

wire [31:0]          load_data;
wire [4:0]           load_addr;

reg  [2:0]           alu_state;


/********intermediate variables declared here********/

assign load_addr = operand_2_in[4:0];

/*
8 operations to support:

1,2. add/sub:   0001/0010
              extract 2 operands from pkt header, add(sub) and write back.

3,4. addi/subi: 1001/1010
              extract op1 from pkt header, op2 from action, add(sub) and write back.

5: load:      0101
              load data from RAM, write to pkt header according to addr in action.

6. store:     0110
              read data from pkt header, write to ram according to addr in action.
*/

localparam  IDLE_S = 3'd0,
            OTHER_S = 3'd1,
            LOAD_S = 3'd2,
            OUTPUT_S = 3'd3;

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        //initialize outputs
        container_out_valid <= 1'b0;
        container_out <= 0;

        //initialize regs
        //container_valid_reg <= 1'b0;
        action_type <= 4'b0;
        store_en <= 1'b0;
        store_addr <= 5'b0;

        alu_state <= IDLE_S;
    end

    else begin
        case(alu_state)

            IDLE_S: begin
                container_out <= 32'b0;
                container_out_valid <= 1'b0;
                if(action_valid) begin
                    action_type <= action_in[24:21];
                    case(action_in[24:21])
                        
                        //add/addi ops 
                        4'b0001, 4'b1001: begin
                            container_reg <= operand_1_in + operand_2_in;
                            alu_state <= OTHER_S;
                        end 
                        //sub/subi ops
                        4'b0010, 4'b1010: begin
                            container_reg <= operand_1_in - operand_2_in;
                            alu_state <= OTHER_S;
                        end
                        //store op (interact with RAM)
                        4'b1000: begin
                            container_reg <= operand_3_in;
                            store_en <= 1'b1;
                            store_addr <= operand_2_in[4:0];
                            store_din <= operand_1_in;
                            alu_state <= OTHER_S;
                        end
                        4'b1011: begin
                            //load_addr <= operand_2_in[4:0];
                            alu_state <= LOAD_S;
                        end
                        //cannot go back to IDLE since this
                        //might be a legal action.
                        default: begin
                            container_reg <= operand_3_in;
                            alu_state <= OTHER_S;
                        end

                    endcase
                end

                else begin
                    alu_state <= IDLE_S;
                    //flush all the regs
                end
            end

            OTHER_S: begin
                //container_out_valid <= 1'b1;
                //container_out <= container_valid_reg;
                store_en <= 1'b0;
                alu_state <= OUTPUT_S;
            end

            LOAD_S: begin
                //do nothing and wait 1 cycle
                //load_addr <= 5'b0;
                //container_out_valid <= 1'b1;
                //container_out <= load_data;
                alu_state <= OUTPUT_S;
            end


            OUTPUT_S: begin
                //output the value
                container_out_valid <= 1'b1;
                if(action_type == 4'b1011) begin
                    container_out <= load_data;
                end
                else begin
                    container_out <= container_reg;
                end
                
                action_type <= 4'b0;
                container_reg <= 32'b0;
                store_en <= 1'b0;
                store_addr <= 5'b0;
                alu_state <= IDLE_S;
            end

        endcase
    end

end

//ram for key-value
//2 cycles to get value
// blk_mem_gen_0 # (
blk_mem_gen_0 # (
	//.RAM_INIT_FILE ("parse_act_ram_init_file.mif")
    .RAM_INIT_FILE ()
)
data_ram_32w_32d
(
    //store-related
    .addra(store_addr),
    .clka(clk),
    .dina(store_din),
    .ena(1'b1),
    .wea(store_en),

    //load-related
    .addrb(load_addr),
    .clkb(clk),
    .doutb(load_data),
    .enb(1'b1)
);

endmodule