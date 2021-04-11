# Specify root clocks
create_clock -period "50.0 MHz" [get_ports CLOCK_50]

# Actual divider number is CLK_Freq/I2C_Freq in I2C_AV_Config.v
create_generated_clock -name mI2C_CTRL_CLK \
-divide_by 530 \
-source [get_pins {pll|altpll_component|auto_generated|pll1|clk[0]}] \
[get_registers {I2C_AV_Config:i2c_con|mI2C_CTRL_CLK}]

derive_pll_clocks
derive_clock_uncertainty

# Decouple different clock groups (to simplify routing)
#Remove constrains if sysmen module removed (h2f_user0_clk is in sysmen)
set_clock_groups -exclusive \
	-group [get_clocks { CLOCK_50 }] \
	-group [get_clocks {pll|altpll_component|auto_generated|pll1|clk*}]
#	-group [get_clocks { *|pll|pll_inst|altera_pll_i|*[*].*|divclk}]
#  -group [get_clocks { *|h2f_user0_clk}]

set_multicycle_path -from {sdram|dout*} -to {system|data*} -setup 2
set_multicycle_path -from {sdram|dout*} -to {system|data*} -hold 1

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_false_path -from [get_ports {KEY*}]
set_false_path -to [get_ports {LED*}]
set_false_path -to [get_ports {VGA_*}]