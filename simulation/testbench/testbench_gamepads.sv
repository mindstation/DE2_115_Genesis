`timescale 1ns/1ns

module testbench_gamepads();

	logic				fpga_clk_50, nreset;
	
	logic [15:0]	decode_error_count = '0, genpad_type_error_count = '0;
	
	logic				buttons_clk; // dummy_buttons press clock
	logic	[11:0]	dummy_buttons = '0; // {Z,Y,X,M,S,C/2,B/1,A,U,D,L,R}, MasterSystem PAD button 2 is used as C button, button 1 is used as B button
	logic	[5:0]		mode_buttons;
	logic	[1:0] 	pad_type = '0;
	logic				pad_hold_buttons = '0;
	
	wire				genpad_select;
	logic				old_genpad_select = '0;
	wire	[2:0]		pad6_state;
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
	
	function [3:0] dpad_generator;
		input [3:0] id_pad;
		
		case (id_pad[3:0]) // It is impossible to press Left and Right at the same time without Up and Down
			4'b0000: dpad_generator[3:0] = 4'b0001; // genesis_gamepad controller uses Left+Right pattern as genesis PAD sign
			4'b0001: dpad_generator[3:0] = 4'b0101;
			4'b0101: dpad_generator[3:0] = 4'b1001;
			4'b1001: dpad_generator[3:0] = 4'b0010;
			4'b0010: dpad_generator[3:0] = 4'b0110;
			4'b0110: dpad_generator[3:0] = 4'b1010;
			4'b1010: dpad_generator[3:0] = 4'b1111;
			4'b1111: dpad_generator[3:0] = '0;
			default: dpad_generator[3:0] = 'x;
		endcase
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

		.oGENPAD(dummy_genpad),
		.oPAD6B_STATE(pad6_state)
	);

////// initilize testbench
	initial begin
	
		$timeformat(-12, 0, " ns"); // Print simulation time in ns
		
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

	always begin
		buttons_clk <= 1; #144; buttons_clk <=0; #144; // Button press latency 288ns, for a fast simulation

	end

///// Press buttons
// ModelSim Intel FPGA Starter Edition 10.5b will always run else block if begin/end operators don't frame nested "if".
	always @(posedge buttons_clk) begin
		if (nreset) begin
			case (pad_type)
				2'b00: begin // Master System PAD
					if	(pad_hold_buttons) begin
						if (dummy_buttons[3:0] == 4'b1111)
							dummy_buttons[6:5] <= dummy_buttons[6:5] + 1'b1;

						dummy_buttons[3:0] <= dpad_generator(dummy_buttons[3:0]);

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

						dummy_buttons[3:0] <= dpad_generator(dummy_buttons[3:0]);

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

						dummy_buttons[3:0] <= dpad_generator(dummy_buttons[3:0]);

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
		end
		else begin
			pad_hold_buttons <= '0;
			dummy_buttons <= '0;
		end
	end

////// results check
	always @(genpad_decoded) begin
		if (pad_type == 2'b00) begin // Master System PAD
			if (genpad_select == 1'b1 && genpad_type_detected !== pad_type) begin
				$display ("%t: Gamepad type detect ERROR! genpad_type_detected=%b is not equal to pad_type=%b", $time, genpad_type_detected, pad_type);
				genpad_type_error_count <= inc_overflow(genpad_type_error_count);
			end
			if (genpad_decoded !== dummy_buttons) begin
				$display ("%t: Gamepad decoding ERROR! genpad_decoded=%b is not equal to dummy_buttons=%b", $time, genpad_decoded, dummy_buttons);
				decode_error_count <= inc_overflow(decode_error_count);
			end
		end

	end

	always @(genpad_select) begin
		if (nreset) begin
			if (pad_type == 2'b10 && pad6_state == 3'd6)
				mode_buttons <= {dummy_buttons[6:5],dummy_buttons[11:8]};
			if (old_genpad_decoded != genpad_decoded) begin
				case (pad_type)
					2'b01: begin // 3-buttons Genesis PAD
						if (genpad_select == 1'b1 && genpad_type_detected !== pad_type) begin
							$display ("%t: Gamepad type detect ERROR! genpad_type_detected=%b is not equal to pad_type=%b", $time, genpad_type_detected, pad_type);
							genpad_type_error_count <= inc_overflow(genpad_type_error_count);
						end
						if (old_genpad_select) begin // used previous genpad_select, because genpad_decoded has a 1 clock delay
							if (dummy_buttons[3:0] == 4'b1111) begin // If all D-PAD was pressed on the 3-buttons clone gamepad, then genpad_decoded consists {S,C/2,B/1,A,U,D,L,R} button updates
								if (genpad_decoded[7:0] !== dummy_buttons[7:0] || genpad_decoded[11:8] !== old_genpad_decoded[11:8]) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR after genpad_select=%b!", $time, ~genpad_select);
								end
								if (genpad_decoded[7:0] !== dummy_buttons[7:0]) begin
									$display ("genpad_decoded[7:0]=%b is not equal to dummy_buttons[7:0]=%b.", genpad_decoded[7:0], dummy_buttons[7:0]);
								end
								if (genpad_decoded[11:8] !== old_genpad_decoded[11:8]) begin
									$display ("genpad_decoded[11:8]=%b changed from %b.", genpad_decoded[11:8], old_genpad_decoded[11:8]);
								end
							end
							else begin
								if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]} || {genpad_decoded[11:7],genpad_decoded[4]} !== {old_genpad_decoded[11:7],old_genpad_decoded[4]}) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR after genpad_select=%b!", $time, ~genpad_select);
								end
								if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]}) begin
									$display ("genpad_decoded{[6:5],[3:0]}=%b is not equal to dummy_buttons{[6:5],[3:0]}=%b.", {genpad_decoded[6:5],genpad_decoded[3:0]}, {dummy_buttons[6:5],dummy_buttons[3:0]});
								end
								if ({genpad_decoded[11:7],genpad_decoded[4]} !== {old_genpad_decoded[11:7],old_genpad_decoded[4]}) begin
									$display ("genpad_decoded{[11:7],[4]}=%b changed from %b.", {genpad_decoded[11:7],genpad_decoded[4]}, {old_genpad_decoded[11:7],old_genpad_decoded[4]});
								end
							end
						end
						else begin
							if (dummy_buttons[3:0] == 4'b1111) begin // genpad_decoded was not updated if all D-PAD was pressed on the 3-buttons clone gamepad
								if (genpad_decoded[11:0] !== old_genpad_decoded[11:0]) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR after genpad_select=%b!", $time, ~genpad_select);
									$display ("genpad_decoded[11:0]=%b changed from %b.", genpad_decoded[11:0], old_genpad_decoded[11:0]);
								end
							end
							else begin
								if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]} || {genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]} !== {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]}) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR after genpad_select=%b!", $time, ~genpad_select);
								end
								if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]}) begin
									$display ("genpad_decoded{[7],[4]}=%b is not equal to dummy_buttons{[7],[4]}=%b.", {genpad_decoded[7],genpad_decoded[4]}, {dummy_buttons[7],dummy_buttons[4]});
								end
								if ({genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]} !== {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]}) begin
									$display ("genpad_decoded{[11:8],[6:5],[3:0]}=%b changed from %b.", {genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]}, {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]});
									decode_error_count <= inc_overflow(decode_error_count);
								end
							end
						end
					end
					2'b10: begin // 6-buttons Genesis PADs
						if (pad6_state == 3'd7 && genpad_type_detected !== pad_type) begin
							$display ("%t: Gamepad type detect ERROR! genpad_type_detected=%b is not equal to pad_type=%b", $time, genpad_type_detected, pad_type);
							genpad_type_error_count <= inc_overflow(genpad_type_error_count);
						end
						case (pad6_state)
							3'd0, 3'd1, 3'd2, 3'd3, 3'd4: begin
								if (old_genpad_select) begin // used previous genpad_select, because genpad_decoded has a 1 clock delay
									if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]} || {genpad_decoded[11:7],genpad_decoded[4]} !== {old_genpad_decoded[11:7],old_genpad_decoded[4]}) begin
										decode_error_count <= inc_overflow(decode_error_count);
										$display ("%t: Gamepad decoding ERROR at pad6_state=%d!", $time, pad6_state);
									end
									if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]}) begin
										$display ("genpad_decoded{[6:5],[3:0]}=%b is not equal to dummy_buttons{[6:5],[3:0]}=%b.", {genpad_decoded[6:5],genpad_decoded[3:0]}, {dummy_buttons[6:5],dummy_buttons[3:0]});
									end
									if ({genpad_decoded[11:7],genpad_decoded[4]} !== {old_genpad_decoded[11:7],old_genpad_decoded[4]}) begin
										$display ("genpad_decoded{[11:7],[4]}=%b changed from %b.", {genpad_decoded[11:7],genpad_decoded[4]}, {old_genpad_decoded[11:7],old_genpad_decoded[4]});
									end
								end
								else begin
									if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]} || {genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]} !== {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]}) begin
										decode_error_count <= inc_overflow(decode_error_count);
										$display ("%t: Gamepad decoding ERROR at pad6_state=%d!", $time, pad6_state);
									end
									if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]}) begin
										$display ("genpad_decoded{[7],[4]}=%b is not equal to dummy_buttons{[7],[4]}=%b.", {genpad_decoded[7],genpad_decoded[4]}, {dummy_buttons[7],dummy_buttons[4]});
									end
									if ({genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]} !== {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]}) begin
										$display ("genpad_decoded{[11:8],[6:5],[3:0]}=%b changed from %b.", {genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]}, {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]});
									end
								end
							end
							3'd5: begin
								if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]} || {genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]} !== {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]}) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR at pad6_state=%d!", $time, pad6_state);
								end
								if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]}) begin
									$display ("genpad_decoded{[7],[4]}=%b is not equal to dummy_buttons{[7],[4]}=%b", {genpad_decoded[7],genpad_decoded[4]}, {dummy_buttons[7],dummy_buttons[4]});
								end
								if ({genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]} !== {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]}) begin
									$display ("genpad_decoded{[11:8],[6:5],[3:0]}=%b changed from %b.", {genpad_decoded[11:8],genpad_decoded[6:5],genpad_decoded[3:0]}, {old_genpad_decoded[11:8],old_genpad_decoded[6:5],old_genpad_decoded[3:0]});
								end
							end
							3'd6: begin
								if (genpad_decoded[11:0] !== old_genpad_decoded[11:0]) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR at pad6_state=%d!", $time, pad6_state);
									$display ("genpad_decoded[11:0]=%b changed from %b.", genpad_decoded[11:0],old_genpad_decoded[11:0]);
								end
							end
							3'd7: begin
								if ({genpad_decoded[7],genpad_decoded[4],genpad_decoded[6:5],genpad_decoded[11:8]} !== {dummy_buttons[7],dummy_buttons[4],mode_buttons} || genpad_decoded[3:0] !== old_genpad_decoded[3:0]) begin
									decode_error_count <= inc_overflow(decode_error_count);
									$display ("%t: Gamepad decoding ERROR at pad6_state=%d!", $time, pad6_state);
								end
								if ({genpad_decoded[7],genpad_decoded[4]} !== {dummy_buttons[7],dummy_buttons[4]}) begin
									$display ("genpad_decoded{[7],[4]}=%b is not equal to dummy_buttons{[7],[4]}=%b", {genpad_decoded[7],genpad_decoded[4]}, {dummy_buttons[7],dummy_buttons[4]});
								end
								if ({genpad_decoded[6:5],genpad_decoded[11:8]} !== mode_buttons) begin
									$display ("genpad_decoded{[6:5],[11:8]}=%b is not equal to old_dummy_buttons{[6:5],[11:8]}=%b", {genpad_decoded[6:5],genpad_decoded[11:8]}, mode_buttons);
								end
								if (genpad_decoded[3:0] !== old_genpad_decoded[3:0]) begin
									$display ("genpad_decoded[3:0]=%b changed from %b.", genpad_decoded[3:0], old_genpad_decoded[3:0]);
								end
							end
							default: begin
								$display ("Invalid pad6_state %b at genpad_decoded check! Simulation was stopped.", pad6_state);
								$finish;
							end
						endcase
					end
				endcase
			end
			old_genpad_decoded <= genpad_decoded;
		end
		else begin
			old_genpad_decoded <= genpad_decoded;
		end
		old_genpad_select <= genpad_select;
	end

endmodule:testbench_gamepads

/////////////////////////  Genesis gamepad dummy  //////////////////////////////////
module genpad_dummy(
		input							iCLK,		// 50MHz
		input							iN_RESET,
		
		input				[1:0]		iPADTYPE,
		input			 				iSELECT,
		input 			[11:0]	iBUTTONS = '0, // {Z,Y,X,M,S,C/2,B/1,A,U,D,L,R}, MasterSystem PAD button 2 is used as C button, button 1 is used as B button
		
		output	logic	[5:0]		oGENPAD, // {C/Start, B/A, Up/Z, Down/Y, Left/X, Right/Mode}
		output	logic	[2:0]		oPAD6B_STATE
	);

	logic				old_select = '0;
	logic [16:0]	genpad6b_res_timer = '0;
	logic				genpad6b_timeout = '0;

	// Genesis PAD output
	always @(iSELECT or posedge genpad6b_timeout) begin
		if (~genpad6b_timeout && iN_RESET && iPADTYPE == 2'b10)
			if (oPAD6B_STATE == 3'd0) begin
				if (iSELECT) begin
					oPAD6B_STATE <= oPAD6B_STATE + 3'd2;
				end
				else
					oPAD6B_STATE <= oPAD6B_STATE + 3'd1;
			end
			else
				oPAD6B_STATE <= oPAD6B_STATE + 3'd1;
		else
			oPAD6B_STATE <= '0;
	end
	
	always_comb begin
		case(iPADTYPE)
			2'b00: begin // Master System PAD
				oGENPAD = ~{iBUTTONS[6:5],iBUTTONS[3:0]};
			end
			2'b01: begin // 3-buttons Genesis PAD
				if (iSELECT)
					oGENPAD = ~{iBUTTONS[6:5],iBUTTONS[3:0]};
				else
					oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; // It is impossible to press Left and Right at the same time, this is a 3-buttons PAD sign
			end
			2'b10: begin // 6-buttons Genesis PAD
				case(oPAD6B_STATE)
					3'd0, 3'd1, 3'd2, 3'd3, 3'd4:
						if (iSELECT)
							oGENPAD = ~{iBUTTONS[6:5],iBUTTONS[3:0]};
						else
							oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; // START and A buttons set. It is impossible to press Left and Right at the same time, this is a 3-buttons PAD sign
					3'd5:
						oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],1'b1,1'b1,1'b1,1'b1};					// All D-PAD is "pressed" before extra buttons
					3'd6:
						oGENPAD = ~{iBUTTONS[6:5],iBUTTONS[11:8]};										// It's C, B and extra (MXYZ) buttons set
					3'd7:
						oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],1'b0,1'b0,1'b0,1'b0};					// All D-PAD of 6-buttons gamepad is "released" after extra buttons
				endcase																									// A third-party gamepad can give there its extra buttons
			end
			2'b11: begin // Wrong iPADTYPE
				oGENPAD = 'x;
			end
		endcase
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
