//============================================================================
//
//  Genesis gamepads controller
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

module genesis_gamepads (
	input					iCLK,
	input					iN_RESET,
	
	input 		[5:0]	iGENPAD,			 // {C/Start, B/A, Up/Z, Down/Y, Left/X, Right/Mode}
	
	output 		[1:0]	oGENPAD_TYPE,	 // 0 - MasterSystem or unknown, 1 - 3-buttons, 2 - 6-buttons, 3 - error identify
	output reg			oGENPAD_SELECT = 1'b0, // Initial is LOW
	output reg [11:0]	oGENPAD_DECODED = 12'b0 // {Z,Y,X,M,S,C,B,A,U,D,L,R}
);

	reg [1:0]	padread_state = 2'd0;
	reg			type_button3, type_button6;
	
	assign oGENPAD_TYPE = type_button3 ? (type_button6 ? 2'd2 : 2'd1) : (type_button6 ? 2'd3 : 2'd0);

	always @(posedge iCLK) begin
		
		if (iN_RESET) begin
			case (padread_state)
				3'd0: begin
					if (oGENPAD_SELECT == 1'b0) begin
						if (iGENPAD[3:2] != 2'b00 && iGENPAD[1:0] == 2'b00) begin // If Left and Right pressed together, then it's 3-buttons PAD (pressed is 0, inverted logic)
							{oGENPAD_DECODED[7],oGENPAD_DECODED[4],oGENPAD_DECODED[3:2]} <= ~iGENPAD[5:2];

							type_button3 <= 1'b1;
						end
						else
							if (type_button3 == 1'b1)
								if (iGENPAD[3:0] == 4'b0000) begin // If all D-PAD was pressed at low oGENPAD_SELECT, then it's 6-buttons PAD
											type_button6 <= 1'b1;
											{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4];

											padread_state <= padread_state + 2'd1;
								end
								else type_button3 <= 1'b0;
							else begin // MasterSystem or unknown PAD
								{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= ~iGENPAD;
								type_button6 <= 1'b0;
							end
					end
					else begin
						{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= ~iGENPAD;
					end
					oGENPAD_SELECT <= ~oGENPAD_SELECT;
				end
				3'd1: begin
					if (oGENPAD_SELECT == 1'b1 && type_button3 == 1'b1 && type_button6 == 1'b1)
						{oGENPAD_DECODED[6:5],oGENPAD_DECODED[11:8]} <= ~iGENPAD; // C, B and extra buttons: Z, Y, X, MODE

					padread_state <= padread_state + 2'd1;

					oGENPAD_SELECT <= ~oGENPAD_SELECT;
				end
				3'd2: begin
					if (oGENPAD_SELECT == 1'b0 && type_button3 == 1'b1 && type_button6 == 1'b1)
						{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4]; // Start, A and third-party controllers button. Only Start and A used here by genesis_gamepads.

					padread_state <= 2'd0;

					oGENPAD_SELECT <= ~oGENPAD_SELECT;
				end
			endcase
		end
		else begin
			oGENPAD_SELECT <= '0;
			oGENPAD_DECODED <= '0;

			padread_state <= '0;
			type_button3 <= '0;
			type_button6 <= '0;
		end
	end

endmodule
