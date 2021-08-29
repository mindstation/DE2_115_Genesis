module sys_top
(
	/////////// CLOCK //////////
	input         CLOCK_50,
	input         CLOCK2_50,

	// switch inputs
	// SW[0] - RESET
	// SW[16] - joystick_0_A, SW[15] - joystick_0_B, SW[14] - joystick_0_C, SW[13] - joystick_0_START, SW[12] - joystick_0_Left
   input  [17:0] SW, // Toggle Switch[17:0]

	// button inputs
	// KEY[0]  - joystick_0_Right, KEY[3] - RESET (01052021), KEY[2] - joystick_0_Up, KEY[1] - joystick_0_Down
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
	output		  AUDIO_L, //exGPIO[1], analog connection through RC-filter. See MiSTER IO Board schematic (https://github.com/MiSTer-devel/Hardware_MiSTer/blob/master/releases/iobrd_5.5.pdf)
	output		  AUDIO_R, //exGPIO[3], analog connection through RC-filter
	
	output  [1:0] LEDR, //LEDR[0] = led_user
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

	///////// USER IO ///////////
	inout [35:29] GPIO,
	
	// FLASH interface
	output		  FL_RST_N,
	output		  FL_CE_N,
	output		  FL_OE_N,
	output		  FL_WE_N,
	output		  FL_WP_N,
	output [22:0] FL_ADDR,
	input  [7:0]  FL_DQ
);

pll_sys pll_sys
(
	.inclk0(CLOCK2_50),
	.c0(AUD_XCK), //Audio codec MCLK 18.0 MHz (MAX 18.51 MHz)
);

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
	resetb  <= ~KEY[3] | SW[0];
	reset_button_syn <= resetb;
end

wire reset;
assign reset = ~init_reset_n | reset_button_syn;

//////////////////////  LEDs/Buttons  ///////////////////////////////////

assign LEDG[1] = led_power[1] ? led_power[0] : 1'b0;
assign LEDG[0] = led_disk[1] ? ~led_disk[0] : 1'b0;
assign LEDR[0] = led_user;

wire [31:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;

//exHSP, joystick bitmap (used only 11 bit from 32)
//0      7 8      15       23       31
//xxxxxxxx xxxxxxxx xxxxZYXM SCBAUDLR
assign joystick_0 = {20'b00000000000000000000, 4'b0, SW[13],SW[14],SW[15],SW[16],~KEY[1],~KEY[2],SW[12],~KEY[0]};
assign joystick_1 = 32'd0;
assign joystick_2 = 32'd0;
assign joystick_3 = 32'd0;
assign joystick_4 = 32'd0;

/////////////////////////  VGA output  //////////////////////////////////
wire [23:0] vga_data_sl;
wire        vga_de_sl, vga_vs_sl, vga_hs_sl;

scanlines #(0) VGA_scanlines
(
	.clk(clk_vid),

	.scanlines(scanlines),
	.din(de_emu ? {r_out, g_out, b_out} : 24'd0),
	.hs_in(hs_fix),
	.vs_in(vs_fix),
	.de_in(de_emu),

	.dout(vga_data_sl),
	.hs_out(VGA_HS),
	.vs_out(VGA_VS)
);

wire [23:0] vga_o;
vga_out vga_out
(
	.ypbpr_full(1'b0),
	.ypbpr_en(1'b0),
	.dout(vga_o),
	.din(vga_data_sl)
);

assign VGA_R  = vga_o[23:16];
assign VGA_G  = vga_o[15:8];
assign VGA_B  = vga_o[7:0];

// Disable Blank and sync at VGA out.
assign VGA_BLANK_N = 1'b1; // (VGA_HS && VGA_VS);
assign VGA_SYNC_N = 0;

assign VGA_CLK = clk_vid;

////////////////  User I/O  /////////////////////////
// Open-drain User port (MiSTER SERJOYSTICK).
assign GPIO[29] = !user_out[0] ? 1'b0 : 1'bZ;
assign GPIO[30] = !user_out[1] ? 1'b0 : 1'bZ;
assign GPIO[31] = !user_out[2] ? 1'b0 : 1'bZ;
assign GPIO[32] = !user_out[3] ? 1'b0 : 1'bZ;
assign GPIO[33] = !user_out[4] ? 1'b0 : 1'bZ;
assign GPIO[34] = !user_out[5] ? 1'b0 : 1'bZ;
assign GPIO[35] = !user_out[6] ? 1'b0 : 1'bZ;

assign user_in[0] = GPIO[29];
assign user_in[1] = GPIO[30];
assign user_in[2] = GPIO[31];
assign user_in[3] = GPIO[32];
assign user_in[4] = GPIO[33];
assign user_in[5] = GPIO[34];
assign user_in[6] = GPIO[35];

///////////////////  User module connection ////////////////////////////
wire [15:0] audio_ls, audio_rs;
wire        audio_s;
wire  [1:0] audio_mix; // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
wire  [1:0] scanlines;
wire  [7:0] r_out, g_out, b_out;
wire        vs_fix, hs_fix, hs_emu, vs_emu, de_emu;
wire        clk_vid;
wire        led_user;
wire  [1:0] led_power;
wire  [1:0] led_disk;

sync_fix sync_v(clk_vid, vs_emu, vs_fix);
sync_fix sync_h(clk_vid, hs_emu, hs_fix);

wire  [6:0] user_out, user_in;

emu emu
(
	.CLK_50M(CLOCK_50),
	.RESET(reset),
	
	.JOY_0(joystick_0),
	.JOY_1(joystick_1),
	.JOY_2(joystick_2),
	.JOY_3(joystick_3),
	.JOY_4(joystick_4),

	.VGA_R(r_out),
	.VGA_G(g_out),
	.VGA_B(b_out),
	.VGA_HS(hs_emu),
	.VGA_VS(vs_emu),
	.VGA_DE(de_emu),    // = ~(VBlank | HBlank)
	.VGA_F1(),
	.VGA_SL(scanlines),

	.CLK_VIDEO(clk_vid),
	.CE_PIXEL(),	

	.LED_USER(led_user),
	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	.LED_POWER(led_power),
	.LED_DISK(led_disk),

	.AUDIO_L(audio_ls),
	.AUDIO_R(audio_rs),
	.AUDIO_S(audio_s),
	.AUDIO_MIX(audio_mix),

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
	
	.USER_OUT(user_out),
	.USER_IN(user_in),
	
	// FLASH controller interface
	.FL_DQ(FL_DQ),
	.FL_ADDR(FL_ADDR),	
	.FL_RST_N(FL_RST_N),
	.FL_CE_N(FL_CE_N),
	.FL_OE_N(FL_OE_N),
	.FL_WE_N(FL_WE_N),
	.FL_WP_N(FL_WP_N)
);

//********************************Audio**************************************
// Codec DE2-115 configuring by I2C
I2C_AV_Config  i2c_con
(
//      Host Side
.iCLK(CLOCK2_50),
.iRST_N(reset),
//      I2C Side
.oI2C_SCLK(I2C_SCLK),
.oI2C_SDAT(I2C_SDAT)
);

// Digital audio mixing
wire        clk_audio = CLOCK2_50;
wire [4:0]  vol_att = 0; //if (cmd == 'h26) vol_att <= io_din[4:0]. Genesis MiSTER sys_top.v(399).
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

audio_out audio_out
(
	.reset(reset),
	.clk(clk_audio),
	.sample_rate(1'b0), //0 - 48KHz, 1 - 96KHz
	.left_in(audio_l),
	.right_in(audio_r),
	.i2s_bclk(AUD_BCLK),
	.i2s_lrclk(AUD_DACLRCK),
	.i2s_data(AUD_DACDAT),
	
	.dac_l(AUDIO_L),
	.dac_r(AUDIO_R)
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
