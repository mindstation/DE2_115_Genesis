//============================================================================
//
//  Genesis gamepads controller.
//  Only 3-buttons, 6-buttons, MasterSystem (and similar) gamepads are supported.
//  (c)2020-2022 Alexander Kirichenko
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

module genesis_gamepads 
# (parameter	select_latency = 1000,	// 1000 ticks at 50 MHz equals to 40 us
					xyzm_wait = 502,			// select_latency(40 us default) * 502 = 20.08 ms or 48 Hz, close to PAL VBLANK time with some reserve time
					read_latency = 48)			// read_latency is latency after oGENPAD_SELECT, before iGENPAD state change; typically - 32 tick at 50 MHz
(
	input					iCLK,           // 50 MHz
	input					iN_RESET,

	input			[5:0]	iGENPAD,			 // {C/Start, B/A, Up/Z, Down/Y, Left/X, Right/Mode}

	output		[1:0]	oGENPAD_TYPE,	 // 0 - MasterSystem or unknown, 1 - 3-buttons, 2 - 6-buttons, 3 - error identify
	output reg			oGENPAD_SELECT = 1'b0, // Initial is LOW
	output reg [11:0]	oGENPAD_DECODED = 12'b0 // {Z,Y,X,M,S,C,B,A,U,D,L,R}
);
	(* noprune *) reg [7:0] full_dpad_clk_count; // DEBUG

	reg [10:0]	pad_clk;
	reg [8:0]	xyzm_wait_cnt;

	reg [2:0]	padread_state = 3'd0;
	reg [5:0]	read_wait = 6'd0;
	reg			type_button3, type_button6;
	reg [5:0]	starta_buttons = 6'd0, mode_buttons = 6'd0;

	assign oGENPAD_TYPE = type_button3 ? (type_button6 ? 2'd2 : 2'd1) : (type_button6 ? 2'd3 : 2'd0);

	always @(posedge iCLK) begin
		pad_clk <= pad_clk + 10'd1;

		if (iN_RESET) begin

			if (iGENPAD[3:0] == 4'b0000) begin
				full_dpad_clk_count <= 8'b00000000;
			end
			else begin
				full_dpad_clk_count <= full_dpad_clk_count + 8'b00000001;
			end

			if (pad_clk == select_latency) begin
				oGENPAD_SELECT <= ~oGENPAD_SELECT;
				read_wait <= 6'd0;

				pad_clk <= 10'd0;
					
				case (padread_state)
					3'd0, 3'd2: begin
						if (oGENPAD_SELECT == 1'b0) begin
							padread_state <= padread_state + 3'd1;
						end
					end
					3'd1, 3'd7: begin
						if (oGENPAD_SELECT == 1'b1) begin
							padread_state <= padread_state + 3'd1;
						end
					end
					3'd3: begin
						if (oGENPAD_SELECT == 1'b1) begin
							if (type_button3) begin
								padread_state <= padread_state + 3'd1;
							end
							else
								padread_state <= 3'd0;
						end
					end
					3'd4: begin
						if (oGENPAD_SELECT == 1'b0) begin
							if	(iGENPAD[3:0] == 4'b0000 && xyzm_wait_cnt <= xyzm_wait) begin
								padread_state <= padread_state + 3'd1;

							end
							else if (xyzm_wait_cnt < xyzm_wait) begin
										xyzm_wait_cnt <= xyzm_wait_cnt + 9'd1;
									end
									else begin // full d-pad timeout
										xyzm_wait_cnt <= 9'd0;

										if (oGENPAD_SELECT == 1'b0) begin
												padread_state <= 3'd1;
											end
											else
												padread_state <= 3'd0;
									end
						end
						else
							if	(iGENPAD[3:0] == 4'b0000) begin 									// If all d-pad pressed at hight select, then it's just all d-pad pressed (possible for clone gamepads)
								padread_state <= 3'd0;
							end

					end
					3'd5: begin
						if (oGENPAD_SELECT == 1'b1) begin
							padread_state <= padread_state + 3'd1;

							xyzm_wait_cnt <= xyzm_wait_cnt + 9'd1;
						end

					end
					3'd6: begin
						if (oGENPAD_SELECT == 1'b0 && type_button3 == 1'b1) begin
							if (iGENPAD[3:0] == 4'b1111) begin									// All D-PAD of 6-buttons gamepad is "released" after extra buttons
								padread_state <= padread_state + 3'd1;

								xyzm_wait_cnt <= 9'd0;
							end
						end
						else if (xyzm_wait_cnt > xyzm_wait) begin
									xyzm_wait_cnt <= 9'd0;

									padread_state <= 3'd1;
								end
								else begin
									xyzm_wait_cnt <= xyzm_wait_cnt + 9'd1;

									padread_state <= 3'd4;
								end

					end
				endcase
			end
			else
				pad_clk <= pad_clk + 10'd1;

			if (read_wait < read_latency) begin
				read_wait <= read_wait + 6'd1;
			end

			if (read_wait >= read_latency) begin
				case (padread_state)
					3'd0, 3'd2: begin
						if (oGENPAD_SELECT == 1'b0) begin
							starta_buttons <= ~iGENPAD;			// If all D-PAD is pressed at low oGENPAD_SELECT, then it can be start+A or some MasterSystem like PAD
							if (iGENPAD[3:0] != 4'b0000) begin
								if (iGENPAD[1:0] == 2'b00) begin // If Left and Right pressed together, then it's 3-buttons PAD (pressed is 0, inverted logic)
									{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4];

									type_button3 <= 1'b1;
								end
								else begin
									type_button3 <= 1'b0;
								end
							end

						end
					end
					3'd1, 3'd3, 3'd7: begin
						if (type_button3) begin // ModelSim Intel FPGA Starter Edition 10.5b will always run else block if begin/end operators don't frame nested "if"
							if (iGENPAD[3:0] == 4'b0000 && starta_buttons[3:0] == 4'b0000 && type_button3) begin // If all D-PAD is pressed at low and hight oGENPAD_SELECT, then previous iGENPAD was Start and A set, highly likely
								{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~starta_buttons[5:4];
							end
						end
						else							 // MasterSystem or unknown PAD
							type_button6 <= 1'b0; // If gamepad isn't 3-buttons PAD, then it's not 6-buttons PAD too

						if (oGENPAD_SELECT == 1'b1)
							{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= ~iGENPAD; // The only place updating MasterSystem PAD state
					end
					3'd4: begin
						if (oGENPAD_SELECT == 1'b0) begin	// All D-PAD may be pressed at low oGENPAD_SELECT, then it's 6-buttons PAD,
																		// or user has pressed D-PAD on the 3-buttons/6-buttons clone gamepad
							{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4];
						end
						else
							{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= ~iGENPAD;
							
						if (xyzm_wait_cnt > xyzm_wait) begin
							type_button6 <= 1'b0;
						end
					end
					3'd5: begin
						if (oGENPAD_SELECT == 1'b1 && type_button3 == 1'b1)
							mode_buttons <= ~iGENPAD; // C, B and extra buttons, maybe: Z, Y, X, MODE

					end
					3'd6: begin
						if (oGENPAD_SELECT == 1'b0 && type_button3 == 1'b1) begin
							if (iGENPAD[3:0] == 4'b1111) begin // If all D-PAD was released at low oGENPAD_SELECT after full D-PAD pressing, then it's 6-buttons PAD, highly likely
								{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4]; // Start, A and third-party controller buttons. But the Genesis core doesn't support third-party extra buttons. Only Start and A used here.
								{oGENPAD_DECODED[6:5],oGENPAD_DECODED[11:8]} <= mode_buttons;

								type_button6 <= 1'b1;
							end
							else begin
								{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= mode_buttons; // If all D-PAD wasn't released at low oGENPAD_SELECT after full D-PAD pressing, then mode_buttons is C, B and D-PAD.
							end
						end
					end
				endcase

			end
		end
		else begin
			full_dpad_clk_count <= 8'd0;

			pad_clk <= 10'd0;
			xyzm_wait_cnt <= 9'd0;

			oGENPAD_SELECT <= 1'b0;
			oGENPAD_DECODED <= 12'b0;

			padread_state <= 3'd0;
			read_wait = 6'd0;
			type_button3 <= 1'b0;
			type_button6 <= 1'b0;
		end
	end

endmodule
