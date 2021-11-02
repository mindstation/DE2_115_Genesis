set_time_format -unit ns -decimal_places 3

# Specify root clocks
create_clock -period "50.0 MHz" [get_ports CLOCK_50]
create_clock -period "50.0 MHz" [get_ports CLOCK2_50]

derive_pll_clocks
derive_clock_uncertainty

# Decouple different clock groups (to simplify routing)
set_clock_groups -exclusive \
	-group [get_clocks { emu|pll|altpll_component|auto_generated|pll1|clk* }] \
	-group [get_clocks { pll_sys|altpll_component|auto_generated|pll1|clk[1] }] \
	-group [get_clocks { CLOCK_50 }] \
	-group [get_clocks { CLOCK2_50 }]

set_false_path -from [get_ports { KEY* }]
set_false_path -from [get_ports { SW* }]
set_false_path -to [get_ports { LED* }]
set_false_path -to [get_ports { VGA_* }]
set_false_path -to [get_ports { AUDIO_L }]
set_false_path -to [get_ports { AUDIO_R }]

#///////////////////////////////////////////////////
#    Audio out
#///////////////////////////////////////////////////

# It don't need while vol_att is a wire
#set_false_path -to   {vol_att[*]}
#set_false_path -from {vol_att[*]}
# It don't need while is constants
#set_false_path -from {aflt_* acx* acy* areset* arc*}

#    Audio codec
#---------------------------------------------------
create_generated_clock -name audio_xck \
-source [get_pins { pll_sys|altpll_component|auto_generated|pll1|clk[0] }] \
[get_ports { AUD_XCK }]

set_false_path -to [get_ports { AUD_BCLK AUD_DACLRCK AUD_DACDAT }]

#create_generated_clock -name audio_bclk \
-source [get_ports CLOCK2_50] \
[get_ports { AUD_BCLK }]
#[get_registers { audio_out|i2s|sclk }]
#set_output_delay -clock audio_bclk 0 [get_ports { AUD_BCLK }]

#    I2C controller (audio codec configuration)
#---------------------------------------------------
# Actual divider number is CLK_Freq/I2C_Freq in I2C_AV_Config.v:66
create_generated_clock -name i2c_clock \
-divide_by 530 \
-source [get_ports { CLOCK2_50 }] \
[get_registers { i2c_con|mI2C_CTRL_CLK }]

# I2C controlled by state machine
set_false_path -from [get_clocks i2c_clock] -to [get_ports { I2C_SCLK I2C_SDAT }]
set_false_path -from [get_ports I2C_SDAT] -to [get_clocks i2c_clock]
