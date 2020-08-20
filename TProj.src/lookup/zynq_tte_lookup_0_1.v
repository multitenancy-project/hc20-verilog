// (c) Copyright 1995-2019 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:user:lookup:1.0
// IP Revision: 9

(* X_CORE_INFO = "lookup,Vivado 2018.3" *)
(* CHECK_LICENSE_TYPE = "zynq_tte_lookup_0_1,lookup,{}" *)
(* CORE_GENERATION_INFO = "zynq_tte_lookup_0_1,lookup,{x_ipProduct=Vivado 2018.3,x_ipVendor=xilinx.com,x_ipLibrary=user,x_ipName=lookup,x_ipVersion=1.0,x_ipCoreRevision=9,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED}" *)
(* IP_DEFINITION_SOURCE = "package_project" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module zynq_tte_lookup_0_1 (
  clk,
  key_clk,
  rst_n,
  cfg2lookup_cs_n,
  cfg2lookup_wr_rd,
  lookup2cfg_ack_n,
  cfg2lookup_addr,
  cfg2lookup_wdata,
  lookup2cfg_rdata,
  um2lookup_key_valid,
  um2lookup_key,
  lookup2um_key_ready,
  lookup2um_index_valid,
  lookup2um_hit,
  lookup2um_index,
  um2lookup_alful
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME clk, ASSOCIATED_RESET rst_n, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk CLK" *)
input wire clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME key_clk, FREQ_HZ 100000000, PHASE 0.0, CLK_DOMAIN /clk_wiz_0_clk_out1, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 key_clk CLK" *)
input wire key_clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME rst_n, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst_n RST" *)
input wire rst_n;
(* X_INTERFACE_INFO = "xilinx.com:user:localbus:1.0 localbus cs_n" *)
input wire cfg2lookup_cs_n;
(* X_INTERFACE_INFO = "xilinx.com:user:localbus:1.0 localbus cmd" *)
input wire cfg2lookup_wr_rd;
(* X_INTERFACE_INFO = "xilinx.com:user:localbus:1.0 localbus ack_n" *)
output wire lookup2cfg_ack_n;
(* X_INTERFACE_INFO = "xilinx.com:user:localbus:1.0 localbus addr" *)
input wire [15 : 0] cfg2lookup_addr;
(* X_INTERFACE_INFO = "xilinx.com:user:localbus:1.0 localbus wdata" *)
input wire [31 : 0] cfg2lookup_wdata;
(* X_INTERFACE_INFO = "xilinx.com:user:localbus:1.0 localbus rdata" *)
output wire [31 : 0] lookup2cfg_rdata;
input wire um2lookup_key_valid;
input wire [511 : 0] um2lookup_key;
output wire lookup2um_key_ready;
output wire lookup2um_index_valid;
output wire lookup2um_hit;
output wire [5 : 0] lookup2um_index;
input wire um2lookup_alful;

  lookup inst (
    .clk(clk),
    .key_clk(key_clk),
    .rst_n(rst_n),
    .cfg2lookup_cs_n(cfg2lookup_cs_n),
    .cfg2lookup_wr_rd(cfg2lookup_wr_rd),
    .lookup2cfg_ack_n(lookup2cfg_ack_n),
    .cfg2lookup_addr(cfg2lookup_addr),
    .cfg2lookup_wdata(cfg2lookup_wdata),
    .lookup2cfg_rdata(lookup2cfg_rdata),
    .um2lookup_key_valid(um2lookup_key_valid),
    .um2lookup_key(um2lookup_key),
    .lookup2um_key_ready(lookup2um_key_ready),
    .lookup2um_index_valid(lookup2um_index_valid),
    .lookup2um_hit(lookup2um_hit),
    .lookup2um_index(lookup2um_index),
    .um2lookup_alful(um2lookup_alful)
  );
endmodule
