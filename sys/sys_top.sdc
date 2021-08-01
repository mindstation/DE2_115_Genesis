# Specify root clocks
create_clock -period "50.0 MHz" [get_ports CLOCK_50]
create_clock -period "50.0 MHz" [get_ports CLOCK2_50]

# Actual divider number is CLK_Freq/I2C_Freq in I2C_AV_Config.v:66
create_generated_clock -name mI2C_CTRL_CLK \
-divide_by 530 \
-source [get_ports { CLOCK2_50 }] \
[get_registers { I2C_AV_Config:i2c_con|mI2C_CTRL_CLK }]

derive_pll_clocks
derive_clock_uncertainty

# Decouple different clock groups (to simplify routing)
set_clock_groups -exclusive \
	-group [get_clocks { *|altpll_component|auto_generated|pll1|clk* }] \
	-group [get_clocks { CLOCK_50 }] \
	-group [get_clocks { CLOCK2_50 }]

set_false_path -from [get_ports { KEY* }]
set_false_path -from [get_ports { SW* }]
set_false_path -to [get_ports { LED* }]
set_false_path -to [get_ports { VGA_* }]
set_false_path -to [get_ports {AUDIO_L}]
set_false_path -to [get_ports {AUDIO_R}]

# It don't need while vol_att is a wire
#set_false_path -to   {vol_att[*]}
#set_false_path -from {vol_att[*]}