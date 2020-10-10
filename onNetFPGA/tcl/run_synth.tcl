set jobs [lindex $argv 0]

open_project TProj.xpr
reset_run synth_1
launch_runs synth_1 -jobs ${jobs}
wait_on_run synth_1

exit
