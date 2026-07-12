//============================================================================
//
//  DE2-115 port MiSTer hardware abstraction module
//  (c)2017-2020 Alexey Melnikov
//  (c)2020-2021 Alexander Kirichenko
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 3 of the License, or (at your option)
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
//
//============================================================================

module sys_top
(
	/////////// CLOCK //////////
	input         CLOCK_50,
	input         CLOCK2_50,

	// switch inputs
	// SW[17] - PAL on/off
	// SW[16] - RESET
	// SW[15] - enable/disable MiSTer serial ports
	// SW[5] - joystick_0_B, SW[4] - joystick_0_C, SW[3] - joystick_0_Left, SW[2] - joystick_0_Up, SW[1] - joystick_0_Down, SW[0] - joystick_0_Right
	// SW[12] - joystick_1_B, SW[11] - joystick_1_C, SW[10] - joystick_1_Left, SW[9] - joystick_1_Up, SW[8] - joystick_1_Down, SW[7] - joystick_1_Right
	input  [17:0] SW, // Toggle Switches[17:0]

	// button inputs
	// KEY[3] - joystick_0_START, KEY[2] - joystick_0_A, KEY[1] - joystick_1_START, KEY[0] - joystick_1_A
	input   [3:0] KEY,
	
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_CLK,
	output        VGA_BLANK_N,
	output        VGA_SYNC_N,
	
	/////////// AUDIO //////////
	output		  AUDIO_L, // exHSMC_TX_D_P16, analog connection through RC-filter. See MiSTer IO Board schematic (https://github.com/MiSTer-devel/Hardware_MiSTer/blob/master/releases/iobrd_5.5.pdf)
	output		  AUDIO_R, // exHSMC_TX_D_N16, analog connection through RC-filter

	//////////// SDCARD //////////
	output		  SD_CLK,
	inout		  SD_CMD,
	inout	[3:0] SD_DAT,
	//input		  SD_WP_N, Does not connected, no SD card support now

	output  [0:0] LEDR, // LEDR[0] = led_user
	output  [1:0] LEDG,

	// I2C for Audio codec configuration
	output        I2C_SCLK,
	inout         I2C_SDAT,
	// I2S for Audio codec bit stream
	output        AUD_BCLK,
	output        AUD_DACDAT,
	output        AUD_DACLRCK,
	output        AUD_XCK,

	// SDRAM interface
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

	///////// USER IO, SPDIF ///////////
	inout [35:0] GPIO, // [13], [11], [9], [5], [3], [1], [7]      - MiSTer serial 1 {Up/Z, Down/Y, Left/X, Right/Mode, B/A (TL), C/Start (TR), Select (TH)}
					   // [23], [25], [27], [31], [33], [35], [29] - MiSTer serial 2 {Up/Z, Down/Y, Left/X, Right/Mode, B/A (TL), C/Start (TR), Select (TH)}
					   // [34] - spdif audio out

	// FLASH interface
	output		  FL_RST_N,
	output		  FL_CE_N,
	output		  FL_OE_N,
	output		  FL_WE_N,
	output		  FL_WP_N,
	output [22:0] FL_ADDR,
	input  [7:0]  FL_DQ
);

//////////////////////  SD card  ////////////////////////////////////////
wire SD_CS, SD_MOSI, SD_MISO;

assign SD_MISO = SD_DAT[0];

assign SD_DAT[2:1] = 2'bZZ;
assign SD_DAT[3]   = SD_CS;
assign SD_CMD      = SD_MOSI;

//////////////////////  LEDs/Buttons  ///////////////////////////////////

assign LEDG[1] = led_power[1] ? led_power[0] : 1'b0;
assign LEDG[0] = led_disk[1]  ?  led_disk[0] : 1'b0;
assign LEDR[0] = led_user;

wire [31:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;

//exHSP, joystick bitmap (used only 11 bit from 32)
//0      7 8      15       23       31
//xxxxxxxx xxxxxxxx xxxxZYXM SCBAUDLR
assign joystick_0 = {24'b000000000000000000000000, ~KEY[3],SW[4],SW[5],~KEY[2],SW[2],SW[1],SW[3],SW[0]};
assign joystick_1 = {24'b000000000000000000000000, ~KEY[1],SW[11],SW[12],~KEY[0],SW[9],SW[8],SW[10],SW[7]};
assign joystick_2 = 32'd0;
assign joystick_3 = 32'd0;
assign joystick_4 = 32'd0;

//////////////////////  RESET  ///////////////////////////////////

// Initial
reg init_reset_n = 0;
always @(posedge CLOCK_50) begin
	integer timeout = 0;

	if(timeout < 2000000) begin
		init_reset_n <= 0;
		timeout <= timeout + 1;
	end
	else init_reset_n <= 1;
end

// By button
reg reset_button_syn = 0;
reg resetb;
always @(posedge CLOCK_50) begin
	resetb  <= SW[16];
	reset_button_syn <= resetb;
end

wire reset;
assign reset = ~init_reset_n | reset_button_syn;

/////////////////////////  VGA output  //////////////////////////////////

wire        csync_en = 1'b0; // HPS cfg register, MiSTer/sys/sys_top.v:281

wire [23:0] vga_data_sl;
wire        vga_vs_sl, vga_hs_sl;
scanlines #(0) VGA_scanlines
(
	.clk(clk_vid),

	.scanlines(scanlines),
	.din(de_emu ? {r_out, g_out, b_out} : 24'd0),
	.hs_in(hs_fix),
	.vs_in(vs_fix),
	.de_in(de_emu),
	.ce_in(ce_pix),

	.dout(vga_data_sl),
	.hs_out(vga_hs_sl),
	.vs_out(vga_vs_sl),
	.de_out(),
	.ce_out()
);

wire vga_cs_osd; // OSD (On-Screen Display) isn't implemented in DE2_115_Genesis
				 // osd name is saved for MiSTer source compatibility
csync csync_vga(
	.clk(clk_vid),

	.hsync(vga_hs_sl),
	.vsync(vga_vs_sl),

	.csync(vga_cs_osd)
);

wire VGA_DISABLE;

wire [23:0] vga_o, vga_o_t;
wire vga_hs, vga_vs, vga_cs, vga_hs_t, vga_vs_t, vga_cs_t;
vga_out vga_out
(
	.clk(clk_vid),
	.ypbpr_en(1'b0),
	.hsync(vga_hs_sl),
	.vsync(vga_vs_sl),
	.csync(vga_cs_osd),
	.dout(vga_o_t),
	.din(vga_data_sl),
	.hsync_o(vga_hs_t),
	.vsync_o(vga_vs_t),
	.csync_o(vga_cs_t)
);

`ifndef MISTER_DISABLE_YC
	reg         pal_en;
	reg         yc_en;
	reg         cvbs;
	reg  [16:0] ColorBurst_Range;
	reg  [39:0] PhaseInc;
	wire [23:0] yc_o;
	wire        yc_hs, yc_vs, yc_cs;

	// HPS command interface
	// no HPS, no data for CVBS options
	always @(posedge clk_vid) begin
		pal_en <= 1'b0;
		yc_en  <= 1'b0;
		cvbs   <= 1'b0;
		ColorBurst_Range <= 17'b0;
		PhaseInc         <= 40'b0;
	end

	yc_out yc_out
	(
		.clk(clk_vid),
		.PAL_EN(pal_en),
		.CVBS(cvbs),
		.PHASE_INC(PhaseInc),
		.COLORBURST_RANGE(ColorBurst_Range),
		.hsync(vga_hs_sl),
		.vsync(vga_vs_sl),
		.csync(vga_cs_osd),
		.dout(yc_o),
		.din(vga_data_sl),
		.hsync_o(yc_hs),
		.vsync_o(yc_vs),
		.csync_o(yc_cs)
	);

	assign {vga_o, vga_hs, vga_vs, vga_cs } = ~yc_en ? {vga_o_t, vga_hs_t, vga_vs_t, vga_cs_t } : {yc_o, yc_hs, yc_vs, yc_cs };
`else
	assign {vga_o, vga_hs, vga_vs, vga_cs } =  {vga_o_t, vga_hs_t, vga_vs_t, vga_cs_t } ;
`endif

// No VGA_EN MUX because VGA DAC is soldered to DE2-115
assign VGA_VS = (VGA_DISABLE ? 1'd1 : ~vga_vs) | csync_en;
assign VGA_HS = VGA_DISABLE ? 1'd1 : (csync_en ? ~vga_cs : ~vga_hs);
assign VGA_R  = VGA_DISABLE ? 6'd0 : vga_o[23:16];
assign VGA_G  = VGA_DISABLE ? 6'd0 : vga_o[15:8] ;
assign VGA_B  = VGA_DISABLE ? 6'd0 : vga_o[7:0]  ;

// Disable Blank and sync at VGA out.
assign VGA_BLANK_N = 1'b1; // (VGA_HS && VGA_VS);
assign VGA_SYNC_N = 0;

assign VGA_CLK = clk_vid;

/////////////////////////  Audio output  ////////////////////////////////

// Codec DE2-115 configuring by I2C
I2C_AV_Config  i2c_con
(
//      Host Side
.iCLK(CLOCK2_50),
.iRST_N(~reset),
//      I2C Side
.oI2C_SCLK(I2C_SCLK),
.oI2C_SDAT(I2C_SDAT)
);

wire analog_l, analog_r;

assign GPIO[34] = spdif;
assign AUDIO_R  = analog_r;
assign AUDIO_L  = analog_l;

wire clk_audio;

pll_sys pll_sys
(
	.inclk0(CLOCK2_50),
	.c0(AUD_XCK),            // Audio codec MCLK 12.288 MHz (MAX 18.51 MHz)
	.c1(clk_audio)
);

wire       audio_96k = 1'b0; //0 - 48KHz, 1 - 96KHz

reg [31:0] aflt_rate = 7056000;
reg [39:0] acx  = 4258969;
reg  [7:0] acx0 = 3;
reg  [7:0] acx1 = 3;
reg  [7:0] acx2 = 1;
reg [23:0] acy0 = -24'd6216759;
reg [23:0] acy1 =  24'd6143386;
reg [23:0] acy2 = -24'd2023767;
reg        areset = 0;
reg [12:0] arc1x = 0;
reg [12:0] arc1y = 0;
reg [12:0] arc2x = 0;
reg [12:0] arc2y = 0;

wire [4:0]  vol_att = 0; //if (cmd == 'h26) vol_att <= io_din[4:0]. Genesis MiSTer sys_top.v(399).
wire [15:0] alsa_l = 0, alsa_r = 0;

wire spdif;
audio_out audio_out
(
	.reset(reset),
	.clk(clk_audio),

	.att(vol_att),
	.mix(audio_mix),
	.sample_rate(audio_96k),

	.flt_rate(aflt_rate),
	.cx(acx),
	.cx0(acx0),
	.cx1(acx1),
	.cx2(acx2),
	.cy0(acy0),
	.cy1(acy1),
	.cy2(acy2),

	.is_signed(audio_s),
	.core_l(audio_l),
	.core_r(audio_r),

	.alsa_l(alsa_l),
	.alsa_r(alsa_r),

	.i2s_bclk(AUD_BCLK),
	.i2s_lrclk(AUD_DACLRCK),
	.i2s_data(AUD_DACDAT),

	.dac_l(analog_l),
	.dac_r(analog_r),

	.spdif(spdif)
);

////////////////  User I/O  /////////////////////////
// synchronizer: enable/disable MiSTer SERJOYSTICKs
reg gpads_enable_syn = 1'b0;
reg gpads_enable_b;
always @(posedge CLOCK_50) begin
	gpads_enable_b  <= SW[15];
	gpads_enable_syn <= gpads_enable_b;
end
wire gpads_enable = gpads_enable_syn;

// Open-drain User port 1 (MiSTer SERJOYSTICK).
// [13], [11], [9], [5], [3], [1], [7] - {Up/Z, Down/Y, Left/X, Right/Mode, B/A (TL), C/Start (TR), Select (TH)}
assign GPIO[13] = !user_out_1[1] ? 1'b0 : 1'bZ;
assign GPIO[11] = !user_out_1[0] ? 1'b0 : 1'bZ;
assign GPIO[9]  = !user_out_1[5] ? 1'b0 : 1'bZ;
assign GPIO[5]  = !user_out_1[3] ? 1'b0 : 1'bZ;
assign GPIO[3]  = !user_out_1[2] ? 1'b0 : 1'bZ;
assign GPIO[1]  = !user_out_1[6] ? 1'b0 : 1'bZ;
assign GPIO[7]  = !user_out_1[4] ? 1'b0 : 1'bZ;

assign user_in_1[1] = GPIO[13];
assign user_in_1[0] = GPIO[11];
assign user_in_1[5] = GPIO[9];
assign user_in_1[3] = GPIO[5];
assign user_in_1[2] = GPIO[3];
assign user_in_1[6] = GPIO[1];
assign user_in_1[4] = GPIO[7];

// Open-drain User port 2 (MiSTer SERJOYSTICK).
// [23], [25], [27], [31], [33], [35], [29] - {Up/Z, Down/Y, Left/X, Right/Mode, B/A (TL), C/Start (TR), Select (TH)}
assign GPIO[23] = !user_out_2[1] ? 1'b0 : 1'bZ;
assign GPIO[25] = !user_out_2[0] ? 1'b0 : 1'bZ;
assign GPIO[27] = !user_out_2[5] ? 1'b0 : 1'bZ;
assign GPIO[31] = !user_out_2[3] ? 1'b0 : 1'bZ;
assign GPIO[33] = !user_out_2[2] ? 1'b0 : 1'bZ;
assign GPIO[35] = !user_out_2[6] ? 1'b0 : 1'bZ;
assign GPIO[29] = !user_out_2[4] ? 1'b0 : 1'bZ;

assign user_in_2[1] = GPIO[23];
assign user_in_2[0] = GPIO[25];
assign user_in_2[5] = GPIO[27];
assign user_in_2[3] = GPIO[31];
assign user_in_2[2] = GPIO[33];
assign user_in_2[6] = GPIO[35];
assign user_in_2[4] = GPIO[29];

///////////////////  User module connection ////////////////////////////
wire [15:0] audio_l, audio_r;
wire        audio_s;
wire  [1:0] audio_mix; // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
wire  [1:0] scanlines;
wire  [7:0] r_out, g_out, b_out;
wire        vs_fix, hs_fix, hs_emu, vs_emu, de_emu;
wire        clk_vid, ce_pix;

wire        led_user;
wire  [1:0] led_power;
wire  [1:0] led_disk;

sync_fix sync_v(clk_vid, vs_emu, vs_fix);
sync_fix sync_h(clk_vid, hs_emu, hs_fix);

wire  [6:0] user_out_1, user_in_1, user_out_2, user_in_2;

emu emu
(
	.CLK_50M(CLOCK_50),
	.RESET(reset),
	
	// DE2-115 extra: connected to SW, because no HPS
	.JOY_0(joystick_0),  // using SW as gamepad 1
	.JOY_1(joystick_1),  // using SW as gamepad 2
	.JOY_2(joystick_2),  // not used
	.JOY_3(joystick_3),  // not used
	.JOY_4(joystick_4),  // not used
	.GENPADS_ENABLE(gpads_enable), // if LOW: enable JOY_0 and JOY_1, disable USER I/O;
	.PAL_ENABLE(SW[17]), // if HIGH: switch on VDP PAL mode and system Europe region

	.VGA_R(r_out),
	.VGA_G(g_out),
	.VGA_B(b_out),
	.VGA_HS(hs_emu),
	.VGA_VS(vs_emu),
	.VGA_DE(de_emu),    // = ~(VBlank | HBlank)
	.VGA_F1(),          // not used, because no HPS
	.VGA_SCALER(),      // VGA sginal selector: scaled or not (used with some MiSTer hdmi modules)

	.VGA_DISABLE(VGA_DISABLE),

	.HDMI_WIDTH(12'd0),  // No HDMI
	.HDMI_HEIGHT(12'd0), // No HDMI
	.HDMI_FREEZE(),      // Video scaler ouput control, not used because no HDMI

	.CLK_VIDEO(clk_vid),
	.CE_PIXEL(ce_pix),
	.VGA_SL(scanlines),
	.VIDEO_ARX(),        // Video aspect ratio for HDMI (not used)
	.VIDEO_ARY(),        // Video aspect ratio for HDMI (not used)

	.LED_USER(led_user),
	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	.LED_POWER(led_power),
	.LED_DISK(led_disk),

	.CLK_AUDIO(clk_audio),
	.AUDIO_L(audio_l),
	.AUDIO_R(audio_r),
	.AUDIO_S(audio_s),
	.AUDIO_MIX(audio_mix),

	.ADC_BUS(), // MiSTer ADCin board for a tape loading (not used for Genesis)

	//SDRAM interface with lower latency
	.SDRAM_CLK(DRAM_CLK),
	.SDRAM_CKE(DRAM_CKE),
	.SDRAM_A(DRAM_ADDR),
	.SDRAM_BA(DRAM_BA),
	.SDRAM_DQ(DRAM_DQ),
	.SDRAM_DQML(DRAM_DQM[0]),
	.SDRAM_DQMH(DRAM_DQM[1]),
	.SDRAM_nCS(DRAM_CS_N),
	.SDRAM_nCAS(DRAM_CAS_N),
	.SDRAM_nRAS(DRAM_RAS_N),
	.SDRAM_nWE(DRAM_WE_N),

	.SD_SCK(SD_CLK),
	.SD_MOSI(SD_MOSI),
	.SD_MISO(SD_MISO),
	.SD_CS(SD_CS),
	.SD_CD(), // a sdmicro slot CARD DETECT, here isn't the detect signal on a SD slot of DE2-115

	// no UART for Genesis
	.UART_CTS(),
	.UART_RTS(),
	.UART_RXD(),
	.UART_TXD(),
	.UART_DTR(),
	.UART_DSR(),

	.USER_OUT_1(user_out_1),
	.USER_IN_1(user_in_1),
	.USER_OUT_2(user_out_2),
	.USER_IN_2(user_in_2),

	// FLASH controller interface
	.FL_DQ(FL_DQ),
	.FL_ADDR(FL_ADDR),	
	.FL_RST_N(FL_RST_N),
	.FL_CE_N(FL_CE_N),
	.FL_OE_N(FL_OE_N),
	.FL_WE_N(FL_WE_N),
	.FL_WP_N(FL_WP_N)
);

endmodule

//***********************************video h/v sync fix module***********************************

module sync_fix
(
	input clk,
	
	input sync_in,
	output sync_out
);

assign sync_out = sync_in ^ pol;

reg pol;
always @(posedge clk) begin
	integer pos = 0, neg = 0, cnt = 0;
	reg s1,s2;

	s1 <= sync_in;
	s2 <= s1;

	if(~s2 & s1) neg <= cnt;
	if(s2 & ~s1) pos <= cnt;

	cnt <= cnt + 1;
	if(s2 != s1) cnt <= 0;

	pol <= pos > neg;
end

endmodule

/////////////////////////////////////////////////////////////////////

// CSync generation
// Shifts HSync left by 1 HSync period during VSync

module csync
(
	input  clk,
	input  hsync,
	input  vsync,

	output csync
);

assign csync = (csync_vs ^ csync_hs);

reg csync_hs, csync_vs;
always @(posedge clk) begin
	reg prev_hs;
	reg [15:0] h_cnt, line_len, hs_len;

	// Count line/Hsync length
	h_cnt <= h_cnt + 1'd1;

	prev_hs <= hsync;
	if (prev_hs ^ hsync) begin
		h_cnt <= 0;
		if (hsync) begin
			line_len <= h_cnt - hs_len;
			csync_hs <= 0;
		end
		else hs_len <= h_cnt;
	end
	
	if (~vsync) csync_hs <= hsync;
	else if(h_cnt == line_len) csync_hs <= 1;
	
	csync_vs <= vsync;
end

endmodule
