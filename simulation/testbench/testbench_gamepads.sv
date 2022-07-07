`timescale 1ns/1ns

module testbench_gamepads();

	logic				fpga_clk_50, nreset;
	
	logic [15:0]	decode_error_count = '0, genpad_type_error_count = '0;
	logic [2:0]		select_count = '0;
	
	logic	[11:0]	dummy_buttons = '0; // {Z,Y,X,M,S,C/2,B/1,A,U,D,L,R}, MasterSystem PAD button 2 is used as C button, button 1 is used as B button
	logic	[1:0] 	pad_type = '0, old_pad_type;
	logic				pad_hold_buttons = '0;
	
	wire				genpad_select;
	logic	[2:0]		pad6_state = '0;
	wire	[1:0]		genpad_type_detected;
	wire	[5:0]		dummy_genpad;
	wire	[11:0]	genpad_decoded;
	logic [11:0]	old_genpad_decoded;
	
	function [15:0] inc_overflow;
		input [15:0] count;
		
		if (&count) begin
			$display ("Increment overflow! count=%b Simulation was stopped.", count);
			$finish;
		end
		else
			inc_overflow = count + 16'd1;
	
	endfunction
	
	// instatiate device to be tested
	genesis_gamepads dut (
		.iCLK(fpga_clk_50),
		.iN_RESET(nreset),
		
		.iGENPAD(dummy_genpad),
		
		.oGENPAD_TYPE(genpad_type_detected),
		.oGENPAD_SELECT(genpad_select),
		.oGENPAD_DECODED(genpad_decoded)
	);
	
	// Genesis gamepad dummy
	genpad_dummy genesis_pad (
		.iCLK(fpga_clk_50),
		.iN_RESET(nreset),

		.iPADTYPE(pad_type),
		.iSELECT(genpad_select),
		.iBUTTONS(dummy_buttons),

		.oGENPAD(dummy_genpad)
	);

////// initilize testbench
	initial begin
	
		$timeformat(-12, 0, " ns"); // Print simulation time in ns
		
		old_pad_type <= pad_type;
		
		case (pad_type) // MasterSystem PAD
			2'b00: // Master System PAD
				$display ("pad_type is %b. MasterSystem PAD testing.", pad_type);
			2'b01: // 3-buttons Genesis PAD
				$display ("pad_type is %b. Genesis 3-buttons PAD testing.", pad_type);
			2'b10: // 6-buttons Genesis PAD
				$display ("pad_type is %b. Genesis 6-buttons PAD testing.", pad_type);
			default: begin
				$display ("Invalid pad_type %b ! Simulation was stopped.", pad_type);
				$finish;
			end				
		endcase
		
	end
	
	initial begin
			nreset <= 0; #44; nreset <= 1;
	end
	
////// generate clock to sequence tests
	always begin

			fpga_clk_50 <= 1; #10; fpga_clk_50 <= 0; #10;

	end

///// Press buttons
// ModelSim Intel FPGA Starter Edition 10.5b will skip else block if begin/end doesn't frame nested "if".
	always @(posedge fpga_clk_50) begin
		if (nreset) begin
			case (pad_type)
				2'b00: begin // Master System PAD
					if	(pad_hold_buttons) begin
						if (dummy_buttons[3:0] == 4'b1111)
							dummy_buttons[6:5] <= dummy_buttons[6:5] + 1'b1;
			
						case (dummy_buttons[3:0]) // It is impossible to press Left and Right at the same time without Up and Down
							4'b0000: dummy_buttons[3:0] <= 4'b0001; // genesis_gamepad controller uses Left+Right pattern as genesis PAD sign
							4'b0001: dummy_buttons[3:0] <= 4'b0101;
							4'b0101: dummy_buttons[3:0] <= 4'b1001;
							4'b1001: dummy_buttons[3:0] <= 4'b0010;
							4'b0010: dummy_buttons[3:0] <= 4'b0110;
							4'b0110: dummy_buttons[3:0] <= 4'b1010;
							4'b1010: dummy_buttons[3:0] <= 4'b1111;
							4'b1111: dummy_buttons[3:0] <= '0;
							default: dummy_buttons[3:0] <= 'x;
						endcase
						
						if (dummy_buttons[6:5] == '1 && dummy_buttons[3:0] == '1) begin // All buttons with and without hold were tested
							pad_hold_buttons <= ~pad_hold_buttons;
							pad_type <= pad_type + 2'd1;
	
							$display ("pad_type changed to %b. Genesis 3-buttons PAD testing.", (pad_type + 2'd1));
						end
					end
					else begin
						if (dummy_buttons)
							{dummy_buttons[6:5],dummy_buttons[3:0]} <= {dummy_buttons[6:5],dummy_buttons[3:0]} << 1'd1;
						else
							dummy_buttons <= 12'b000000000001;
							
						if (dummy_buttons[6]) begin
							pad_hold_buttons <= ~pad_hold_buttons;
							dummy_buttons <= '0; // Reset buttons after pass with "hold"/"no hold" buttons test
						end
					end
				end
				2'b01: begin // 3-buttons Genesis PAD
					if	(pad_hold_buttons) begin
						if (dummy_buttons[3:0] == 4'b1111)
							dummy_buttons[7:4] <= dummy_buttons[7:4] + 1'b1;
			
						case (dummy_buttons[3:0]) // It is impossible to press Left and Right at the same time without Up and Down
							4'b0000: dummy_buttons[3:0] <= 4'b0001; // genesis_gamepad controller uses Left+Right pattern as genesis PAD sign
							4'b0001: dummy_buttons[3:0] <= 4'b0101;
							4'b0101: dummy_buttons[3:0] <= 4'b1001;
							4'b1001: dummy_buttons[3:0] <= 4'b0010;
							4'b0010: dummy_buttons[3:0] <= 4'b0110;
							4'b0110: dummy_buttons[3:0] <= 4'b1010;
							4'b1010: dummy_buttons[3:0] <= 4'b1111;
							4'b1111: dummy_buttons[3:0] <= '0;
							default: dummy_buttons[3:0] <= 'x;
						endcase
						
						if (dummy_buttons[7:0] == '1) begin // All buttons with and without hold were tested
							pad_hold_buttons <= ~pad_hold_buttons;
							pad_type <= pad_type + 2'd1;
	
							$display ("pad_type changed to %b. Genesis 6-buttons PAD testing.", (pad_type + 2'd1));
						end
					end
					else begin
						if (dummy_buttons)
							dummy_buttons[7:0] <= dummy_buttons[7:0] << 1'd1;
						else
							dummy_buttons <= 12'b000000000001;
	
						if (dummy_buttons[7]) begin
							pad_hold_buttons <= ~pad_hold_buttons;
							dummy_buttons <= '0; // Reset buttons after pass with "hold"/"no hold" buttons test
						end
					end
				end
				2'b10: begin // 6-buttons Genesis PAD
					if	(pad_hold_buttons) begin
						if (dummy_buttons[3:0] == 4'b1111)
							dummy_buttons[11:4] <= dummy_buttons[11:4] + 1'b1;
			
						case (dummy_buttons[3:0]) // It is impossible to press Left and Right at the same time without Up and Down
							4'b0000: dummy_buttons[3:0] <= 4'b0001; // genesis_gamepad controller uses Left+Right pattern as genesis PAD sign
							4'b0001: dummy_buttons[3:0] <= 4'b0101;
							4'b0101: dummy_buttons[3:0] <= 4'b1001;
							4'b1001: dummy_buttons[3:0] <= 4'b0010;
							4'b0010: dummy_buttons[3:0] <= 4'b0110;
							4'b0110: dummy_buttons[3:0] <= 4'b1010;
							4'b1010: dummy_buttons[3:0] <= 4'b1111;
							4'b1111: dummy_buttons[3:0] <= '0;
							default: dummy_buttons[3:0] <= 'x;
						endcase
						
						if (dummy_buttons[11:0] == '1) begin // All buttons for all PAD types were tested
							pad_hold_buttons <= ~pad_hold_buttons;
							pad_type <= pad_type + 2'd1;
	
							$display ("All PAD type tests are complited with %d errors.", (decode_error_count + genpad_type_error_count));
							$finish;
						end
					end
					else begin
						if (dummy_buttons)
							dummy_buttons <= dummy_buttons << 1'd1;
						else
							dummy_buttons <= 12'b000000000001;
							
						if (dummy_buttons[11]) begin
							pad_hold_buttons <= ~pad_hold_buttons;
							dummy_buttons <= '0; // Reset buttons after pass with "hold"/"no hold" buttons test
						end
					end
				end
				default: begin
					$display ("Invalid pad_type %b ! Simulation was stopped.", pad_type);
					$finish;
				end
			endcase
			#288; // Button press latency 288ns, for a fast simulation
		end
		else begin
			pad_hold_buttons <= '0;
			dummy_buttons <= '0;
		end
	end
		
////// results check
	always @(genpad_decoded) begin // If all D-PAD is pressed and pad_type=00 or 01, then dut doesn't update genpad_decoded
		if (pad_type == 2'b00) begin // Master System PAD
			if (genpad_decoded !== dummy_buttons) begin
				$display ("%t: Gamepad decoding ERROR! genpad_decoded=%b is not equal to dummy_buttons=%b", $time, genpad_decoded, dummy_buttons);
				decode_error_count <= inc_overflow(decode_error_count);
			end
		end

		old_genpad_decoded <= genpad_decoded;

	end

	always @(genpad_select) begin
		if (nreset) begin
			if (old_pad_type == pad_type) begin
				select_count <= select_count + 1'd1;
				if (select_count == 3'd5 && genpad_type_detected !== pad_type) begin // Fifth select is time for detecting PAD type (see genesis_gamepad module)
					$display ("%t: Gamepad type detect ERROR! genpad_type_detected=%b is not equal to pad_type=%b", $time, genpad_type_detected, pad_type);
					genpad_type_error_count <= inc_overflow(genpad_type_error_count);
				end
			end
			else begin
				old_pad_type <= pad_type;
				select_count <= 1'd1;
			end

			if (old_genpad_decoded != genpad_decoded) begin // If all D-PAD is pressed and pad_type=00 or 01, then dut doesn't update genpad_decoded
				case (pad_type)
					2'b01: begin // 3-buttons Genesis PAD
						if (~genpad_select) begin // used previous genpad_select, because genpad_decoded shows previous dummy_buttons state
							if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]}) begin
								$display ("%t: Gamepad decoding ERROR! genpad_decoded{[6:5],[3:0]}=%b is not equal to dummy_buttons{[6:5],[3:0]}=%b after genpad_select=%b", $time, genpad_decoded, dummy_buttons, ~genpad_select);
								decode_error_count <= inc_overflow(decode_error_count);
							end
						end
						else begin
							if ({genpad_decoded[7],genpad_decoded[4],genpad_decoded[3:2]} !== {dummy_buttons[7],dummy_buttons[4],dummy_buttons[3:2]}) begin
								$display ("%t: Gamepad decoding ERROR! genpad_decoded{[7],[4],[3:2]}=%b is not equal to dummy_buttons{[7],[4],[3:2]}=%b after genpad_select=%b", $time, genpad_decoded, dummy_buttons, ~genpad_select);
								decode_error_count <= inc_overflow(decode_error_count);
							end
						end
					end
					2'b10: begin // 6-buttons Genesis PADs
						if (old_pad_type == pad_type) begin
							case (select_count)
								3'd0, 3'd2:
									if ({genpad_decoded[7],genpad_decoded[4],genpad_decoded[3:2]} !== {dummy_buttons[7],dummy_buttons[4],dummy_buttons[3:2]}) begin
										$display ("%t: Gamepad decoding ERROR! genpad_decoded{[7],[4],[3:2]}=%b is not equal to dummy_buttons{[7],[4],[3:2]}=%b at select_count=%b", $time, genpad_decoded, dummy_buttons, select_count);
										decode_error_count <= inc_overflow(decode_error_count);
									end
								3'd1, 3'd3, 3'd7:
									if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]}) begin
										$display ("%t: Gamepad decoding ERROR! genpad_decoded{[6:5],[3:0]}=%b is not equal to dummy_buttons{[6:5],[3:0]}=%b at select_count=%b", $time, genpad_decoded, dummy_buttons, select_count);
										decode_error_count <= inc_overflow(decode_error_count);
									end
								3'd4, 3'd6:
									if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]}) begin
										$display ("%t: Gamepad decoding ERROR! genpad_decoded{[7],[4]}=%b is not equal to dummy_buttons{[7],[4]}=%b at select_count=%b", $time, genpad_decoded, dummy_buttons, select_count);
										decode_error_count <= inc_overflow(decode_error_count);
									end
								3'd5:
									if ({genpad_decoded[6:5],genpad_decoded[11:8]} !== {dummy_buttons[6:5],dummy_buttons[11:8]}) begin
										$display ("%t: Gamepad decoding ERROR! genpad_decoded{[6:5],[11:8]}=%b is not equal to dummy_buttons{[6:5],[11:8]}=%b at select_count=%b", $time, genpad_decoded, dummy_buttons, select_count);
										decode_error_count <= inc_overflow(decode_error_count);
									end
								default: begin
									$display ("Invalid select_count %b at genpad_decoded check! Simulation was stopped.", select_count);
									$finish;
								end
							endcase
						end
					end
				endcase
			end
		end
		else begin
			old_pad_type <= pad_type;
			select_count <= '0;
			
			old_genpad_decoded <= genpad_decoded;
		end

	end

endmodule:testbench_gamepads

/////////////////////////  Genesis gamepad dummy  //////////////////////////////////
module genpad_dummy(
		input							iCLK,		// 50MHz
		input							iN_RESET,
		
		input				[1:0]		iPADTYPE,
		input			 				iSELECT,
		input 			[11:0]	iBUTTONS = '0, // {Z,Y,X,M,S,C/2,B/1,A,U,D,L,R}, MasterSystem PAD button 2 is used as C button, button 1 is used as B button
		
		output			[5:0]		oGENPAD // {C/Start, B/A, Up/Z, Down/Y, Left/X, Right/Mode}
	);

	logic	[5:0]		genpad_out = '1;
	logic	[2:0]		genpad6b_state = '0;
	logic				old_select = '0;
	logic [16:0]	genpad6b_res_timer = '0;
	logic				genpad6b_timeout = '0;
	
	// Out Genesis (genpad_out) or Master System PAD
	assign oGENPAD = iPADTYPE[1] ? (iPADTYPE[0] ? 'x : genpad_out) : (iPADTYPE[0] ? genpad_out : ~{iBUTTONS[6:5],iBUTTONS[3:0]});
	
	// Genesis PAD output
	always @(iSELECT or posedge genpad6b_timeout) begin
		if (~genpad6b_timeout && iN_RESET && iPADTYPE == 2'b10)
			genpad6b_state <= genpad6b_state + 1'd1;
		else
			genpad6b_state <= '0;
	end
	
	always @(iBUTTONS or iSELECT) begin
		if (iN_RESET) begin
			case(iPADTYPE)
				2'b01: begin // 3-buttons Genesis PAD
					if (iSELECT)
						genpad_out <= ~{iBUTTONS[6:5],iBUTTONS[3:0]};
					else
						genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; // It is impossible to press Left and Right at the same time, this is a 3-buttons PAD sign
				end
				2'b10: begin // 6-buttons Genesis PAD
					case(genpad6b_state)
						3'd0, 3'd1, 3'd2, 3'd6, 3'd7:
							if (iSELECT)
								genpad_out <= ~{iBUTTONS[6:5],iBUTTONS[3:0]};
							else
								genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; // START and A buttons set. It is impossible to press Left and Right at the same time, this is a 3-buttons PAD sign
						3'd3:
							genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],1'b1,1'b1,1'b1,1'b1};					// All D-PAD is "pressed" before extra buttons
						3'd4:
							genpad_out <= ~{iBUTTONS[6:5],iBUTTONS[11:8]};										// It's C, B and extra (MXYZ) buttons set
						3'd5:
							genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],1'b0,1'b0,1'b0,1'b0};					// All D-PAD of 6-buttons gamepad is "released" after extra buttons
					endcase																									// A third-party gamepad can give there its extra buttons
				end
			endcase
		end
		else genpad_out = '1;
	end
	
///// Genesis 6-buttons PAD - extra buttons timeout

	// iSELECT timeout counter
	always @(posedge iCLK) begin // 1 / 50 MHz = 20ns
		if (iN_RESET) begin
			if (~old_select & iSELECT) 							// Reset timeout counter every posedge iSELECT
				genpad6b_res_timer <= '0;
			else
				genpad6b_res_timer <= genpad6b_res_timer + 1'd1;
				
			old_select <= iSELECT;

			if (genpad6b_res_timer == 17'd75000) begin	// 75000 * 20ns = 1,5 ms extra buttons timeout
				genpad6b_timeout <= '1;
				genpad6b_res_timer <= '0;
			end
			else
				genpad6b_timeout <= '0;
		end
		else begin
			genpad6b_timeout <= '0;
			genpad6b_res_timer <= '0;
		end
	end
	
endmodule:genpad_dummy
