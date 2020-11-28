derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_multicycle_path -from {sdram|dout*} -to {system|data*} -setup 2
set_multicycle_path -from {sdram|dout*} -to {system|data*} -hold 1

# Specify root clocks
create_clock -period "50.0 MHz" [get_ports CLOCK_50]

# Decouple different clock groups (to simplify routing)
#Remove constrains ff sysmen module removed (h2f_user0_clk is in sysmen)
#set_clock_groups -exclusive \
#	-group [get_clocks { CLOCK_50 }] \
#  -group [get_clocks { *|h2f_user0_clk}]

set_false_path -from [get_ports {KEY*}]
set_false_path -to [get_ports {LED*}]
set_false_path -to [get_ports {VGA_*}]