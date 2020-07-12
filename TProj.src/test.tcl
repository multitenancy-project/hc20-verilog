
exec xvlog ram.v
exec xvhdl dmem.vhd
exec xvhdl cam_top.vhd
exec xvhdl cam_control.vhd
exec xvhdl cam_decoder.vhd
exec xvhdl cam_init_file_pack_xst.vhd
exec xvhdl cam_input_ternary_ternenc.vhd
exec xvhdl cam_input_ternary.vhd
exec xvhdl cam_input.vhd
exec xvhdl cam_match_enc.vhd
exec xvhdl cam_mem_blk_extdepth_prim.vhd
exec xvhdl cam_mem_blk_extdepth.vhd
exec xvhdl cam_mem_blk.vhd
exec xvhdl cam_mem_srl16_block.vhd
exec xvhdl cam_mem_srl16_block_word.vhd
exec xvhdl cam_mem_srl16_ternwrcomp.vhd
exec xvhdl cam_mem_srl16.vhd
exec xvhdl cam_mem_srl16_wrcomp.vhd
exec xvhdl cam_mem.vhd
exec xvhdl cam_pkg.vhd
exec xvhdl cam_regouts.vhd
exec xvhdl cam_rtl.vhd
exec xvhdl cam_top.vhd

exec xvlog test.v

exec xelab -debug all testbench
exec xsim -gui work.testbench
