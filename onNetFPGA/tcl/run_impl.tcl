set jobs [lindex $argv 0]

open_project TProj.xpr
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs ${jobs}
wait_on_run impl_1

exit
