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

	input				GENPADS_ENABLE,

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

	// Open-drain User ports.
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN_1,
	output  [6:0] USER_OUT_1,
	input   [6:0] USER_IN_2,
	output  [6:0] USER_OUT_2,

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

//exHPS OUTPUTS
reg  [63:0] status;
wire [31:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_data;
wire  [7:0] ioctl_index;

wire        forced_scandoubler;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

//exHPS bidirectional signals
wire [21:0] gamma_bus;

//exHPS inputs
//ioctl_wait is a HPS bus ROM word write status
reg         ioctl_wait;
//sd_rd and sd_wr VDNUM-1 bit signal (VD is Virtual Drive count). It is used for a SD-card selection for read or write
//for Genesis core VDNUM == 1
wire			sd_rd;
wire			sd_wr;

//exHPS outputs
assign joystick_0 = JOY_0;
assign joystick_1 = JOY_1;
assign joystick_2 = JOY_2;
assign joystick_3 = JOY_3;
assign joystick_4 = JOY_4;

ex_hps_io #(.WIDE(1)) ex_hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS({GENPADS_ENABLE,FL_DQ,FL_ADDR,FL_RST_N,FL_CE_N,FL_OE_N,FL_WE_N,FL_WP_N}),

	.joystick_analog_0({joy0_y, joy0_x}),
	.joystick_analog_1({joy1_y, joy1_x}),

	.forced_scandoubler(forced_scandoubler),

	.status(status),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.gamma_bus(gamma_bus),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse)
);

wire [1:0] gun_mode = status[41:40];
wire       gun_btn_mode = status[42];

wire code_index = &ioctl_index;
wire cart_download = ioctl_download & ~code_index;
//GameGenue code loading
wire code_download = ioctl_download & code_index;

///////////////////////////////////////////////////
wire clk_sys, clk_ram, locked;

pll pll
(
	.inclk0(CLK_50M),
	.c0(clk_sys),
	.c1(clk_ram),
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

	.GG_RESET(code_download && ioctl_wr && !ioctl_addr),
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

	.SERJOYSTICK_IN_1(SERJOYSTICK_IN_1),
	.SERJOYSTICK_IN_2(SERJOYSTICK_IN_2),
	.SER_OPT(SER_OPT),

	.ENABLE_FM(~dbg_menu | ~status[32]),
	.ENABLE_PSG(~dbg_menu | ~status[33]),
	.EN_HIFI_PCM(status[23]),
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
//input for HPS. sys_top/vga_hs_osd. Not used.
	.FIELD(VGA_F1),
	.INTERLACE(interlace),
	.RESOLUTION(resolution),

	.GG_AVAILABLE(gg_available),

	.SERJOYSTICK_OUT_1(SERJOYSTICK_OUT_1),
	.SERJOYSTICK_OUT_2(SERJOYSTICK_OUT_2),

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
	
	.scandoubler(~interlace && (scale || forced_scandoubler)),
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

	.addr0(ioctl_addr[24:1]),
	.din0({ioctl_data[7:0],ioctl_data[15:8]}),
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
reg  rom_wr = 0;
wire sdrom_wrack;
reg [24:0] rom_sz;
always @(posedge clk_sys) begin
	reg old_download, old_reset;
	old_download <= cart_download;
	old_reset <= reset;

	if(~old_reset && reset) ioctl_wait <= 0;
	if (old_download & ~cart_download) rom_sz <= ioctl_addr[24:0];

	if (cart_download & ioctl_wr) begin
		ioctl_wait <= 1;
		rom_wr <= ~rom_wr;
	end else if(ioctl_wait && (rom_wr == sdrom_wrack)) begin
		ioctl_wait <= 0;
	end
end

wire [3:0] hrgn = ioctl_data[3:0] - 4'd7;

reg cart_hdr_ready = 0;
reg hdr_j=0,hdr_u=0,hdr_e=0;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= cart_download;

	if(~old_download && cart_download) {hdr_j,hdr_u,hdr_e} <= 0;
	if(old_download && ~cart_download) cart_hdr_ready <= 0;

	if(ioctl_wr & cart_download) begin
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_addr[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] == "E") hdr_e <= 1;
			else if(ioctl_data[7:0] >= "0" && ioctl_data[7:0] <= "9") {hdr_e, hdr_u, hdr_j} <= {ioctl_data[3], ioctl_data[2], ioctl_data[0]};
			else if(ioctl_data[7:0] >= "A" && ioctl_data[7:0] <= "F") {hdr_e, hdr_u, hdr_j} <= {      hrgn[3],       hrgn[2],       hrgn[0]};
		end		
		if(ioctl_addr == 'h1F2) begin
			if(ioctl_data[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_data[15:8] == "J") hdr_j <= 1;
			else if(ioctl_data[15:8] == "U") hdr_u <= 1;
			else if(ioctl_data[15:8] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h200) cart_hdr_ready <= 1;
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
wire [7:0] SERJOYSTICK_IN_1,SERJOYSTICK_IN_2;
wire [7:0] SERJOYSTICK_OUT_1,SERJOYSTICK_OUT_2;
wire [1:0] SER_OPT;

always @(posedge clk_sys) begin
	if (status[45]) begin
		// port 1
		SERJOYSTICK_IN_1[0] <= USER_IN_1[1];//up
		SERJOYSTICK_IN_1[1] <= USER_IN_1[0];//down
		SERJOYSTICK_IN_1[2] <= USER_IN_1[5];//left
		SERJOYSTICK_IN_1[3] <= USER_IN_1[3];//right
		SERJOYSTICK_IN_1[4] <= USER_IN_1[2];//b TL
		SERJOYSTICK_IN_1[5] <= USER_IN_1[6];//c TR GPIO7
		SERJOYSTICK_IN_1[6] <= USER_IN_1[4];//  TH
		SERJOYSTICK_IN_1[7] <= 0;
		USER_OUT_1[1] <= SERJOYSTICK_OUT_1[0];
		USER_OUT_1[0] <= SERJOYSTICK_OUT_1[1];
		USER_OUT_1[5] <= SERJOYSTICK_OUT_1[2];
		USER_OUT_1[3] <= SERJOYSTICK_OUT_1[3];
		USER_OUT_1[2] <= SERJOYSTICK_OUT_1[4];
		USER_OUT_1[6] <= SERJOYSTICK_OUT_1[5];
		USER_OUT_1[4] <= SERJOYSTICK_OUT_1[6];

		// port 2
		SERJOYSTICK_IN_2[0] <= USER_IN_2[1];//up
		SERJOYSTICK_IN_2[1] <= USER_IN_2[0];//down
		SERJOYSTICK_IN_2[2] <= USER_IN_2[5];//left
		SERJOYSTICK_IN_2[3] <= USER_IN_2[3];//right
		SERJOYSTICK_IN_2[4] <= USER_IN_2[2];//b TL
		SERJOYSTICK_IN_2[5] <= USER_IN_2[6];//c TR GPIO7
		SERJOYSTICK_IN_2[6] <= USER_IN_2[4];//  TH
		SERJOYSTICK_IN_2[7] <= 0;
		USER_OUT_2[1] <= SERJOYSTICK_OUT_2[0];
		USER_OUT_2[0] <= SERJOYSTICK_OUT_2[1];
		USER_OUT_2[5] <= SERJOYSTICK_OUT_2[2];
		USER_OUT_2[3] <= SERJOYSTICK_OUT_2[3];
		USER_OUT_2[2] <= SERJOYSTICK_OUT_2[4];
		USER_OUT_2[6] <= SERJOYSTICK_OUT_2[5];
		USER_OUT_2[4] <= SERJOYSTICK_OUT_2[6];

		// ports swap
		SER_OPT[0] <= ~status[4];
		SER_OPT[1] <= status[4];
	end else begin
		// port 1
		USER_OUT_1 <= '1;
		// port 2
		USER_OUT_2 <= '1;
		// ports swap
		SER_OPT <= '0;
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
