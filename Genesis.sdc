set_time_format -unit ns -decimal_places 3

derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

#///////////////////////////////////////////////////
#            SDRAM
#///////////////////////////////////////////////////
# sdram.sv:246|sdramclk_ddr
set clk_ram emu|pll|altpll_component|auto_generated|pll1|clk[1]
create_generated_clock -name {sdram_clk} -source [list $clk_ram] \
-invert [get_ports {DRAM_CLK}]

# sdram.sv:246|sdramclk_ddr No data transfer from clk_ram to DRAM_CLK through altddio
set_false_path -setup -fall_from [list $clk_ram] -rise_to [get_clocks sdram_clk]
set_false_path -hold -fall_from [list $clk_ram] -rise_to [get_clocks sdram_clk]

# FPGA output to SDRAM inputs delay (addr, ba, dq, dqm, ras_n, cas_n, we_n IS42S16320D-7TL have same hold and setup time)
# Tds, Tas
set sdram_input_setup 1.5
# Tdh, Tah
set sdram_input_hold -0.8
set_output_delay -clock sdram_clk -max $sdram_input_setup [get_ports DRAM_*]
set_output_delay -clock sdram_clk -min $sdram_input_hold [get_ports DRAM_*]

# SDRAM IS42S16320D-7TL output to FPGA inputs delay
set sdram_Tac2 6
set sdram_Toh2 2.7
set_input_delay -clock sdram_clk -max $sdram_Tac2 [get_ports DRAM_DQ[*]]
set_input_delay -clock sdram_clk -min $sdram_Toh2 [get_ports DRAM_DQ[*]]

set_multicycle_path -from [get_ports DRAM_DQ[*]] -to {emu|sdram|dout*} -setup 2
set_multicycle_path -from [get_ports DRAM_DQ[*]] -to {emu|sdram|dout*} -hold 1
set_multicycle_path -from {emu|sdram|dout*} -to {emu|system|data*} -setup 2
set_multicycle_path -from {emu|sdram|dout*} -to {emu|system|data*} -hold 1

#///////////////////////////////////////////////////
#            Flash
#///////////////////////////////////////////////////
# All timings are controlled by state machine of flash controller
set_false_path -to [get_ports FL_*]
set_false_path -from [get_ports FL_*]
