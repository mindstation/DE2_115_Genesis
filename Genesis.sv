//============================================================================
//  MiSTer FPGAGen port to DE2-115
//  Copyright (c) 2020-2021 Alexander Kirichenko
//  Original MiSTer port: Copyright (c) 2017-2019 Sorgelig
//
//  YM2612 implementation by Jose Tejada Gomez. Twitter: @topapate
//  Original Genesis code: Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com) 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input          CLK_50M,
   input			   RESET,

	input	 [31:0]  JOY_0,JOY_1,JOY_2,JOY_3,JOY_4,	
	
	//Base video clock. Usually equals to CLK_SYS.
	output         CLK_VIDEO,
	
	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output         CE_PIXEL,
	
	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,
	
	output  [7:0]  VGA_R,
	output  [7:0]  VGA_G,
	output  [7:0]  VGA_B,
	output         VGA_HS,
	output         VGA_VS,
	output         VGA_DE,    // = ~(VBlank | HBlank)
	output         VGA_F1,
	output  [1:0]  VGA_SL,
	output         VGA_SCALER, // Force VGA scaler
	
	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	
	output        LED_USER,  // 1 - ON, 0 - OFF.
	
	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0]  LED_POWER,
	output  [1:0]  LED_DISK,

	input          CLK_AUDIO, // 24.576 MHz
	output [15:0]  AUDIO_L,
	output [15:0]  AUDIO_R,
	output         AUDIO_S,
	output  [1:0]  AUDIO_MIX,

	// SDRAM interface with lower latency
	output         SDRAM_CLK,
	output         SDRAM_CKE,
	output [12:0]  SDRAM_A,
	output  [1:0]  SDRAM_BA,
	inout  [15:0]  SDRAM_DQ,
	output         SDRAM_DQML,
	output         SDRAM_DQMH,
	output         SDRAM_nCS,
	output         SDRAM_nCAS,
	output         SDRAM_nRAS,
	output         SDRAM_nWE,
	
	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,
	
	// Open-drain User port.
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,	
	
	// FLASH interface
	input    [7:0] FL_DQ,
	output  [22:0] FL_ADDR,
	output         FL_RST_N,
	output         FL_CE_N,
	output         FL_OE_N,
	output         FL_WE_N,
	output         FL_WP_N
);

assign {UART_RTS, UART_TXD, UART_DTR} = 'b0;

// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = cart_download;

assign VGA_SCALER= 0;

// 1 - signed audio samples, 0 - unsigned
assign AUDIO_S = 1;
// 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
assign AUDIO_MIX = 0;

assign HDMI_FREEZE = 0;

wire [1:0] ar = status[49:48];
wire [7:0] arx,ary;

always_comb begin
	case(res) // {V30, H40}
		2'b00: begin // 256 x 224
			arx = 8'd64;
			ary = 8'd49;
		end

		2'b01: begin // 320 x 224
			arx = status[30] ? 8'd10: 8'd64;
			ary = status[30] ? 8'd7 : 8'd49;
		end

		2'b10: begin // 256 x 240
			arx = 8'd128;
			ary = 8'd105;
		end

		2'b11: begin // 320 x 240
			arx = status[30] ? 8'd4 : 8'd128;
			ary = status[30] ? 8'd3 : 8'd105;
		end
	endcase
end

wire       vcrop_en = status[34];
wire [3:0] vcopt    = status[53:50];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),
	.VGA_VS(VGA_VS),
	.HDMI_WIDTH(HDMI_WIDTH),
	.HDMI_HEIGHT(HDMI_HEIGHT),
	.VIDEO_ARX(VIDEO_ARX),
	.VIDEO_ARY(VIDEO_ARY),
	
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? arx : (ar - 1'd1)),
	.ARY((!ar) ? ary : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[55:54])
);

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXX XXXXXXXXXXXXXXXXXXX XX XXXXXXXXXXXXX               

`include "build_id.v"
localparam CONF_STR = {
	"Genesis;;",
	"FS,BINGENMD ;",
	"-;",
	"O67,Region,JP,US,EU;",
	"O89,Auto Region,Header,File Ext,Disabled;",
	"D2ORS,Priority,US>EU>JP,EU>US>JP,US>JP>EU,JP>US>EU;",
	"-;",
	"C,Cheats;",
	"H1OO,Cheats Enabled,Yes,No;",
	"-;",
	"D0RG,Load Backup RAM;",
	"D0RH,Save Backup RAM;",
	"D0OD,Autosave,Off,On;",
	"-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1oGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OU,320x224 Aspect,Original,Corrected;",
	"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"d5P1o2,Vertical Crop,Disabled,216p(5x);",
	"d5P1oIL,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1oMN,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1OT,Border,No,Yes;",
	"P1oEF,Composite Blend,Off,On,Adaptive;",
	"P1OA,CRAM Dots,Off,On;",
	"P1-;",
	"P1OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
	"P1OB,FM Chip,YM2612,YM3438;",
	"P1ON,HiFi PCM,No,Yes;",

	"P2,Input;",
	"P2-;",
	"P2O4,Swap Joysticks,No,Yes;",
	"P2O5,6 Buttons Mode,No,Yes;",
	"P2o57,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
	"P2-;",
	"P2OIJ,Mouse,None,Port1,Port2;",
	"P2OK,Mouse Flip Y,No,Yes;",
	"P2-;",
	"P2oD,Serial,OFF,SNAC;",
	"P2-;",
	"P2o89,Gun Control,Disabled,Joy1,Joy2,Mouse;",
	"D4P2oA,Gun Fire,Joy,Mouse;",
	"D4P2oBC,Cross,Small,Medium,Big,None;",

	"P3,Miscellaneous;",
	"P3-;",
	"P3o34,ROM Storage,Auto,SDRAM,DDR3;",
	"P3-;",
	"P3OPQ,CPU Turbo,None,Medium,High;",
	"P3OV,Sprite Limit,Normal,High;",
	"P3-;",

	"-;",
	"H3o0,Enable FM,Yes,No;",
	"H3o1,Enable PSG,Yes,No;",
	"H3-;",
	"R0,Reset;",
	"J1,A,B,C,Start,Mode,X,Y,Z;",
	"jn,A,B,R,Start,Select,X,Y,L;", // name map to SNES layout.
	"jp,Y,B,A,Start,Select,L,X,R;", // positional map to SNES layout (3 button friendly) 
	"V,v",`BUILD_DATE
};

//exHPS bidirectional signals
wire [21:0] gamma_bus;

//exHPS OUTPUTS
reg  [63:0] status;
wire [31:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;

wire  [7:0] ioctl_index;

// If forced_scandoubler is zero, then disable scandoubler
wire        forced_scandoubler = 0;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

//exHPS inputs
//ioctl_wait is a HPS bus status signal
//wire ioctl_wait;
//sd_rd and sd_wr VDNUM-1 bit signal (VD is Virtual Drive count). It is used for a SD-card selection for read or write
//for Genesis core VDNUM == 1
wire sd_rd, sd_wr;

//exHSP, i/o bus
//GAMMA parameter in video_mixer module is 0, that's why gamma_coor module isn't uses
//gamma_bus[21] is an output of video_mixer module, it's 1 if the GAMMA parameter equals 1
//gamma_bus[20:0] = HPSmodule_out{clk_sys, gamma_en, gamma_wr, gamma_wr_addr, gamma_value};
//gamma_bus[20] (clk_sys) is clock source for gamma_corr module
assign gamma_bus[20] = clk_sys;
//gamma_bus[19] (gamma_en) video_mixer/gamma_corr enable a gamma correction if 1
assign gamma_bus[19] = 1'b0;
//gamma_bus[18] (gamma_wr) video_mixer/gamma_corr enable write a new gamma value if 1
assign gamma_bus[18] = 1'b0;
//gamma_bus[17:8] (gamma_wr_addr) video_mixer/gamma_corr is a component address of gamma_curve (r if gamma_bus[17:16] == 2'b00,g if gamma_bus[17:16] == 2'b01 or b if gamma_bus[17:16] == 2'b10)
//don't care because the GAMMA parameter is low
assign gamma_bus[17:8] = 10'b0;
//gamma_bus[7:0] (gamma_value) video_mixer/gamma_corr is data source for gamma_curve or gamma_curve rgb
assign gamma_bus[7:0] = 8'b0;

//exHSP, status is a 64-bit parameter
//status[0] is reset (active HIGH)
//status[3:1] video_mixer, scandoubler: 3'b100 enable CRT 75%, 3'b011 enable CRT 50%, 3'b010 enable CRT 25%. 3'b001 enable hq2x scale. 3'b000 - disable scandoubler
//status[4] system, joystick_1 and joystick_0 swap. 0 - swap disabled. Also set SER_OPT system/gen_io parameter: use SERJOYSTICK on port 1 if status[4]==1'b1, or port 2 if status[4]==1'b0
//status[5] system, J3BUT set a 3 buttons controller mode (active LOW)
//status[7:6] system/multitap/gen_io EXPORT parameter: maybe 2'b00 - Japan, 2'b01 - USA, 2b'10 - Europe. status[7]=1 system, Genesis PAL mode (VDP, multitap)
//status[9:8]=2'b10 auto region disabled (DE2_115_Genesis). Can be IGNORED. 2'b00 region by file extention, 2'b01 region by ROM header. Set status_in[7:6] HSP parameter by region_req[1:0]
//status[10]=1 Enable VDP CRAM dots
//status[11]=0 jt12, YM2612 ladder (active LOW)
//status[13] DE2_115_Genesis, sav_pending status at cart BRAM SAVE/LOAD. Used by HSP. Can be IGNORED
//status[15:14] rtl/genesis_lpf, FM low pass filter 2'b00 SMD Model 1, 2'b01 SMD Model 2, 2'b10 - 8.5khz (minimal) filter
//status[16] DE2_115_genesis, bk_load status at cart BRAM SAVE/LOAD. Used by HSP. Can be IGNORED
//status[17] DE2_115_genesis, bk_save status at cart BRAM SAVE/LOAD. Used by HSP. Can be IGNORED
//status[20:18] system/multitap/gem_io, MOUSE_OPT - mouse mode. MOUSE_OPT[0]=1 mouse connected to port1. MOUSE_OPT[1]=1 mouse connected to port2. MOUSE_OPT[2]=1 mouse Y inverted (?). MOUSE_OPT=3'b000 mouse disabled
//status[23]=1  system, high to enable PCM interpolation on YM2612 mode
//status[24]=0 system/cheatcodes, enable Game Geniue (system GG_EN). 1 - disable
//status[26:25] system, turbo mode M68K and VDP (status[26:25]==2'b11 VRAM full speed (max turbo), 2'b01 medium turbo, 2'b00 no turbo)
//status[28:27] DE2_115_Genesis, Can be IGNORED. Region priority: 2'b00 - US>EU>JP, 2'b01 - EU>US>JP, 2'b10 - US>JP>EU, 2'b11 - JP>US>EU. Set status_in[7:6] HSP parameter by region_req[1:0]
//status[29]=1 system, enabled VDP border
//status[30]=1 then VIDEO_ARX x VIDEO_ARY = 10x7 at 320x224 mode, or VIDEO_ARX x VIDEO_ARY = 4x3 at 320x240 mode. 320x224 aspect: 1 - corrected, 0 - original
					//VIDEO_ARX x VIDEO_ARY - MiSTER legacy, video aspect ratio for HDMI.
//status[31]=1 vdp OBJ_LIMIT_HIGH - enable more sprites and pixels per line. 0 - enable sprite limit like MD
//status[32]=0 ENABLE_FM (active LOW)
//status[33]=0 ENABLE_PSG (active LOW)

//vcrop_en = status[34] CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0)

//status[36:35] DE2_115_Genesis/system, use_sdr. 2'b00 - use_sdr==|sdram_sz[2:0], where sdram_sz[1:0] is SDRAM size: 0 - none, 1 - 32MB, 2 - 64MB, 3 - 128MB (taken from  hps_io). If status[36:35] non zero - use_sdr==status[35]
//status[39:37] system, MULTITAP type: 3'b001 - 4-way, 3b'010 - controller 2 is controller 2, mode or 3b'011 - controller 2 is controller 5. 3b'100 - J-cart. 3b'000 - multitap disabled
//status[41:40] gun_mode, if 2'b00 in gen_io then GUN disabled. lightgun, MOUSE_XY and JOY_X, JOY_Y, JOY: if 2'b11 then use mouse, 2'b01 use joypad at joystick_0, stick 0; 2'b10 or 2'b00 use joypad at joystick_1, stick 1
//status[42] lightgun, gun_btn_mode. Use mouse buttons if status[42]==1, else use joypad buttons
//status[44:43] video_mixer 2'b00 draw lightgun cross. lightgun - cross size 8'd1 at 0, cross size 8'd3 at 1. cross size 8'd0 at 2 and 3
//status[45]=1 DE2_115_Genesis, MISTer SERJOYSTICK enabled (GPIO)
//status[46]=1 cofi_enable, active HIGH
//status[47]=1 cofi_enable if VDP TRANSP_DETECT is HIGH too
//ar = status[49:48]
//vcopt    = status[53:50] CROP_OFF
//status[63:48] loopback to HPS_BUS. Ignore {status[63:48], status[34], status[28:27], status[22:21], status[17:16], status[13], status[12], status[9:8]}

always @(posedge clk_sys)
//           63               47                         31                         15                        0
status <= 64'b0000000000000000_0_0_0_11_0_00_000_00_0_0_0_0_0_0_00_00_1_0_00_000_0_0_01_0_0_0_0_10_00_0_0_001_0;

assign joystick_0 = JOY_0;
assign joystick_1 = JOY_1;
assign joystick_2 = JOY_2;
assign joystick_3 = JOY_3;
assign joystick_4 = JOY_4;

//exHSP, joystick_analog (8 bit) for lightgun - not used
assign joy0_y = '0;
assign joy0_x = '0;
assign joy1_y = '0;
assign joy1_x = '0;

//exHSP signal, ioctl_download - indicating an active cart/GG download (1 bit). No system reset and hard_reset when it's LOW
//exHPS signal, menu index used to upload the file (8 bit). If it's LOW, then cart_download will be HIGH when ioctl_download is HIGH
assign ioctl_index = '0;
//exHPS bus write status (1 bit). If HIGH then GG loading starts by cart_download. Also a GG module reset depends on it
//exHPS bus read/write address: ioctl_addr[3:0] - set gg_code bits when d14 or less (15 not used), !ioctl_addr allow GG_RESET (system module)
//ioctl_addr[24:1] used by sdram module as write address for sdram port0 when ROM uploads to RAM
//ioctl_addr[24:0] was using by system module as ROMSZ (rom size) if old_download == 1 and cart_download == 0 (cart was loaded). Now rom_sz is set manually
//exHPS bus, ioctl_data (16 bit) is data source for loading cart ROM to SDRAM, GameGenue code and ROM header (region, cart quirks)

//Also using for BRAM save/load, not used
//img_mounted signaling that new image has been mounted
//assign img_mounted = '1;
//img_readonly signaling that image was mounted as read only. Is HIGH if cart hasn't BRAM. Valid only for active bit in img_mounted
//assign img_readonly = '1;
//img_size - size of image in bytes (64 bit). Valid only for active bit in img_mounted. If non zero and BRAM enabled, then backup file is reading from SD-card after ROM loading
//assign img_size = '0;

//exHPS sdram_sz bus (16 bit, used 3). Enable use SDRAM if non zero. hps_io defines next SDRAM sizes: 0 - none, 1 - 32MB, 2 - 64MB, 3 - 128MB.
//assign sdram_sz = 16'b0000000000000010;

//exHPS ps2_key (10-bit) - PS/2 keyboard signal. Not used
//new data - ps2_key[10], key pressed - ps2_key[9], key code - ps2_key[8:0]
assign ps2_key = '0;

//exHPS ps2_mouse (24-bit) - PS/2 mouse signal. Not used
//It's input for system/multitap/gen_io and lightgun modules
//Cursor X coordinate - {{3{ps2_mouse[4]}},ps2_mouse[15:8]}, Y coordinate - {{3{ps2_mouse[5]}},ps2_mouse[23:16]}, new data - ps2_mouse[24], buttons - ps2_mouse[2:0]
assign ps2_mouse = '0;

wire [1:0] gun_mode = status[41:40];
wire       gun_btn_mode = status[42];

wire code_index = &ioctl_index;
wire cart_download = rom_loading & ~code_index;
//GameGenue code loading
wire code_download = rom_loading & code_index;

//There was an osd_btn always process (line 330 MiSTER/Genesis.sv)

///////////////////////////////////////////////////
wire clk_sys, clk_ram, locked;

pll pll
(
	.inclk0(CLK_50M),
	.c0(clk_sys),
	.c1(clk_ram),
	.c3(), //SignalTap
	.locked(locked)
);

///////////////////////////////////////////////////
// Code loading for WIDE IO (16 bit)
reg [128:0] gg_code;
wire        gg_available;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk_sys) begin
	gg_code[128] <= 1'b0;

	if (code_download & orom_load_wr) begin
		case (loadrom_addr[3:0])
			0:  gg_code[111:96]  <= loadrom_wdata; // Flags Bottom Word
			2:  gg_code[127:112] <= loadrom_wdata; // Flags Top Word
			4:  gg_code[79:64]   <= loadrom_wdata; // Address Bottom Word
			6:  gg_code[95:80]   <= loadrom_wdata; // Address Top Word
			8:  gg_code[47:32]   <= loadrom_wdata; // Compare Bottom Word
			10: gg_code[63:48]   <= loadrom_wdata; // Compare top Word
			12: gg_code[15:0]    <= loadrom_wdata; // Replace Bottom Word
			14: begin
				gg_code[31:16]   <= loadrom_wdata; // Replace Top Word
				gg_code[128]     <=  1'b1;      // Clock it in
			end
		endcase
	end
end

///////////////////////////////////////////////////
wire [3:0] r, g, b;
wire vs,hs;
wire ce_pix;
wire hblank, vblank;
wire interlace;
wire [1:0] resolution;

//A global reset signal (active HIGHT)
wire reset = RESET;

wire [7:0] color_lut[16] = '{
	8'd0,   8'd27,  8'd49,  8'd71,
	8'd87,  8'd103, 8'd119, 8'd130,
	8'd146, 8'd157, 8'd174, 8'd190,
	8'd206, 8'd228, 8'd255, 8'd255
};

//***********************************fpgagen top module***********************************
system system
(
//INPUTS
	.RESET_N(~reset),
	.MCLK(clk_sys),

	.LOADING(cart_download),
	.EXPORT(|status[7:6]),
	.PAL(PAL),
	.SRAM_QUIRK(sram_quirk),
	.SRAM00_QUIRK(sram00_quirk),
	.EEPROM_QUIRK(eeprom_quirk),
	.NORAM_QUIRK(noram_quirk),
	.PIER_QUIRK(pier_quirk),
	.FMBUSY_QUIRK(fmbusy_quirk),

	.TURBO(status[26:25]),

	.BORDER(status[29]),
	.CRAM_DOTS(status[10]),

	.FAST_FIFO(fifo_quirk),
	.SVP_QUIRK(svp_quirk),
	.SCHAN_QUIRK(schan_quirk),

	.GG_RESET(code_download && orom_load_wr && !loadrom_addr),
	.GG_EN(status[24]),
	.GG_CODE(gg_code),

	.J3BUT(~status[5]),
	.JOY_1(status[4] ^ status[45] ? joystick_1 : joystick_0),
	.JOY_2(status[4] ^ status[45] ? joystick_0 : joystick_1),
	.JOY_3(joystick_2),
	.JOY_4(joystick_3),
	.JOY_5(joystick_4),
	.MULTITAP(status[39:37]),

	.MOUSE(ps2_mouse),
	.MOUSE_OPT(status[20:18]),

	.GUN_OPT(|gun_mode),
	.GUN_TYPE(gun_type),
	.GUN_SENSOR(lg_sensor),
	.GUN_A(lg_a),
	.GUN_B(lg_b),
	.GUN_C(lg_c),
	.GUN_START(lg_start),

	.SERJOYSTICK_IN(SERJOYSTICK_IN),
	.SER_OPT(SER_OPT),

	.ENABLE_FM(~dbg_menu | ~status[32]),
	.ENABLE_PSG(~dbg_menu | ~status[33]),
	.EN_HIFI_PCM(status[23]), // Option "N"
	.LADDER(~status[11]),
	.LPF_MODE(status[15:14]),

	.OBJ_LIMIT_HIGH(status[31]),

	.BRAM_A('b0),
	.BRAM_DI('b0),
	.BRAM_WE('b0),
	
	.ROMSZ(rom_sz[24:1]),
	.ROM_DATA(sdrom_data),
	.ROM_ACK(sdrom_rdack),

// SVP inputs. ROM.
	.ROM_DATA2(rom_data2),
	.ROM_ACK2(rom_rdack2),

// debug
	.PAUSE_EN(DBG_PAUSE_EN),
	.BGA_EN(VDP_BGA_EN),
	.BGB_EN(VDP_BGB_EN),
	.SPR_EN(VDP_SPR_EN),
	
//OUTPUTS
	.DAC_LDATA(AUDIO_L),
	.DAC_RDATA(AUDIO_R),

	.RED(r),
	.GREEN(g),
	.BLUE(b),
	.VS(vs),
	.HS(hs),
	.HBL(hblank),
	.VBL(vblank),
	.CE_PIX(ce_pix),
//input for HPS. sus_top/vga_hs_osd. Not used.
	.FIELD(VGA_F1),
	.INTERLACE(interlace),
	.RESOLUTION(resolution),

	.GG_AVAILABLE(gg_available),

	.SERJOYSTICK_OUT(SERJOYSTICK_OUT),

//input for HPS. Not used.
//	.BRAM_DO(sd_buff_din),
//	.BRAM_CHANGE(bk_change),

	.ROM_ADDR(rom_addr),
	.ROM_WDATA(rom_wdata),
	.ROM_WE(rom_we),
	.ROM_BE(rom_be),
	.ROM_REQ(rom_req),

// SVP outputs. ROM.
	.ROM_ADDR2(rom_addr2),
	.ROM_REQ2(rom_rd2),

	.TRANSP_DETECT(TRANSP_DETECT)
);

wire TRANSP_DETECT;
wire cofi_enable = status[46] || (status[47] && TRANSP_DETECT);

wire PAL = status[7];

reg new_vmode;
always @(posedge clk_sys) begin
	reg old_pal;
	int to;
	
	if(~(reset | cart_download)) begin
		old_pal <= PAL;
		if(old_pal != PAL) to <= 5000000;
	end
	else to <= 5000000;
	
	if(to) begin
		to <= to - 1;
		if(to == 1) new_vmode <= ~new_vmode;
	end
end

reg dbg_menu = 0;
always @(posedge clk_sys) begin
	reg old_stb;
	reg enter = 0;
	reg esc = 0;
	
	old_stb <= ps2_key[10];
	if(old_stb ^ ps2_key[10]) begin
		if(ps2_key[7:0] == 'h5A) enter <= ps2_key[9];
		if(ps2_key[7:0] == 'h76) esc   <= ps2_key[9];
	end
	
	if(enter & esc) begin
		dbg_menu <= ~dbg_menu;
		enter <= 0;
		esc <= 0;
	end
end

//lock resolution for the whole frame.
reg [1:0] res;
always @(posedge clk_sys) begin
	reg old_vbl;
	
	old_vbl <= vblank;
	if(old_vbl & ~vblank) res <= resolution;
end

wire [2:0] scale = status[3:1];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign CLK_VIDEO = clk_ram;
assign VGA_SL = {~interlace,~interlace}&sl[1:0];

//***********************************Composite-like horizontal blending***********************************
reg old_ce_pix;
always @(posedge CLK_VIDEO) old_ce_pix <= ce_pix;

wire [7:0] red, green, blue;

cofi coffee (
	.clk(clk_sys),
	.pix_ce(ce_pix),
	.enable(cofi_enable),

	.hblank(hblank),
	.vblank(vblank),
	.hs(hs),
	.vs(vs),
	.red(color_lut[r]),
	.green(color_lut[g]),
	.blue(color_lut[b]),

	.hblank_out(hblank_c),
	.vblank_out(vblank_c),
	.hs_out(hs_c),
	.vs_out(vs_c),
	.red_out(red),
	.green_out(green),
	.blue_out(blue)
);

//***********************************gamma, scandoubler, scanlines***********************************

wire hs_c, vs_c, hblank_c, vblank_c;

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE),

	.gamma_bus(gamma_bus),

	.CLK_VIDEO(CLK_VIDEO),
	.CE_PIXEL(CE_PIXEL),

	.ce_pix(~old_ce_pix & ce_pix),
	
	.scandoubler(~interlace && scale),
	.hq2x(scale==1),
	.freeze_sync(),

	.R((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[0]}} : red),
	.G((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[1]}} : green),
	.B((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[2]}} : blue),

	// Positive pulses.
	.HSync(hs_c),
	.VSync(vs_c),
	.HBlank(hblank_c),
	.VBlank(vblank_c)
);

//***********************************lightgun emulation by mouse or joypad***********************************
wire [2:0] lg_target;
wire       lg_sensor;
wire       lg_a;
wire       lg_b;
wire       lg_c;
wire       lg_start;

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(&gun_mode),

	.JOY_X(gun_mode[0] ? joy0_x : joy1_x),
	.JOY_Y(gun_mode[0] ? joy0_y : joy1_y),
	.JOY(gun_mode[0] ? joystick_0 : joystick_1),

	.RELOAD(gun_type),

	.HDE(~hblank_c),
	.VDE(~vblank_c),
	.CE_PIX(ce_pix),
	.H40(res[0]),

	.BTN_MODE(gun_btn_mode),
	.SIZE(status[44:43]),
	.SENSOR_DELAY(gun_sensor_delay),

	.TARGET(lg_target),
	.SENSOR(lg_sensor),
	.BTN_A(lg_a),
	.BTN_B(lg_b),
	.BTN_C(lg_c),
	.BTN_START(lg_start)
);

///////////////////////////////////////////////////
//***********************************sdram module***********************************
//

//DE2-115 ISSI IS42S16320D-7TL - 100MHz at CAS=2 or 143MHz at CAS=3.
sdram sdram
(	.SDRAM_DQ(SDRAM_DQ),   // 16 bit bidirectional data bus
	.SDRAM_A(SDRAM_A),    // 13 bit multiplexed address bus
	.SDRAM_DQML(SDRAM_DQML), // byte mask
	.SDRAM_DQMH(SDRAM_DQMH), // byte mask
	.SDRAM_BA(SDRAM_BA),   // two banks
	.SDRAM_nCS(SDRAM_nCS),  // a single chip select
	.SDRAM_nWE(SDRAM_nWE),  // write enable
	.SDRAM_nRAS(SDRAM_nRAS), // row address select
	.SDRAM_nCAS(SDRAM_nCAS), // columns address select
	.SDRAM_CLK(SDRAM_CLK),
	.SDRAM_CKE(SDRAM_CKE),

	.init(~locked),
	.clk(clk_ram),

	.addr0(loadrom_addr[24:1]),
	.din0({loadrom_wdata[7:0],loadrom_wdata[15:8]}),
	.dout0(),
	.wrl0(1),
	.wrh0(1),
	.req0(rom_wr),
	.ack0(sdrom_wrack),

//if addr0 is sequential columns wrtitting use this .addr1({rom_addr[24:23],rom_addr[9:1],rom_addr[22:10]}),
	.addr1(rom_addr),
	.din1(rom_wdata),
	.dout1(sdrom_data),
	.wrl1(rom_we & rom_be[0]),
	.wrh1(rom_we & rom_be[1]),
	.req1(rom_req),
	.ack1(sdrom_rdack),

//SVP ROM port
	.addr2({4'b0,rom_addr2}),
	.din2(0),
	.dout2(rom_data2),
	.wrl2(0),
	.wrh2(0),
	.req2(rom_rd2),
	.ack2(rom_rdack2)
);

wire [24:1] rom_addr;
wire [20:1] rom_addr2;
wire [15:0] sdrom_data, rom_data2, rom_wdata;
wire  [1:0] rom_be;
wire rom_req, sdrom_rdack, rom_rd2, rom_rdack2, rom_we;

///////////////////////////////////////////////////
//***********************************ROM loading***********************************
wire	[24:0] loadrom_addr;
wire	[15:0] loadrom_wdata;
wire			 rom_loading, orom_load_wr, irom_load_wait;
reg			 rom_load_wait;
wire	[23:1] fl_ctrl_addr;
wire	[15:0] fl_ctrl_data;
wire         fl_ctrl_req, fl_ctrl_ack;

rom_loader rom_loader
(
	.iclk(clk_sys),
	.ireset(),

	.oloading(rom_loading),
	
// SDRAM	
	.oram_addr(loadrom_addr),
	.oram_wrdata(loadrom_wdata),
	.orom_load_wr(orom_load_wr), //active high when addr and data are ready
	.irom_load_wait(rom_load_wait), //ex-ioctl_wait, if high, then stop next word reading from Flash while the other word is written to SDRAM

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

	.iFL_DQ(FL_DQ),
	.oFL_ADDR(FL_ADDR),
	.oFL_RST_N(FL_RST_N),
	.oFL_CE_N(FL_CE_N),
	.oFL_OE_N(FL_OE_N),
	.oFL_WE_N(FL_WE_N),
	.oFL_WP_N(FL_WP_N), // write protection is disabled (set to 1)
	
	.ifl_addr(fl_ctrl_addr),
	.ofl_dout(fl_ctrl_data),
	.ifl_req(fl_ctrl_req),
	.ofl_ack(fl_ctrl_ack)
);

reg  rom_wr = 0;
wire sdrom_wrack;
reg [24:0] rom_sz;
//sytem module, ROM size
//1104B hello.bin assign rom_sz = 24'b000000000000010001010000;
//1000B psg_tone.bin assign rom_sz = 24'b000000000000001111101000;
//1222B hello_z80.bin assign rom_sz = 24'b000000000000010011000110;
//1628B gamepad.bin assign rom_sz = 24'b000000000000011001011100;
//512kB assign rom_sz = 24'b000001000000000000000000;
//1MB   assign rom_sz = 24'b000010000000000000000000;
//2MB   assign rom_sz = 24'b000100000000000000000000;
//4MB   
assign rom_sz = 24'b001000000000000000000000;
always @(posedge clk_sys) begin
	reg old_download, old_reset;
	old_download <= cart_download;
	old_reset <= reset;

	if(~old_reset && reset) rom_load_wait <= 0;
//	if (old_download & ~cart_download) rom_sz <= loadrom_addr[24:0];

	if (cart_download & orom_load_wr) begin
		rom_load_wait <= 1;
		rom_wr <= ~rom_wr;
	end else if(rom_load_wait && (rom_wr == sdrom_wrack)) begin
		rom_load_wait <= 0;
	end
end

wire [3:0] hrgn = loadrom_wdata[3:0] - 4'd7;

reg cart_hdr_ready = 0;
reg hdr_j=0,hdr_u=0,hdr_e=0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= cart_download;

	if(~old_download && cart_download) {hdr_j,hdr_u,hdr_e} <= 0;
	if(old_download && ~cart_download) cart_hdr_ready <= 0;

	if(orom_load_wr & cart_download) begin
		if(loadrom_addr == 'h1F0) begin
			if(loadrom_addr[7:0] == "J") hdr_j <= 1;
			else if(loadrom_wdata[7:0] == "U") hdr_u <= 1;
			else if(loadrom_wdata[7:0] == "E") hdr_e <= 1;
			else if(loadrom_wdata[7:0] >= "0" && loadrom_wdata[7:0] <= "9") {hdr_e, hdr_u, hdr_j} <= {loadrom_wdata[3], loadrom_wdata[2], loadrom_wdata[0]};
			else if(loadrom_wdata[7:0] >= "A" && loadrom_wdata[7:0] <= "F") {hdr_e, hdr_u, hdr_j} <= {      hrgn[3],       hrgn[2],       hrgn[0]};
		end		
		if(loadrom_addr == 'h1F2) begin
			if(loadrom_wdata[7:0] == "J") hdr_j <= 1;
			else if(loadrom_wdata[7:0] == "U") hdr_u <= 1;
			else if(loadrom_wdata[7:0] == "E") hdr_e <= 1;
		end
		if(loadrom_addr == 'h1F0) begin
			if(loadrom_wdata[15:8] == "J") hdr_j <= 1;
			else if(loadrom_wdata[15:8] == "U") hdr_u <= 1;
			else if(loadrom_wdata[15:8] == "E") hdr_e <= 1;
		end
		if(loadrom_addr == 'h200) cart_hdr_ready <= 1;
	end
end

reg sram_quirk = 0;
reg sram00_quirk = 0;
reg eeprom_quirk = 0;
reg fifo_quirk = 0;
reg noram_quirk = 0;
reg pier_quirk = 0;
reg svp_quirk = 0;
reg fmbusy_quirk = 0;
reg schan_quirk = 0;
reg gun_type = 0;
reg [7:0] gun_sensor_delay = 8'd44;
always @(posedge clk_sys) begin
	reg [63:0] cart_id;
	reg old_download;
	old_download <= cart_download;

	if(~old_download && cart_download) {fifo_quirk,eeprom_quirk,sram_quirk,sram00_quirk,noram_quirk,pier_quirk,svp_quirk,fmbusy_quirk,schan_quirk} <= 0;

	if(orom_load_wr & cart_download) begin
		if(loadrom_addr == 'h182) cart_id[63:56] <= loadrom_wdata[15:8];
		if(loadrom_addr == 'h184) cart_id[55:40] <= {loadrom_wdata[7:0],loadrom_wdata[15:8]};
		if(loadrom_addr == 'h186) cart_id[39:24] <= {loadrom_wdata[7:0],loadrom_wdata[15:8]};
		if(loadrom_addr == 'h188) cart_id[23:08] <= {loadrom_wdata[7:0],loadrom_wdata[15:8]};
		if(loadrom_addr == 'h18A) cart_id[07:00] <= loadrom_wdata[7:0];
		if(loadrom_addr == 'h18C) begin
			     if(cart_id == "T-081276") sram_quirk   <= 1; // NFL Quarterback Club
			else if(cart_id == "T-81406 ") sram_quirk   <= 1; // NBA Jam TE
			else if(cart_id == "T-081586") sram_quirk   <= 1; // NFL Quarterback Club '96
			else if(cart_id == "T-81576 ") sram_quirk   <= 1; // College Slam
			else if(cart_id == "T-81476 ") sram_quirk   <= 1; // Frank Thomas Big Hurt Baseball
			else if(cart_id == "MK-1215 ") eeprom_quirk <= 1; // Evander Real Deal Holyfield's Boxing
			else if(cart_id == "G-4060  ") eeprom_quirk <= 1; // Wonder Boy
			else if(cart_id == "00001211") eeprom_quirk <= 1; // Sports Talk Baseball
			else if(cart_id == "MK-1228 ") eeprom_quirk <= 1; // Greatest Heavyweights
			else if(cart_id == "G-5538  ") eeprom_quirk <= 1; // Greatest Heavyweights JP
			else if(cart_id == "00004076") eeprom_quirk <= 1; // Honoo no Toukyuuji Dodge Danpei
			else if(cart_id == "T-12046 ") eeprom_quirk <= 1; // Mega Man - The Wily Wars 
			else if(cart_id == "T-12053 ") eeprom_quirk <= 1; // Rockman Mega World 
			else if(cart_id == "G-4524  ") eeprom_quirk <= 1; // Ninja Burai Densetsu
			else if(cart_id == "T-113016") noram_quirk  <= 1; // Puggsy fake ram check
			else if(cart_id == "T-89016 ") fifo_quirk   <= 1; // Clue
			else if(cart_id == "T-574023") pier_quirk   <= 1; // Pier Solar Reprint
			else if(cart_id == "T-574013") pier_quirk   <= 1; // Pier Solar 1st Edition
			else if(cart_id == "MK-1229 ") svp_quirk    <= 1; // Virtua Racing EU/US
			else if(cart_id == "G-7001  ") svp_quirk    <= 1; // Virtua Racing JP
			else if(cart_id == "T-35036 ") fmbusy_quirk <= 1; // Hellfire US
			else if(cart_id == "T-25073 ") fmbusy_quirk <= 1; // Hellfire JP
			else if(cart_id == "MK-1137-") fmbusy_quirk <= 1; // Hellfire EU
			else if(cart_id == "T-68???-") schan_quirk  <= 1; // Game no Kanzume Otokuyou
			else if(cart_id == " GM 0000") sram00_quirk <= 1; // Sonic 1 Remastered
			
			// Lightgun device and timing offsets
			if(cart_id == "MK-1533 ") begin						  // Body Count
				gun_type  <= 0;
				gun_sensor_delay <= 8'd100;
			end
			else if(cart_id == "T-95096-") begin				  // Lethal Enforcers
				gun_type  <= 1;
				gun_sensor_delay <= 8'd52;
			end
			else if(cart_id == "T-95136-") begin				  // Lethal Enforcers II
				gun_type  <= 1;
				gun_sensor_delay <= 8'd30;
			end
			else if(cart_id == "MK-1658 ") begin				  // Menacer 6-in-1
				gun_type  <= 0;
				gun_sensor_delay <= 8'd120;
			end
			else if(cart_id == "T-081156") begin				  // T2: The Arcade Game
				gun_type  <= 0;
				gun_sensor_delay <= 8'd126;
			end
			else begin
				gun_type  <= 0;
				gun_sensor_delay <= 8'd44;
			end
		end
	end
end

/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////
//No SD support. SAVE/LOAD for SD cart removed.

////////////////  MiSTER SERJOYSTICK /////////////////////////
wire [7:0] SERJOYSTICK_IN;
wire [7:0] SERJOYSTICK_OUT;
wire [1:0] SER_OPT;

always @(posedge clk_sys) begin
	if (status[45]) begin
		SERJOYSTICK_IN[0] <= USER_IN[1];//up
		SERJOYSTICK_IN[1] <= USER_IN[0];//down
		SERJOYSTICK_IN[2] <= USER_IN[5];//left
		SERJOYSTICK_IN[3] <= USER_IN[3];//right
		SERJOYSTICK_IN[4] <= USER_IN[2];//b TL
		SERJOYSTICK_IN[5] <= USER_IN[6];//c TR GPIO7
		SERJOYSTICK_IN[6] <= USER_IN[4];//  TH
		SERJOYSTICK_IN[7] <= 0;
		SER_OPT[0] <= ~status[4];
		SER_OPT[1] <= status[4];
		USER_OUT[1] <= SERJOYSTICK_OUT[0];
		USER_OUT[0] <= SERJOYSTICK_OUT[1];
		USER_OUT[5] <= SERJOYSTICK_OUT[2];
		USER_OUT[3] <= SERJOYSTICK_OUT[3];
		USER_OUT[2] <= SERJOYSTICK_OUT[4];
		USER_OUT[6] <= SERJOYSTICK_OUT[5];
		USER_OUT[4] <= SERJOYSTICK_OUT[6];
	end else begin
		SER_OPT  <= 0;
		USER_OUT <= '1;
	end
end

////////////////  DEBUG /////////////////////////
reg       VDP_BGA_EN = 1;
reg       VDP_BGB_EN = 1;
reg       VDP_SPR_EN = 1;
//reg [1:0] VDP_GRID_EN = '0;
reg       DBG_PAUSE_EN = 0;

`ifdef DEBUG_BUILD

always @(posedge clk_sys) begin
	reg old_state = 0;

	old_state <= ps2_key[10];

	if((ps2_key[10] != old_state) && pressed) begin
		casex(code)
			'h003: begin VDP_BGA_EN <= ~VDP_BGA_EN; end 	// F5
			'h00B: begin VDP_BGB_EN <= ~VDP_BGB_EN; end 	// F6
			'h083: begin VDP_SPR_EN <= ~VDP_SPR_EN; end 	// F7
			//'h00A: begin VDP_GRID_EN <= VDP_GRID_EN + 2'd1; end 	// F8
			'h001: begin DBG_PAUSE_EN <= ~DBG_PAUSE_EN; end 	// F9
		endcase
	end
end

`endif

endmodule
