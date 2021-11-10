transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+/home/greyman/github/DE2_115_Genesis/de2115_board {/home/greyman/github/DE2_115_Genesis/de2115_board/rom_loader.v}
vlog -vlog01compat -work work +incdir+/home/greyman/github/DE2_115_Genesis/de2115_board {/home/greyman/github/DE2_115_Genesis/de2115_board/flash.v}
vlog -sv -work work +incdir+/home/greyman/github/DE2_115_Genesis/rtl {/home/greyman/github/DE2_115_Genesis/rtl/sdram.sv}
vlog -vlog01compat -work work +incdir+/home/greyman/github/DE2_115_Genesis/simulation/testbench {/home/greyman/github/DE2_115_Genesis/simulation/testbench/mt48lc4m16a2.v}


vlog -sv -work work +incdir+/home/greyman/github/DE2_115_Genesis/simulation {/home/greyman/github/DE2_115_Genesis/simulation/testbench/testbench_romloader.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  testbench_romloader

add wave *
view structure
view signals
run -all
