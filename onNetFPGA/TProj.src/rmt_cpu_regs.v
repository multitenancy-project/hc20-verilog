`timescale 1ns / 1ps


module rmt_cpu_regs #(
	parameter C_S_AXI_DATA_WIDTH = 32,
	parameter C_S_AXI_ADDR_WIDTH = 32,
	parameter C_BASEADDR		= 32'h44020000
)
(
	input					clk,
	input					resetn,
	input       cpu_resetn_soft,
	output reg  resetn_soft,
	output reg  resetn_sync,

	//
	output reg [31:0]		vlan_drop_flags,
	input [31:0]			ctrl_token,

	// AXI Lite ports
	input                                     S_AXI_ACLK,
	input                                     S_AXI_ARESETN,
	input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_AWADDR,
	input                                     S_AXI_AWVALID,
	input      [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_WDATA,
	input      [C_S_AXI_DATA_WIDTH/8-1 : 0]   S_AXI_WSTRB,
	input                                     S_AXI_WVALID,
	input                                     S_AXI_BREADY,
	input      [C_S_AXI_ADDR_WIDTH-1 : 0]     S_AXI_ARADDR,
	input                                     S_AXI_ARVALID,
	input                                     S_AXI_RREADY,
	output                                    S_AXI_ARREADY,
	output     [C_S_AXI_DATA_WIDTH-1 : 0]     S_AXI_RDATA,
	output     [1 : 0]                        S_AXI_RRESP,
	output                                    S_AXI_RVALID,
	output                                    S_AXI_WREADY,
	output     [1 :0]                         S_AXI_BRESP,
	output                                    S_AXI_BVALID,
	output                                    S_AXI_AWREADY
);


reg [C_S_AXI_ADDR_WIDTH-1 : 0]      axi_awaddr;
reg                                 axi_awready;
reg                                 axi_wready;
reg [1 : 0]                         axi_bresp;
reg                                 axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH-1 : 0]      axi_araddr;
reg                                 axi_arready;
reg [C_S_AXI_DATA_WIDTH-1 : 0]      axi_rdata;
reg [1 : 0]                         axi_rresp;
reg                                 axi_rvalid;

reg                                 resetn_sync_d;
wire                                reg_rden;
wire                                reg_wren;
reg [C_S_AXI_DATA_WIDTH-1:0]        reg_data_out;
integer                             byte_index;

//
assign S_AXI_AWREADY    = axi_awready;
assign S_AXI_WREADY     = axi_wready;
assign S_AXI_BRESP      = axi_bresp;
assign S_AXI_BVALID     = axi_bvalid;
assign S_AXI_ARREADY    = axi_arready;
assign S_AXI_RDATA      = axi_rdata;
assign S_AXI_RRESP      = axi_rresp;
assign S_AXI_RVALID     = axi_rvalid;


    always @ (posedge clk) begin
        if (~resetn) begin
            resetn_sync_d  <=  1'b0;
            resetn_sync    <=  1'b0;
        end
        else begin
            resetn_sync_d  <=  resetn;
            resetn_sync    <=  resetn_sync_d;
        end
    end

always @(posedge clk) resetn_soft <= #1 cpu_resetn_soft;


    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awready <= 1'b0;
        end
      else
        begin
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
            begin
              // slave is ready to accept write address when
              // there is a valid write address and write data
              // on the write address and data bus. This design
              // expects no outstanding transactions.
              axi_awready <= 1'b1;
            end
          else
            begin
              axi_awready <= 1'b0;
            end
        end
    end

    // Implement axi_awaddr latching

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awaddr <= 0;
        end
      else
        begin
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID)
            begin
              // Write Address latching
              axi_awaddr <= S_AXI_AWADDR ^ C_BASEADDR;
            end
        end
    end

    // Implement axi_wready generation

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_wready <= 1'b0;
        end
      else
        begin
          if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID)
            begin
              // slave is ready to accept write data when
              // there is a valid write address and write data
              // on the write address and data bus. This design
              // expects no outstanding transactions.
              axi_wready <= 1'b1;
            end
          else
            begin
              axi_wready <= 1'b0;
            end
        end
    end

    // Implement write response logic generation

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_bvalid  <= 0;
          axi_bresp   <= 2'b0;
        end
      else
        begin
          if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
            begin
              // indicates a valid write response is available
              axi_bvalid <= 1'b1;
              axi_bresp  <= 2'b0; // OKAY response
            end                   // work error responses in future
          else
            begin
              if (S_AXI_BREADY && axi_bvalid)
                //check if bready is asserted while bvalid is high)
                //(there is a possibility that bready is always asserted high)
                begin
                  axi_bvalid <= 1'b0;
                end
            end
        end
    end

    // Implement axi_arready generation

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_arready <= 1'b0;
          axi_araddr  <= 32'b0;
        end
      else
        begin
          if (~axi_arready && S_AXI_ARVALID)
            begin
              // indicates that the slave has acceped the valid read address
              // Read address latching
              axi_arready <= 1'b1;
              axi_araddr  <= S_AXI_ARADDR ^ C_BASEADDR;
            end
          else
            begin
              axi_arready <= 1'b0;
            end
        end
    end


    // Implement axi_rvalid generation

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rvalid <= 0;
          axi_rresp  <= 0;
        end
      else
        begin
          if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
            begin
              // Valid read data is available at the read data bus
              axi_rvalid <= 1'b1;
              axi_rresp  <= 2'b0; // OKAY response
            end
          else if (axi_rvalid && S_AXI_RREADY)
            begin
              // Read data is accepted by the master
              axi_rvalid <= 1'b0;
            end
        end
    end


    // Implement memory mapped register select and write logic generation

    assign reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;



always @(posedge clk) begin
	if (!resetn_sync) begin
		vlan_drop_flags <= #1 32'h0;
	end
	else begin
		if (reg_wren) begin
			case (axi_awaddr)
				32'h4: begin
					for (byte_index = 0; byte_index <= 3; byte_index=byte_index+1)
						if (S_AXI_WSTRB[byte_index] == 1) begin
							vlan_drop_flags[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
						end
				end
				default: begin
				end
			endcase
		end
	end
end

//
assign reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

always @(*) begin
	case (axi_araddr)
		32'h8: begin
			reg_data_out = ctrl_token;
		end
		default: begin
			reg_data_out = 32'habcddcba;
		end
	endcase
end

always @(posedge S_AXI_ACLK) begin
	if (~S_AXI_ARESETN) begin
		axi_rdata <= 0;
	end
	else begin
		if (reg_rden) begin
			axi_rdata <= reg_data_out;
		end
	end
end

//
(* mark_debug = "true" *) wire dbg_rden;
(* mark_debug = "true" *) wire dbg_wren;
(* mark_debug = "true" *) wire [31:0] dbg_vlan;
(* mark_debug = "true" *) wire [31:0] dbg_ctrl;
assign dbg_rden = reg_rden;
assign dbg_wren = reg_wren;
assign dbg_vlan = vlan_drop_flags;
assign dbg_ctrl = reg_data_out;

endmodule
