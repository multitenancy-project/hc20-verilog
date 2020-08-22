`timescale 1ns / 1ps

module lookup_engine #(
    parameter KEY_LEN  = 896,
    parameter MASK_LEN = 896,
    parameter PKT_HDR_LEN = 1024+7+24*8+5*20+256
) 