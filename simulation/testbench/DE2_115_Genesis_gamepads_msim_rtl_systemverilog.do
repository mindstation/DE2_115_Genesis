transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+/home/greyman/github/DE2_115_Genesis/de2115_board {/home/greyman/github/DE2_115_Genesis/de2115_board/genesis_gamepads.v}

vlog -sv -work work +incdir+/home/greyman/github/DE2_115_Genesis/simulation {/home/greyman/github/DE2_115_Genesis/simulation/testbench/testbench_gamepads.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc" testbench_gamepads

add wave *
add wave dut.padread_state
add wave genesis_pad.genpad6b_state
view structure
view signals
run -all
