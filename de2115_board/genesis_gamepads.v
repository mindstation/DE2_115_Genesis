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
	
	output reg	[1:0]	oGENPAD_TYPE = 2'd0,	 // 0 - MasterSystem or unknown, 1 - 3-buttons, 2 - 6-buttons, 3 - error identify
	output reg			oGENPAD_SELECT = 1'b0, // Initial is LOW
	output reg [11:0]	oGENPAD_DECODED = 12'b0 // {Z,Y,X,M,S,C,B,A,U,D,L,R}
);

	reg [2:0]	padread_state = 3'd0;
	reg			type_button3, type_button6;
	
	always @(posedge iCLK) begin
		
		if (iN_RESET)
			case (padread_state)
				3'd0, 3'd2:
					if (iGENPAD[3:0] !== 4'b0000) begin // Original D-PAD can't be pressed in all directions, skip reading (pressed is 0, inverted logic)
						if (~oGENPAD_SELECT & ~iGENPAD[1] & ~iGENPAD[0]) begin // If Left and Right pressed together, then it's 3-buttons PAD
							type_button3 <= 1'b1;
							{oGENPAD_DECODED[7],oGENPAD_DECODED[4],oGENPAD_DECODED[3:2]} <= ~iGENPAD[5:2];
							oGENPAD_SELECT <= ~oGENPAD_SELECT;
						
							padread_state <= padread_state + 3'd1;
						end
						else begin
							{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= ~iGENPAD;
							type_button3 <= 1'b0;
							oGENPAD_TYPE <= 2'd0; // MasterSystem or unknown
						end
					end
				3'd1, 3'd3, 3'd7: begin
					{oGENPAD_DECODED[6:5],oGENPAD_DECODED[3:0]} <= ~iGENPAD;
					if (type_button3)
						oGENPAD_SELECT <= ~oGENPAD_SELECT;
					
					padread_state <= padread_state + 3'd1;
				end
				3'd4: begin
					if (~oGENPAD_SELECT & type_button3 & ~iGENPAD[3] & ~iGENPAD[2] & ~iGENPAD[1] & ~iGENPAD[0]) begin // If all D-PAD was pressed, then it's 6-buttons PAD
						type_button6 <= 1'b1;
						{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4];
						oGENPAD_SELECT <= ~oGENPAD_SELECT;
						
						padread_state <= padread_state + 3'd1;
					end
					else begin
						type_button6 <= 1'b0;
						if (type_button3) oGENPAD_TYPE <= 2'd1; // 3-buttons
						else oGENPAD_TYPE <= 2'd0; // MasterSystem or unknown
	
						{oGENPAD_DECODED[7],oGENPAD_DECODED[4],oGENPAD_DECODED[3:2]} <= ~iGENPAD[5:2];
	
						padread_state <= 3'd0;
					end
				end
				3'd5: begin
					if (oGENPAD_SELECT & type_button6) begin
						{oGENPAD_DECODED[6:5],oGENPAD_DECODED[11:8]} <= ~iGENPAD; // C, B and extra buttons: Z, Y, X, MODE
						oGENPAD_SELECT <= ~oGENPAD_SELECT;
					end
					
					// GENPAD type identify
					case ({type_button3,type_button6})
						2'b00: oGENPAD_TYPE <= 2'd0; // MasterSystem or unknown
						2'b01: oGENPAD_TYPE <= 2'd3; // ERROR identify
						2'b10: oGENPAD_TYPE <= 2'd1; // 3-buttons
						2'b11: oGENPAD_TYPE <= 2'd2; // 6-buttons
					endcase
					
					padread_state <= padread_state + 3'd1;
				end
				3'd6: begin
					if (type_button3) begin // This state gives same START and A buttons for 3-buttons and 6-buttons PAD
						{oGENPAD_DECODED[7],oGENPAD_DECODED[4]} <= ~iGENPAD[5:4]; // Start, A and third-party controllers button. Only Start and A used here by genesis_gamepads.
						oGENPAD_SELECT <= ~oGENPAD_SELECT;
					end
					
					padread_state <= padread_state + 3'd1;
				end
			endcase
		else begin
			oGENPAD_TYPE <= '0; 
			oGENPAD_SELECT <= '0;
			oGENPAD_DECODED <= '0;
			
			padread_state <= '0;
			type_button3 <= '0;
			type_button6 <= '0;
		end
	end

endmodule
