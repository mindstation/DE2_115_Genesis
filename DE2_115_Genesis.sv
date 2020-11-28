//============================================================================
//  FPGAGen port to MiSTer
//  Copyright (c) 2017-2019 Sorgelig
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

module DE2_115_Genesis
(
	//Master input clock
	input         CLOCK_50,

	// switch inputs
	// SW[0] - RESET
	// SW[3] - ROM download
	// SW[17] - joystick_0_A, SW[16] - joystick_0_B, SW[15] - joystick_0_C, SW[14] - joystick_0_START
   input  [17:0] SW, // Toggle Switch[17:0]

	// button inputs
	// KEY[0]  - joystick_0_Right, KEY[3] - joystick_0_Left, KEY[2] - joystick_0_Up, KEY[1] - joystick_0_Down
	input   [3:0] KEY,
	
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_CLK,
	output        VGA_BLANK,
	output        VGA_SYNC,
	
	output [17:0] LEDR,
	output  [8:0] LEDG,	

	// I2C for Audio codec configuration
	output        I2C_SCLK,
	inout         I2C_SDAT,
	// I2S for Audio codec bit stream
	inout         AUD_BCLK,
	output        AUD_DACDAT,
	inout         AUD_DACLRCK,
	output        AUD_XCK,
	
	// SD-SPI - not used (SD_SCK, SD_MOSI, SD_CS are set to Z state)
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	// SDRAM interface with lower latency
	output        DRAM_CLK,
	output        DRAM_CKE,
	output [12:0] DRAM_ADDR,
	output  [1:0] DRAM_BA,
	inout  [15:0] DRAM_DQ,
	output  [1:0] DRAM_DQM,
	output        DRAM_CS_N,
	output        DRAM_CAS_N,
	output        DRAM_RAS_N,
	output        DRAM_WE_N,
	
	// [35:30] Open-drain User port (MiSTER SERJOYSTICK).
	inout [35:30] GPIO
);

//A global reset signal (active HIGHT)
wire RESET = SW[0];

//BUTTONS old output DE2_115_genesis module for MiSTer top module
//assign BUTTONS   = osd_btn;

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

wire [7:0] VIDEO_ARX, VIDEO_ARY;
always_comb begin
	if (status[10]) begin
		VIDEO_ARX = 8'd16;
		VIDEO_ARY = 8'd9;
	end else begin
		case(res) // {V30, H40}
			2'b00: begin // 256 x 224
				VIDEO_ARX = 8'd64;
				VIDEO_ARY = 8'd49;
			end

			2'b01: begin // 320 x 224
				VIDEO_ARX = status[30] ? 8'd10: 8'd64;
				VIDEO_ARY = status[30] ? 8'd7 : 8'd49;
			end

			2'b10: begin // 256 x 240
				VIDEO_ARX = 8'd128;
				VIDEO_ARY = 8'd105;
			end

			2'b11: begin // 320 x 240
				VIDEO_ARX = status[30] ? 8'd4 : 8'd128;
				VIDEO_ARY = status[30] ? 8'd3 : 8'd105;
			end
		endcase
	end
end

//assign VIDEO_ARX = status[10] ? 8'd16 : ((status[30] && wide_ar) ? 8'd10 : 8'd64);
//assign VIDEO_ARY = status[10] ? 8'd9  : ((status[30] && wide_ar) ? 8'd7  : 8'd49);

// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
wire  [1:0] led_power, led_disk;
wire        led_user;

assign led_disk  = 0;
assign led_power = 0;
assign led_user  = cart_download | sav_pending;

assign LEDG[0] = led_disk[1] ? led_disk[0] : 1'b0;
assign LEDG[1] = led_power[1] ? led_power[0] : 1'b0;
assign LEDR[0] = led_user;

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
	"O89,Auto Region,File Ext,Header,Disabled;",
	"D2ORS,Priority,US>EU>JP,EU>US>JP,US>JP>EU,JP>US>EU;",
	"-;",
	"C,Cheats;",
	"H1OO,Cheats Enabled,Yes,No;",
	"-;",
	"D0RG,Load Backup RAM;",
	"D0RH,Save Backup RAM;",
	"D0OD,Autosave,Off,On;",
	"-;",
	"OA,Aspect Ratio,4:3,16:9;",
	"OU,320x224 Aspect,Original,Corrected;",
	"O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"OT,Border,No,Yes;",
	"oEF,Composite Blend,Off,On,Adaptive;",
	"-;",
	"OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
	"OB,FM Chip,YM2612,YM3438;",
	"ON,HiFi PCM,No,Yes;",
	"-;",
	"O4,Swap Joysticks,No,Yes;",
	"O5,6 Buttons Mode,No,Yes;",
	"o57,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
	"OIJ,Mouse,None,Port1,Port2;",
	"OK,Mouse Flip Y,No,Yes;",
	"oD,Serial,OFF,SNAC;",
	"-;",
	"o89,Gun Control,Disabled,Joy1,Joy2,Mouse;",
	"H4oA,Gun Fire,Joy,Mouse;",
	"H4oBC,Cross,Small,Medium,Big,None;",
	"-;",
	"o34,ROM Storage,Auto,SDRAM,DDR3;",
	"-;",
	"OPQ,CPU Turbo,None,Medium,High;",
	"OV,Sprite Limit,Normal,High;",
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
wire [63:0] status;
wire [11:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_data;
wire  [7:0] ioctl_index;

wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

//wire        forced_scandoubler;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire [15:0] sdram_sz;

//exHPS inputs
//sd_lba is 32-bit a SD-card address part. It is used as BRAM address part in "system" module
wire [31:0] sd_lba;
//ioctl_wait is a HPS bus status signal
wire ioctl_wait;
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
assign gamma_bus[17:8] = '0;
//gamma_bus[7:0] (gamma_value) video_mixer/gamma_corr is data source for gamma_curve or gamma_curve rgb
assign gamma_bus[7:0] = '0;

//exHSP, status is a 64-bit parameter
//status[0] is reset (active HIGH)
//status[3:1] video_mixer, scandoubler: 3'b100 enable CRT 75%, 3'b011 enable CRT 50%, 3'b010 enable CRT 25%. 3'b001 enable hq2x scale. 3'b000 - disable scandoubler
//status[4] system, joystick_1 and joystick_0 swap. 0 - swap disabled. Also set SER_OPT system/gen_io parameter: use SERJOYSTICK on port 1 if status[4]==1'b1, or port 2 if status[4]==1'b0
//status[5] system, J3BUT set a 3 buttons controller mode (active LOW)
//status[7:6] system/multitap/gen_io EXPORT parameter: maybe 2'b00 - Japan, 2'b01 - USA, 2b'10 - Europe. status[7]=1 system, Genesis PAL mode (VDP, multitap)
//status[9:8]=2'b10 auto region disabled (DE2_115_Genesis). Can be IGNORED. 2'b00 region by file extention, 2'b01 region by ROM header. Set status_in[7:6] HSP parameter by region_req[1:0]
//status[10]=1 then VIDEO_ARX x VIDEO_ARY = 16x9
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
//status[31]=1 vdp OBJ_LIMIT_HIGH - enable more sprites and pixels per line. 0 - enable sprite limit like MD
//status[32]=0 ENABLE_FM (active LOW)
//status[33]=0 ENABLE_PSG (active LOW)
//status[36:35] DE2_115_Genesis/system, use_sdr. 2'b00 - use_sdr==|sdram_sz[2:0], where sdram_sz[1:0] is SDRAM size: 0 - none, 1 - 32MB, 2 - 64MB, 3 - 128MB (taken from  hps_io). If status[36:35] non zero - use_sdr==status[35]
//status[39:37] system, MULTITAP type: 3'b001 - 4-way, 3b'010 - controller 2 is controller 2, mode or 3b'011 - controller 2 is controller 5. 3b'100 - J-cart. 3b'000 - multitap disabled
//status[41:40] gun_mode, if 2'b00 in gen_io then GUN disabled. lightgun, MOUSE_XY and JOY_X, JOY_Y, JOY: if 2'b11 then use mouse, 2'b01 use joypad at joystick_0, stick 0; 2'b10 or 2'b00 use joypad at joystick_1, stick 1
//status[42] lightgun, gun_btn_mode. Use mouse buttons if status[42]==1, else use joypad buttons
//status[44:43] video_mixer 2'b00 draw lightgun cross. lightgun - cross size 8'd1 at 0, cross size 8'd3 at 1. cross size 8'd0 at 2 and 3
//status[45]=1 DE2_115_Genesis, MISTer SERJOYSTICK enabled (GPIO)
//status[46]=1 cofi_enable, active HIGH
//status[47]=1 cofi_enable if VDP TRANSP_DETECT is HIGH too
//status[63:48] loopback to HPS_BUS. Ignore {status[63:48], status[34], status[28:27], status[22:21], status[17:16], status[13], status[12], status[9:8]}
//                 63               47                         31                         15                        0
assign status = 64'b0000000000000000_0_0_0_11_0_00_000_00_0_0_0_0_0_0_00_00_1_0_00_000_0_0_01_0_0_0_0_10_00_0_0_001_0;

//exHSP, joystick bitmap (used only 11 bit from 32)
//0      7 8      15       23       31
//RLDUABCS MXYZxxxx xxxxxxxx xxxxxxxx
assign joystick_0 = {KEY[0],KEY[3],KEY[2],KEY[1], SW[17],SW[16],SW[15], SW[14], 4'b0, 20'b00000000000000000000};
assign joystick_1 = '0;
assign joystick_2 = '0;
assign joystick_3 = '0;
assign joystick_4 = '0;

//exHSP, joystick_analog (8 bit) for lightgun - not used
assign joy0_y = '0;
assign joy0_x = '0;
assign joy1_y = '0;
assign joy1_x = '0;

//exHSP signal indicating an active cart/GG download (1 bit). No system reset and hard_reset when it's LOW
assign ioctl_download = SW[3];
//exHPS signal, menu index used to upload the file (8 bit). If it's LOW, then cart_download will be HIGH when ioctl_download is HIGH
assign ioctl_index = '0;
//exHPS bus write status (1 bit). If HIGH then GG loading starts by cart_download. Also a GG module reset depends on it
assign ioctl_wr = '1;
//exHPS bus read/write address: ioctl_addr[3:0] - set gg_code bits when d14 or less (15 not used), !ioctl_addr allow GG_RESET (system module)
//ioctl_addr[24:1] used by sdram module as write address for sdram port0 when ROM uploads to RAM
//ioctl_addr[24:0] was using by system module as ROMSZ (rom size) if old_download == 1 and cart_download == 0 (cart was loaded). Now rom_sz is set manually
assign ioctl_addr = 25'b0000000000000000000001111;
//exHPS bus, ioctl_data (16 bit) is data source for loading cart ROM to SDRAM, GameGenue code and ROM header (region, cart quirks)
//May be zero, but I set it to "J" region for future, when ROM loading will work
assign ioctl_data = "JJ";

//exHPS signals with "sd" prefix was used for passthrough SD-card from HPS to FPGA
//SD-card keep BRAM backup file
//sd_ack enables cart BRAM save to (loading from) SD cart
assign sd_ack = '0;
//sd_buff_addr (8 bit) part of SD-card address bus, not used
assign sd_buff_addr = '0;
//sd_buff_dout (16 bit), the system module, BRAM data input bus. Not used
assign sd_buff_dout = '0;
//sd_buff_wr signal allow system/BRAM_WE if HIGH together with sd_ack
assign sd_buff_wr = '0;

//Also using for BRAM save/load, not used
//img_mounted signaling that new image has been mounted
assign img_mounted = '1;
//img_readonly signaling that image was mounted as read only. Is HIGH if cart hasn't BRAM. Valid only for active bit in img_mounted
assign img_readonly = '1;
//img_size - size of image in bytes (64 bit). Valid only for active bit in img_mounted. If non zero and BRAM enabled, then backup file is reading from SD-card after ROM loading
assign img_size = '0;

//exHPS sdram_sz bus (16 bit, used 3). Enable use SDRAM if non zero. hps_io defines next SDRAM sizes: 0 - none, 1 - 32MB, 2 - 64MB, 3 - 128MB.
assign sdram_sz = 16'b0000000000000010;

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
wire cart_download = ioctl_download & ~code_index;
//GameGenue code loading
wire code_download = ioctl_download & code_index;

reg osd_btn = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;
	reg     has_bootrom = 0;
	reg     last_rst = 0;

	if (RESET) last_rst = 0;
	if (status[0]) last_rst = 1;

	if (cart_download & ioctl_wr & status[0]) has_bootrom <= 1;

	if(last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 24000000) begin
			timeout <= timeout + 1;
			osd_btn <= ~has_bootrom;
		end
	end
end
///////////////////////////////////////////////////
wire clk_sys, clk_ram, locked;

pll pll
(
	.inclk0(CLOCK_50),
	.c0(clk_sys),
	.c1(clk_ram),
	.c2(AUD_XCK),	//Audio codec MCLK 18.1 MHz (MAX 18.51 MHz)
	.c3(dcoun_clk), //DEBUG
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

	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_data; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_data; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_data; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_data; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_data; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_data; // Compare top Word
			12: gg_code[15:0]    <= ioctl_data; // Replace Bottom Word
			14: begin
				gg_code[31:16]   <= ioctl_data; // Replace Top Word
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

wire reset = RESET | status[0] | region_set | bk_loading;

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
	.EEPROM_QUIRK(eeprom_quirk),
	.NORAM_QUIRK(noram_quirk),
	.PIER_QUIRK(pier_quirk),
	.FMBUSY_QUIRK(fmbusy_quirk),

	.TURBO(status[26:25]),

	.BORDER(status[29]),

	.FAST_FIFO(fifo_quirk),
	.SVP_QUIRK(svp_quirk),
	.SCHAN_QUIRK(schan_quirk),

	.GG_RESET(code_download && ioctl_wr && !ioctl_addr),
	.GG_EN(status[24]),
	.GG_CODE(gg_code),

	.J3BUT(~status[5]),
	.JOY_1(status[4] ? joystick_1 : joystick_0),
	.JOY_2(status[4] ? joystick_0 : joystick_1),
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

	.BRAM_A({sd_lba[6:0],sd_buff_addr}),
	.BRAM_DI(sd_buff_dout),
	.BRAM_WE(sd_buff_wr & sd_ack),

	.ROMSZ(rom_sz[24:1]),
//	.ROM_DATA(use_sdr ? sdrom_data : ddrom_data),
//Does Genesis MiSTer work without SDRAM? SDRAM seems to be the sole source of ROM. rom_data2 is used only by the system/SVP module
	.ROM_DATA(sdrom_data),
//	.ROM_ACK(use_sdr ? sdrom_rdack : ddrom_rdack),
	.ROM_ACK(sdrom_rdack),

//MiSTER Genesis DDR RAM signals. DDR uses for SVP ROM.
	.ROM_DATA2(),
	.ROM_ACK2(),

//OUTPUTS
	.DAC_LDATA(audio_ls),
	.DAC_RDATA(audio_rs),

	.RED(r),
	.GREEN(g),
	.BLUE(b),
	.VS(vs),
	.HS(hs),
	.HBL(hblank),
	.VBL(vblank),
	.CE_PIX(ce_pix),
//input for HPS. Not used.
//	.FIELD(VGA_F1),
	.INTERLACE(interlace),
	.RESOLUTION(resolution),

	.GG_AVAILABLE(gg_available),

	.SERJOYSTICK_OUT(SERJOYSTICK_OUT),

//input for HPS. Not used.
//	.BRAM_DO(sd_buff_din),
	.BRAM_CHANGE(bk_change),

	.ROM_ADDR(rom_addr),
	.ROM_WDATA(rom_wdata),
	.ROM_WE(rom_we),
	.ROM_BE(rom_be),
	.ROM_REQ(rom_req),

//MiSTER Genesis DDR RAM signals. DDR uses for SVP ROM.
	.ROM_ADDR2(),
	.ROM_REQ2(),

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
wire CLK_VIDEO = clk_ram;

assign VGA_CLK = CLK_VIDEO; 
//assign VGA_SL = {~interlace,~interlace}&sl[1:0];

reg old_ce_pix;
always @(posedge CLK_VIDEO) old_ce_pix <= ce_pix;

wire [7:0] red, green, blue;

//***********************************Composite-like horizontal blending***********************************
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

wire hs_c,vs_c,hblank_c,vblank_c;

//Disable Blank and sync at VGA out.
assign VGA_BLANK = 1'b1; // (VGA_HS && VGA_VS);
assign VGA_SYNC = 0;

//***********************************gamma, scandoubler, scanlines***********************************
wire VGA_DE, CE_PIXEL;

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	//VGA outputs
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(VGA_DE),

	.gamma_bus(gamma_bus),

	.clk_vid(CLK_VIDEO),
	.ce_pix(~old_ce_pix & ce_pix),
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.scandoubler(~interlace && scale),
	.hq2x(scale==1),

	.mono(0),

	.R((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[0]}} : red),
	.G((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[1]}} : green),
	.B((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[2]}} : blue),

	// Positive pulses.
	.HSync(hs_c),
	.VSync(vs_c),
	.HBlank(hblank_c),
	.VBlank(vblank_c)
);

wire [2:0] lg_target;
wire       lg_sensor;
wire       lg_a;
wire       lg_b;
wire       lg_c;
wire       lg_start;

//***********************************lightgun emulation by mouse or joypad***********************************
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
//debug
wire dcoun_clk;
assign DRAM_CLK = clk_ram;
assign LEDG[8] = locked;
dcounter dramclk_debug
(
	.clk(dcoun_clk),
	.count(LEDR[17:10])
);

sdram sdram
(	.SDRAM_DQ(DRAM_DQ),   // 16 bit bidirectional data bus
	.SDRAM_A(DRAM_ADDR),    // 13 bit multiplexed address bus
	.SDRAM_DQML(DRAM_DQM[0]), // byte mask
	.SDRAM_DQMH(DRAM_DQM[1]), // byte mask
	.SDRAM_BA(DRAM_BA),   // two banks
	.SDRAM_nCS(DRAM_CS_N),  // a single chip select
	.SDRAM_nWE(DRAM_WE_N),  // write enable
	.SDRAM_nRAS(DRAM_RAS_N), // row address select
	.SDRAM_nCAS(DRAM_CAS_N), // columns address select
//	.SDRAM_CLK(DRAM_CLK),
	.SDRAM_CKE(DRAM_CKE),

	.init(~locked),
	.clk(clk_ram),
/*
	.addr0(ioctl_addr[24:1]),
	.din0({ioctl_data[7:0],ioctl_data[15:8]}),
	.dout0(),
	.wrl0(1),
	.wrh0(1),
	.req0(rom_wr),
	.ack0(sdrom_wrack),
*/
	.addr0(0),
	.din0(0),
	.dout0(),
	.wrl0(0),
	.wrh0(0),
	.req0(0),
	.ack0(),

	.addr1(rom_addr),
	.din1(rom_wdata),
	.dout1(sdrom_data),
	.wrl1(rom_we & rom_be[0]),
	.wrh1(rom_we & rom_be[1]),
	.req1(rom_req),
	.ack1(sdrom_rdack),

	.addr2(0),
	.din2(0),
	.dout2(),
	.wrl2(0),
	.wrh2(0),
	.req2(0),
	.ack2()
);

wire [24:1] rom_addr;
wire [15:0] sdrom_data, rom_wdata;
wire  [1:0] rom_be;
wire rom_req, sdrom_rdack, rom_we;

reg use_sdr;
always @(posedge clk_sys) use_sdr <= (!status[36:35]) ? |sdram_sz[2:0] : status[35];

reg  rom_wr = 0;
wire sdrom_wrack;
reg [24:0] rom_sz;
//sytem module, ROM size
assign rom_sz = 24'b000001000000000000000000;

always @(posedge clk_sys) begin
	reg old_download, old_reset;
	old_download <= cart_download;
	old_reset <= reset;

	if(~old_reset && reset) ioctl_wait <= 0;
//Disabled while loading is not work
//	if (old_download & ~cart_download) rom_sz <= ioctl_addr[24:0];

	if (cart_download & ioctl_wr) begin
		ioctl_wait <= 1;
		rom_wr <= ~rom_wr;
	end else if(ioctl_wait && (rom_wr == sdrom_wrack)) begin
		ioctl_wait <= 0;
	end
end

reg  [1:0] region_req;
reg        region_set = 0;

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state, old_ready = 0;
	old_state <= ps2_key[10];

	if(old_state != ps2_key[10]) begin
		casex(code)
			'h005: begin region_req <= 0; region_set <= pressed; end // F1
			'h006: begin region_req <= 1; region_set <= pressed; end // F2
			'h004: begin region_req <= 2; region_set <= pressed; end // F3
		endcase
	end

	old_ready <= cart_hdr_ready;
	if(~status[9] & ~old_ready & cart_hdr_ready) begin
		if(status[8]) begin
			region_set <= 1;
			case(status[28:27])
				0: if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else if(hdr_j) region_req <= 0;
					else region_req <= 1;
				
				1: if(hdr_e) region_req <= 2;
					else if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else region_req <= 2;
				
				2: if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else if(hdr_e) region_req <= 2;
					else region_req <= 1;

				3: if(hdr_j) region_req <= 0;
					else if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else region_req <= 0;
			endcase
		end
		else begin
			region_set <= |ioctl_index;
			region_req <= ioctl_index[7:6];
		end
	end

	if(old_ready & ~cart_hdr_ready) region_set <= 0;
end

reg cart_hdr_ready = 0;
reg hdr_j=0,hdr_u=0,hdr_e=0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= cart_download;

	if(~old_download && cart_download) {hdr_j,hdr_u,hdr_e} <= 0;
	if(old_download && ~cart_download) cart_hdr_ready <= 0;

	if(ioctl_wr & cart_download) begin
		if(ioctl_addr == 'h1F0 || ioctl_addr == 'h1F2) begin
//Really need to compare ioctl_addr == 'h1F0 there^?
			if(ioctl_data[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] >= "0" && ioctl_data[7:0] <= "Z") hdr_e <= 1;
		end
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_data[15:8] == "J") hdr_j <= 1;
			else if(ioctl_data[15:8] == "U") hdr_u <= 1;
			else if(ioctl_data[15:8] >= "0" && ioctl_data[7:0] <= "Z") hdr_e <= 1;
		end
		if(ioctl_addr == 'h200) cart_hdr_ready <= 1;
	end
end

reg sram_quirk = 0;
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

	if(~old_download && cart_download) {fifo_quirk,eeprom_quirk,sram_quirk,noram_quirk,pier_quirk,svp_quirk,fmbusy_quirk,schan_quirk} <= 0;

	if(ioctl_wr & cart_download) begin
		if(ioctl_addr == 'h182) cart_id[63:56] <= ioctl_data[15:8];
		if(ioctl_addr == 'h184) cart_id[55:40] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h186) cart_id[39:24] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h188) cart_id[23:08] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h18A) cart_id[07:00] <= ioctl_data[7:0];
		if(ioctl_addr == 'h18C) begin
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


wire downloading = cart_download;

reg bk_ena = 0;
reg sav_pending = 0;
wire bk_change;

always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_change = 0;

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly && ~svp_quirk) bk_ena <= 1;

	old_change <= bk_change;
	if (~old_change & bk_change) sav_pending <= status[13];
	else if (bk_state) sav_pending <= 0;
end

wire bk_load    = status[16];
wire bk_save    = status[17] | sav_pending;
reg  bk_loading = 0;
reg  bk_state   = 0;

always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_load = 0, old_save = 0, old_ack;

	old_downloading <= downloading;

	old_load <= bk_load;
	old_save <= bk_save;
	old_ack  <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if(!bk_state) begin
		if(bk_ena & ((~old_load & bk_load) | (~old_save & bk_save))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
			sd_lba <= 0;
			sd_rd <=  bk_load;
			sd_wr <= ~bk_load;
		end
		if(old_downloading & ~downloading & |img_size & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_lba <= 0;
			sd_rd <= 1;
			sd_wr <= 0;
		end
	end else begin
		if(old_ack & ~sd_ack) begin
			if(&sd_lba[6:0]) begin
				bk_loading <= 0;
				bk_state <= 0;
			end else begin
				sd_lba <= sd_lba + 1'd1;
				sd_rd  <=  bk_loading;
				sd_wr  <= ~bk_loading;
			end
		end
	end
end

////////////////  MiSTER SERJOYSTICK /////////////////////////
assign GPIO = user_io;

// 0 - D+/RX
// 1 - D-/TX
// 2..6 - USR2..USR6
// Set user_out to 1 to read from user_in.
wire [6:0] user_out, user_in, user_io;

assign user_io[0] = !user_out[0] ? 1'b0 : 1'bZ;
assign user_io[1] = !user_out[1] ? 1'b0 : 1'bZ;
assign user_io[2] = !user_out[2] ? 1'b0 : 1'bZ;
assign user_io[3] = !user_out[3] ? 1'b0 : 1'bZ;
assign user_io[4] = !user_out[4] ? 1'b0 : 1'bZ;
assign user_io[5] = !user_out[5] ? 1'b0 : 1'bZ;
assign user_io[6] = !user_out[6] ? 1'b0 : 1'bZ;

assign user_in[0] = user_io[0];
assign user_in[1] = user_io[1];
assign user_in[2] = user_io[2];
assign user_in[3] = user_io[3];
assign user_in[4] = user_io[4];
assign user_in[5] = user_io[5];
assign user_in[6] = user_io[6];

wire [7:0] SERJOYSTICK_IN;
wire [7:0] SERJOYSTICK_OUT;
wire [1:0] SER_OPT;

always @(posedge clk_sys) begin
	if (status[45]) begin
		SERJOYSTICK_IN[0] <= user_in[1];//up
		SERJOYSTICK_IN[1] <= user_in[0];//down
		SERJOYSTICK_IN[2] <= user_in[5];//left
		SERJOYSTICK_IN[3] <= user_in[3];//right
		SERJOYSTICK_IN[4] <= user_in[2];//b TL
		SERJOYSTICK_IN[5] <= user_in[6];//c TR GPIO7
		SERJOYSTICK_IN[6] <= user_in[4];//  TH
		SERJOYSTICK_IN[7] <= 0;
		SER_OPT[0] <= status[4];
		SER_OPT[1] <= ~status[4];
		user_out[1] <= SERJOYSTICK_OUT[0];
		user_out[0] <= SERJOYSTICK_OUT[1];
		user_out[5] <= SERJOYSTICK_OUT[2];
		user_out[3] <= SERJOYSTICK_OUT[3];
		user_out[2] <= SERJOYSTICK_OUT[4];
		user_out[6] <= SERJOYSTICK_OUT[5];
		user_out[4] <= SERJOYSTICK_OUT[6];
	end else begin
		SER_OPT  <= 0;
		user_out <= '1;
	end
end

//********************************Audio**************************************
// Codec DE2-115 configuration by I2C
I2C_AV_Config  i2c_con
(
//      Host Side
.iCLK(clk_sys),
.iRST_N(reset),
//      I2C Side
.oI2C_SCLK(I2C_SCLK),
.oI2C_SDAT(I2C_SDAT)
);

// Digital audio mixing
wire        clk_audio = clk_sys;
wire [4:0]  vol_att = 0; //if (cmd == 'h26) vol_att <= io_din[4:0]. Genesis MiSTER sys_top.v(399).
wire [1:0]  audio_mix = 0; // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
wire        audio_s = 1;
wire [15:0] audio_ls, audio_rs;
wire [15:0] alsa_l = 0, alsa_r = 0;

wire [15:0] audio_l, audio_l_pre;
aud_mix_top audmix_l
(
	.clk(clk_audio),
	.att(vol_att),
	.mix(audio_mix),
	.is_signed(audio_s),

	.core_audio(audio_ls),
	.pre_in(audio_r_pre),
	.linux_audio(alsa_l),

	.pre_out(audio_l_pre),
	.out(audio_l)
);

wire [15:0] audio_r, audio_r_pre;
aud_mix_top audmix_r
(
	.clk(clk_audio),
	.att(vol_att),
	.mix(audio_mix),
	.is_signed(audio_s),

	.core_audio(audio_rs),
	.pre_in(audio_l_pre),
	.linux_audio(alsa_r),

	.pre_out(audio_r_pre),
	.out(audio_r)
);

wire spdif;
audio_out audio_out
(
	.reset(reset),
	.clk(clk_audio),
	.sample_rate(0), //0 - 48KHz, 1 - 96KHz
	.left_in(audio_l),
	.right_in(audio_r),
	.i2s_bclk(AUD_BCLK),
	.i2s_lrclk(AUD_DACLRCK),
	.i2s_data(AUD_DACDAT)
);
endmodule

//***********************************digital audio mixer module***********************************
module aud_mix_top
(
	input             clk,

	input       [4:0] att,
	input       [1:0] mix,
	input             is_signed,

	input      [15:0] core_audio,
	input      [15:0] linux_audio,
	input      [15:0] pre_in,

	output reg [15:0] pre_out,
	output reg [15:0] out
);

reg [15:0] ca;
always @(posedge clk) begin
	reg [15:0] d1,d2,d3;

	d1 <= core_audio; d2<=d1; d3<=d2;
	if(d2 == d3) ca <= d2;
end

always @(posedge clk) begin
	reg signed [16:0] a1, a2, a3, a4;

	a1 <= is_signed ? {ca[15],ca} : {2'b00,ca[15:1]};
	a2 <= a1 + {linux_audio[15],linux_audio};

	pre_out <= a2[16:1];

	case(mix)
		0: a3 <= a2;
		1: a3 <= $signed(a2) - $signed(a2[16:3]) + $signed(pre_in[15:2]);
		2: a3 <= $signed(a2) - $signed(a2[16:2]) + $signed(pre_in[15:1]);
		3: a3 <= {a2[16],a2[16:1]} + {pre_in[15],pre_in};
	endcase

	if(att[4]) a4 <= 0;
	else a4 <= a3 >>> att[3:0];

	//clamping
	out <= ^a4[16:15] ? {a4[16],{15{a4[15]}}} : a4[15:0];
end

endmodule


//***********************************DEBUG modules***********************************
module dcounter (
	input wire       clk,
	output reg [7:0] count
);
wire [31:0] counter;

assign count = counter[31:24];
	always @(posedge clk)
		begin
			if (&counter)
				counter = 0;
			else
				counter = counter + 1;
		end
endmodule