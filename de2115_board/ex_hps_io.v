//============================================================================
//
//  MiSTER Genesis hps_io replacement for DE2-115 port
//  (c)2021-2022 Alexander Kirichenko
//
//  This source file is free software: you can redistribute it and/or modify 
//  it under the terms of the GNU General Public License as published 
//  by the Free Software Foundation, either version 3 of the License, or 
//  (at your option) any later version. 
// 
//  This source file is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of 
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License 
//  along with this program.  If not, see <http://www.gnu.org/licenses/>
//
//============================================================================

//ModelSim Altera Edition 10.5b doesn't allow to use the DW param before its declaration.
//Quartus Lite does not allow declare localparam in parameters list, ANSI style.
//This is the answer from Altera at May 2015: For your information, this syntax is not yet supported in our compiler and I’ve feedback to our internal team for enhancement request.
//That's why the old style module declaration is using.
module ex_hps_io
(
	clk_sys,
	
	HPS_BUS,

	joystick_analog_0,  // not used
	joystick_analog_1,  // not used
	
	forced_scandoubler,
	status,
	
	ioctl_download,
	ioctl_index,        // not used
	ioctl_wr,
	ioctl_addr,         // in WIDE mode address will be incremented by 2
	ioctl_dout,
	ioctl_wait,
	
	ps2_key,           // not used

	ps2_mouse,         // not used
	
	gamma_bus
);

	parameter WIDE = 0;
	localparam DW = (WIDE) ? 15 : 7;
	
//ex_hps_io ports declaration
	input             clk_sys;
	
	inout      [35:0] HPS_BUS;
	
	// analog -127..+127, Y: [15:8], X: [7:0]
	output reg [15:0] joystick_analog_0;  // not used
	output reg [15:0] joystick_analog_1;  // not used
	
	output            forced_scandoubler;
	output reg [63:0] status;
	
	output            ioctl_download;
	output reg [15:0] ioctl_index;        // not used
	output            ioctl_wr;
	output     [26:0] ioctl_addr;         // in WIDE mode address will be incremented by 2
	output     [DW:0] ioctl_dout;
	input             ioctl_wait;
	
	// [8] - extended, [9] - pressed, [10] - toggles with every press/release
	output reg [10:0] ps2_key = 0;        // not used

	// [24] - toggles with every event
	output reg [24:0] ps2_mouse = 0;      // not used
	
	inout      [21:0] gamma_bus;
//end of ex_hps_io ports declaration
	
	//exHSP outputs, joystick_analog (8 bit) for lightgun - not used
	always @(posedge clk_sys)
		begin
			joystick_analog_0 <= 16'b0;
			joystick_analog_1 <= 16'b0;
		end

	//exHSP outputs - if zero, then disable scandoubler
	assign forced_scandoubler = 1'b0;


///////////////////////////////////////////////////
//***********************************the status register***********************************

	always @(posedge clk_sys)
		//           63                47                         31                         15                        0
		status <= 64'b00000000000000_00_0_0_1_11_0_00_000_00_0_0_0_0_0_0_00_00_1_0_00_000_0_0_01_0_0_0_0_10_01_1_0_010_0;

	//status[0] is reset (active HIGH)
	//status[3:1] video_mixer, scale: 3'b100 enable CRT 75%, 3'b011 enable CRT 50%, 3'b010 enable CRT 25%. 3'b001 enable hq2x scale. 3'b000 - disable scandoubler
	//status[4] system, joystick_1 and joystick_0 swap. 0 - swap disabled. Also set SER_OPT system/gen_io parameter: use SERJOYSTICK on port 1 if status[4]==1'b0, or port 2 if status[4]==1'b1
	//status[5] system, J3BUT set a 3 buttons controller mode (active LOW)
	//status[7:6] system/multitap/gen_io EXPORT parameter: 2'b00 - Japan, 2'b01 - USA, 2b'10 - Europe. status[7]=1 system, Genesis PAL mode (VDP, multitap)
	//status[9:8]=2'b10 auto region disabled (DE2_115_Genesis). Can be IGNORED. 2'b00 region by file extention, 2'b01 region by ROM header. Set status_in[7:6] HSP parameter by region_req[1:0]
	//status[10]=1 Enable VDP CRAM dots
	//status[11]=0 jt12, YM2612 ladder (active LOW)
	//status[13] DE2_115_Genesis, sav_pending status at cart BRAM SAVE/LOAD. Used by HSP. IGNORED now.
	//status[15:14] rtl/genesis_lpf, FM low pass filter 2'b00 SMD Model 1, 2'b01 SMD Model 2, 2'b10 - 8.5khz (minimal) filter
	//status[16] DE2_115_genesis, bk_load status at cart BRAM SAVE/LOAD. Used by HSP. IGNORED now.
	//status[17] DE2_115_genesis, bk_save status at cart BRAM SAVE/LOAD. Used by HSP. IGNORED now.
	//status[20:18] system/multitap/gem_io, MOUSE_OPT - mouse mode. MOUSE_OPT[0]=1 mouse connected to port1. MOUSE_OPT[1]=1 mouse connected to port2. MOUSE_OPT[2]=1 mouse Y inverted (?). MOUSE_OPT=3'b000 mouse disabled
	//status[23]=1  system, high to enable PCM interpolation on YM2612
	//status[24]=0 system/cheatcodes, enable Game Geniue (system GG_EN). 1 - disable
	//status[26:25] system, turbo mode M68K and VDP (status[26:25]==2'b11 VRAM full speed (max turbo), 2'b01 medium turbo, 2'b00 no turbo)
	//status[28:27] DE2_115_Genesis, IGNORED now. Region priority: 2'b00 - US>EU>JP, 2'b01 - EU>US>JP, 2'b10 - US>JP>EU, 2'b11 - JP>US>EU. Set status_in[7:6] HSP parameter by region_req[1:0]
	//status[29]=1 system, enabled VDP border
	//status[30]=1 then VIDEO_ARX x VIDEO_ARY = 10x7 at 320x224 mode, or VIDEO_ARX x VIDEO_ARY = 4x3 at 320x240 mode. 320x224 aspect: 1 - corrected, 0 - original
					//VIDEO_ARX x VIDEO_ARY - MiSTER video aspect ratio for HDMI.
	//status[31]=1 vdp OBJ_LIMIT_HIGH - enable more sprites and pixels per line. 0 - enable sprite limit like MD
	//status[32]=0 ENABLE_FM (active LOW)
	//status[33]=0 ENABLE_PSG (active LOW)
	//status[34]=1 enable 216p vcrop
	//status[36:35] DE2_115_Genesis/system ignore use_sdr (always on). MisTER Genesis: 2'b00 - use_sdr==|sdram_sz[2:0], where sdram_sz[1:0] is SDRAM size: 0 - none, 1 - 32MB, 2 - 64MB, 3 - 128MB (taken from  hps_io). If status[36:35] non zero - use_sdr==status[35]
	//status[39:37] system, MULTITAP type: 3'b001 - 4-way, 3b'010 - controller 2 is controller 2, mode or 3b'011 - controller 2 is controller 5. 3b'100 - J-cart. 3b'000 - multitap disabled
	//status[41:40] gun_mode, if 2'b00 in gen_io then GUN is disabled. The lightgun module, MOUSE_XY and JOY_X, JOY_Y, JOY: if 2'b11 then use mouse, 2'b01 use joypad at joystick_0, stick 0; 2'b10 or 2'b00 use joypad at joystick_1, stick 1.
	//status[42] lightgun, gun_btn_mode. Use mouse buttons if status[42]==1, else use joypad buttons
	//status[44:43] video_mixer, if 2'b00 then draw lightgun cross (?). The lightgun module: cross size 8'd1 at 0, cross size 8'd3 at 1. cross size 8'd0 at 2 and 3.
	//status[45]=1 DE2_115_Genesis, MISTer SERJOYSTICK enabled (GPIO)
	//status[46]=1 cofi_enable, active HIGH
	//status[47]=1 cofi_enable if VDP TRANSP_DETECT is HIGH too
	//status[49:48]=0 then video_freak uses ARX and ARY selected by status[30], else ARX is status[49:48]-1 and ARY is 0
	//status[53:50] CROP_OFF -16...+15, video_freak.sv/vadj
	//status[63:48] loopback to HPS_BUS.
	//Ignored {status[63:48], status[28:27], status[22:21], status[17:16], status[13], status[12], status[9:8]}


///////////////////////////////////////////////////
//***********************************ROM loader***************************************

	//exHPS signal, ioctl_index is menu index used to upload the file. If its all digits are 1 then GG code loads, else cart_download is active.
	always @(posedge clk_sys)
		ioctl_index <= 16'b0;
	
	wire	[23:1] fl_ctrl_addr;
	wire	[15:0] fl_ctrl_data;
	wire         fl_ctrl_req, fl_ctrl_ack;

	//exHSP signal, ioctl_download - indicating an active cart/GG download (1 bit). No system reset and hard_reset when it's LOW.
	//exHPS bus read/write address: ioctl_addr[3:0] - set gg_code bits when d14 or less (15 not used), !ioctl_addr allow GG_RESET (system module).
	//ioctl_addr[24:1] used by sdram module as write address for sdram port0 when ROM is loading to RAM.
	//ioctl_addr[24:0] is using by system module as ROMSZ (rom size) if emu/old_download == 1 and emu/cart_download == 0 (cart was loaded).
	//exHPS bus, ioctl_dout (aka ioctl_data) (16 bit) is data source for loading ROM to SDRAM, GameGenue code and ROM header (region, cart quirks).
	rom_loader rom_loader
	(
		.iclk(clk_sys),
		.ireset(),

		.oloading(ioctl_download),
	
		// SDRAM	
		.oram_addr(ioctl_addr),
		.oram_wrdata(ioctl_dout),
		.orom_load_wr(ioctl_wr), //active high when addr and data are ready
		.irom_load_wait(ioctl_wait), //if high, then stop next word reading from Flash while the other word is written to SDRAM

		//Flash
		.ofl_addr(fl_ctrl_addr),
		.ifl_data(fl_ctrl_data),
		.ofl_req(fl_ctrl_req),
		.ifl_ack(fl_ctrl_ack)
	);

	flash flash
	(
		.iclk(clk_sys),
		.ireset(),

		.iFL_DQ(HPS_BUS[35:28]),
		.oFL_ADDR(HPS_BUS[27:5]),
		.oFL_RST_N(HPS_BUS[4]),
		.oFL_CE_N(HPS_BUS[3]),
		.oFL_OE_N(HPS_BUS[2]),
		.oFL_WE_N(HPS_BUS[1]),
		.oFL_WP_N(HPS_BUS[0]), // write protection is disabled (set to 1)

		.ifl_addr(fl_ctrl_addr),
		.ofl_dout(fl_ctrl_data),
		.ifl_req(fl_ctrl_req),
		.ofl_ack(fl_ctrl_ack)
	);


///////////////////////////////////////////////////
//***********************************PS/2 keyboard and mouse***********************************
//No PS/2 controller now.

	always @(posedge clk_sys)
		begin
			//exHPS ps2_key (10-bit) - PS/2 keyboard signal. Not used
			//new data - ps2_key[10], key pressed - ps2_key[9], key code - ps2_key[8:0]
			ps2_key <= 11'b0;

			//exHPS ps2_mouse (24-bit) - PS/2 mouse signal. Not used
			//It's input for system/multitap/gen_io and lightgun modules
			//Cursor X coordinate - {{3{ps2_mouse[4]}},ps2_mouse[15:8]}, Y coordinate - {{3{ps2_mouse[5]}},ps2_mouse[23:16]}, new data - ps2_mouse[24], buttons - ps2_mouse[2:0]
			ps2_mouse <= 25'b0;
		end


///////////////////////////////////////////////////
//***********************************gamma_bus***********************************

	//exHSP, i/o bus
	//gamma_bus[21] is an output of emu/video_mixer module, it's 1 if the GAMMA parameter equals 1.
	//gamma_bus[20:0] = {clk_sys, gamma_en, gamma_wr, gamma_wr_addr, gamma_value};

	//gamma_bus[20] (clk_sys) is clock source for gamma_corr module
	assign gamma_bus[20] = clk_sys;
	//gamma_bus[19] (gamma_en) video_mixer/gamma_corr enable a gamma correction if 1
	assign gamma_bus[19] = 1'b0;
	//gamma_bus[18] (gamma_wr) video_mixer/gamma_corr enable write a new gamma value if 1
	assign gamma_bus[18] = 1'b0;
	//gamma_bus[17:8] (gamma_wr_addr) video_mixer/gamma_corr is a gamma_curve component address ("r" if gamma_bus[17:16] == 2'b00, "g" if gamma_bus[17:16] == 2'b01 or "b" if gamma_bus[17:16] == 2'b10)
	//don't care, because the gamma correction disabled
	assign gamma_bus[17:8] = 10'b0;
	//gamma_bus[7:0] (gamma_value) video_mixer/gamma_corr is data source for gamma_curve or gamma_curve rgb
	assign gamma_bus[7:0] = 8'b0;


///////////////////////////////////////////////////
//***********************************BRAM save/load***********************************
//No BRAM save/load now.

	//ioctls are used for BRAM save/load too.
	//img_mounted signaling that new image has been mounted
	//assign img_mounted = '1;
	//img_readonly signaling that image was mounted as read only. Is HIGH if cart hasn't BRAM. Valid only for active bit in img_mounted
	//assign img_readonly = '1;
	//img_size - size of image in bytes (64 bit). Valid only for active bit in img_mounted. If non zero and BRAM enabled, then backup file is reading from SD-card after ROM loading
	//assign img_size = '0;

endmodule
