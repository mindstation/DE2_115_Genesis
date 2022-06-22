`timescale 1ns/1ns

module testbench_gamepads();

	logic				fpga_clk_50;
	logic [5:0]		decode_error_count = '0, genpad_type_error_count = '0;
	logic [2:0]		select_count = '0;
	
	logic	[11:0]	dummy_buttons = '0;
	logic	[1:0] 	pad_type = '0, old_pad_type;
	logic				pad_hold_buttons = '0;
	
	wire				genpad_select;
	bit				bit_genpad_select;
	wire	[1:0]		genpad_type_detected;
	wire	[5:0]		dummy_genpad;
	wire	[11:0]	genpad_decoded;
	
	// instatiate device to be tested
	genesis_gamepad dut (
		.iCLK(fpga_clk_50),
		
		.iGENPAD(dummy_genpad),
		
		.oGENPAD_TYPE(genpad_type_detected),
		.oGENPAD_SELECT(genpad_select),
		.oGENPAD_DECODED(genpad_decoded)
	);
	
	// Genesis gamepad dummy
	genpad_dummy genesis_pad (
		.iCLK(fpga_clk_50),

		.iPADTYPE(pad_type),
		.iSELECT(genpad_select),
		.iBUTTONS(dummy_buttons),

		.oGENPAD(dummy_genpad)
	);

////// initilize testbench
	initial begin
		$timeformat(-12, 0, " ns"); // Print simulation time in ns
		
		old_pad_type <= pad_type;
		
		if (pad_type === '0) // MasterSystem PAD
			$display ("pad_type is %b. MasterSystem PAD testing.", pad_type);
	end
	
////// generate clock to sequence tests
	always begin
			fpga_clk_50 <= 1; #10; fpga_clk_50 <= 0; #10;
		end

///// Press buttons
// ModelSim Intel FPGA Starter Edition 10.5b will skip else block if begin/end doesn't frame nested "if".
	always @(posedge fpga_clk_50) begin
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
				$display ("Invalid pad_type %b ! Simulation stopped.", pad_type);
				$finish;
			end
		endcase

		#18000000; // 18ms - is bigger than 60Hz VSync period, but less than 50Hz. Like button press at one frame
	end
		
////// results check
	always @(genpad_decoded) begin
		case (pad_type)
			2'b00: begin // Master System PAD
				if (genpad_decoded !== dummy_buttons) begin
					$display ("%t: Gamepad decoding ERROR! genpad_decoded=%b is not equal to dummy_buttons=%b", $time, genpad_decoded, dummy_buttons);
					decode_error_count <= decode_error_count + 1'd1;
				end
			end
			2'b01: begin // 3-buttons Genesis PAD
				if (~genpad_select) begin // used previous genpad_select, because genpad_decoded shows previous dummy_buttons state
					if ({genpad_decoded[6:5],genpad_decoded[3:0]} !== {dummy_buttons[6:5],dummy_buttons[3:0]}) begin
						$display ("%t: Gamepad decoding ERROR! genpad_decoded{[6:5],[3:0]}=%b is not equal to dummy_buttons{[6:5],[3:0]}=%b after genpad_select=%b", $time, genpad_decoded, dummy_buttons, ~genpad_select);
						decode_error_count <= decode_error_count + 1'd1;
					end
				end
				else begin
					if ({genpad_decoded[7],genpad_decoded[4],genpad_decoded[3:2]} !== {dummy_buttons[7],dummy_buttons[4],dummy_buttons[3:2]}) begin
						$display ("%t: Gamepad decoding ERROR! genpad_decoded{[7],[4],[3:2]}=%b is not equal to dummy_buttons{[7],[4],[3:2]}=%b after genpad_select=%b", $time, genpad_decoded, dummy_buttons, ~genpad_select);
						decode_error_count <= decode_error_count + 1'd1;
					end
				end
			end
			2'b10: begin // 6-buttons Genesis PAD
				//UNDER CONSTRUCTION
			end
		endcase
		
	end	

	assign bit_genpad_select = genpad_select;
	always @(bit_genpad_select) begin
		if (old_pad_type == pad_type) begin
			select_count <= select_count + 1'd1;

			if (select_count == 3'd5 && genpad_type_detected !== pad_type) begin // Fifth select is time for detecting PAD type (see genesis_gamepad module)
				$display ("%t: Gamepad type detect ERROR! genpad_type_detected=%b is not equal to pad_type=%b", $time, genpad_type_detected, pad_type);
				genpad_type_error_count <= genpad_type_error_count + 1'd1;
			end
		end
		else begin
			old_pad_type <= pad_type;
			select_count <= '0;
		end

	end

endmodule:testbench_gamepads

/////////////////////////  Genesis gamepad dummy  //////////////////////////////////
module genpad_dummy(
		input							iCLK,		// 50MHz

		input				[1:0]		iPADTYPE,
		input			 				iSELECT,
		input 			[11:0]	iBUTTONS = '0, // {Z,Y,X,M,S,C/2,B/1,A,U,D,L,R}, MasterSystem PAD button 2 is used as C button, button 1 is used as B button
		
		output			[5:0]		oGENPAD // {C/Start, B/A, Up/Z, Down/Y, Left/X, Right/Mode}
	);

	logic	[5:0]		genpad_out = '0;
	
	logic	[2:0]		genpad6b_state = '0;
	logic [16:0]	genpad6b_res_timer = '0;
	logic				genpad6b_timeout = '0;
	
	assign oGENPAD = iPADTYPE[1] ? (iPADTYPE[0] ? 'x : genpad_out) : (iPADTYPE[0] ? genpad_out : ~{iBUTTONS[6:5],iBUTTONS[3:0]}); // Out Genesis (genpad_out) or Master System PAD

	// Genesis PAD output
	always @(iBUTTONS or iSELECT or posedge genpad6b_timeout) begin
		if (genpad6b_timeout)
			genpad6b_state <= '0;
		else
			genpad6b_state <= genpad6b_state + 1'd1;
	
		case(iPADTYPE)
			2'b01: begin // 3-buttons Genesis PAD
				if (iSELECT)
					genpad_out <= ~{iBUTTONS[6:5],iBUTTONS[3:0]};
				else
					genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; // It is impossible to press Left and Right at the same time, this is a 3-buttons PAD sign
			end
			2'b10: begin // 6-buttons Genesis PAD
				if (iSELECT)
					case(genpad6b_state)
						3'b000, 3'b010, 3'b100:
							genpad_out <= ~{iBUTTONS[6:5],iBUTTONS[3:0]};
						3'b110:
							genpad_out <= ~{1'b0,1'b0,iBUTTONS[11:8]}; // START and A released - it's extra (MXYZ) buttons set sign
					endcase
				else
					case(genpad6b_state)
						3'b001, 3'b011:
							genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; 			// START and A buttons set
						3'b101:
							genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],1'b1,1'b1,1'b1,1'b1};					// All D-PAD is "pressed" before extra buttons
						3'b111:
							genpad_out <= ~{iBUTTONS[7],iBUTTONS[4],1'b0,1'b0,1'b0,1'b0};					// All D-PAD of 6-buttons gamepad is "released" after extra buttons
					endcase																									// A third-party gamepad can give there its extra buttons
			end
		endcase

	end
	
///// Genesis 6-buttons PAD - extra buttons timeout
	
	// Reset timeout counter every posedge iSELECT
	always @(posedge iSELECT)
		genpad6b_res_timer <= '0;
	
	// iSELECT timeout counter
	always @(posedge iCLK) begin // 1 / 50 MHz = 20ns
		genpad6b_res_timer <= genpad6b_res_timer + 1'd1;
		
		if (genpad6b_res_timer == 17'd75000) begin // 75000 * 20ns = 1,5 ms extra buttons timeout
			genpad6b_timeout <= '1;
			genpad6b_res_timer <= '0;
		end
		else
			genpad6b_timeout <= '0;
	end
	
endmodule:genpad_dummy
