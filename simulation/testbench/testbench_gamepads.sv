`timescale 1ns/1ns

module testbench_gamepads();

	logic				fpga_clk_50, nreset, dummy_clk;
	
	logic [15:0]	decode_error_count = '0, genpad_type_error_count = '0;

	logic				buttons_clk; // dummy_buttons press clock
	logic	[11:0]	dummy_buttons = '0, old_dummy_buttons; // {Z,Y,X,M,S,C/2,B/1,A,U,D,L,R}, MasterSystem PAD button 2 is used as C button, button 1 is used as B button
	logic	[5:0]		mode_buttons;
	logic	[1:0] 	pad_type = 'd0, old_pad_type;
	logic [2:0]		pad_type_clk_count = '0;
	logic				pad_hold_buttons = '0;

	wire				genpad_select;
	logic				old_genpad_select = '0;
	wire	[2:0]		pad6_state;

	wire	[1:0]		genpad_type_detected;
	logic	[1:0]		old_genpad_type_detected;

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
		.iCLK(dummy_clk),
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

		old_dummy_buttons <= dummy_buttons;

	end
	
	initial begin
			nreset <= 0; #44; nreset <= 1;
	end

////// generate clock to sequence tests
	always begin
		fpga_clk_50 <= 1; #10; fpga_clk_50 <= 0; #10;

	end

	always begin
		dummy_clk <= 1; #120; dummy_clk <= 0; #120;

	end

	always begin
		buttons_clk <= 1; #10400000; buttons_clk <=0; #10400000; // Button press latency 20.8 ms, see select_latency and full_dpad_wait in genesis_gamepad.v

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
	always @(genpad_type_detected) begin // checks of genpad_type_detected update
		case (pad_type)
			2'b00, 2'b01: begin // Master System or 3-buttons Genesis PAD
				if (genpad_type_detected !== pad_type) begin
					$display ("%t: Gamepad type detect ERROR! genpad_type_detected=%b is not equal to pad_type=%b", $time, genpad_type_detected, pad_type);
					genpad_type_error_count <= inc_overflow(genpad_type_error_count);
				end
			end
			2'b10: begin // 6-buttons Genesis PADs
				if (genpad_type_detected !== pad_type && old_genpad_type_detected !== 'x) begin
					case (genpad_type_detected)
						2'b00, 2'b11: begin
							$display ("%t: Gamepad type detect ERROR! genpad_type_detected changed from %b to %b at pad6_state=%b. It's not equal to pad_type=%b", $time, old_genpad_type_detected, genpad_type_detected, pad6_state, pad_type);
							genpad_type_error_count <= inc_overflow(genpad_type_error_count);
						end
						2'b01: begin
							if (old_genpad_type_detected == 2'b10) begin
								$display ("%t: Gamepad type detect ERROR! genpad_type_detected changed from %b to %b at pad6_state=%b. It's not equal to pad_type=%b", $time, old_genpad_type_detected, genpad_type_detected, pad6_state, pad_type);
								genpad_type_error_count <= inc_overflow(genpad_type_error_count);
							end
						end
					endcase
				end
			end
			default: begin
				$display ("Invalid pad_type=%b at genpad_type_detected update check! Simulation was stopped.", pad_type);
				$finish;
			end
		endcase

		old_genpad_type_detected <= genpad_type_detected;
	end

	always @(posedge fpga_clk_50) begin
		if (nreset) begin
			if (pad_type == 2'b10 && pad6_state == 3'd6)
				mode_buttons <= {dummy_buttons[6:5],dummy_buttons[11:8]};
		end
		else begin
			old_genpad_decoded <= genpad_decoded;
		end
		old_genpad_select <= genpad_select;
	end

	always @(dummy_buttons) begin
		if (old_dummy_buttons !== 'x) begin
			if (genpad_decoded !== old_dummy_buttons) begin // checks of stuck genpad_decoded
				decode_error_count <= inc_overflow(decode_error_count);
				$display ("%t: Gamepad decoding ERROR! New dummy_buttons arrived, but genpad_decoded=%b is not equal to old_dummy_buttons=%b", $time, genpad_decoded, old_dummy_buttons);
			end

			if (pad_type == old_pad_type) begin // If pad_type changes with dummy_buttons, then it's new test sequence; skip pad_type stuck checking
				if (genpad_type_detected !== pad_type) begin // checks of stuck genpad_type_detected
					$display ("%t: Gamepad type detecting stuck ERROR! New dummy_buttons arrived, but genpad_type_detected=%b was not changed to pad_type=%b", $time, genpad_type_detected, pad_type);
					genpad_type_error_count <= inc_overflow(genpad_type_error_count);
				end
			end
			else begin
				old_pad_type <= pad_type;
			end
		end

		old_dummy_buttons <= dummy_buttons;
	end

	// genpad_decoded checks
	always @(genpad_decoded) begin
			case (pad_type)
				2'b00: begin // Master System PAD
					if (genpad_decoded !== dummy_buttons) begin
						$display ("%t: Gamepad decoding ERROR! genpad_decoded=%b is not equal to dummy_buttons=%b", $time, genpad_decoded, dummy_buttons);
						decode_error_count <= inc_overflow(decode_error_count);
					end
				end
				2'b01: begin // 3-buttons Genesis PAD
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
/*					case (pad6_state - 1'd1) // Current genpad_decoded was generated for the previous pad6_state
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
								$display ("genpad_decoded{[6:5],[11:8]}=%b is not equal to mode_buttons=%b", {genpad_decoded[6:5],genpad_decoded[11:8]}, mode_buttons);
							end
							if (genpad_decoded[3:0] !== old_genpad_decoded[3:0]) begin
								$display ("genpad_decoded[3:0]=%b changed from %b.", genpad_decoded[3:0], old_genpad_decoded[3:0]);
							end
						end
						default: begin
							$display ("Invalid pad6_state %b at genpad_decoded check! Simulation was stopped.", pad6_state);
							$finish;
						end
					endcase */
				end
			endcase

			old_genpad_decoded <= genpad_decoded;
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
		output	logic	[2:0]		oPAD6B_STATE = '0
	);

	parameter [6:0] gpad_zyxm_latency_bottom = 7'h63, gpad_zyxm_latency_upper = 7'h7D; // original gamepads have latency 6'h79 or 6'h7B select ticks before ZYXM buttons set; clone gamepads have latency 6'h63 or 6'h65
	parameter [2:0] buttons3_S0 = 3'd0, buttons3_S1 = 3'd1, buttons3_S2 = 3'd2, buttons3_S3 = 3'd3, buttons3_S4 = 3'd4, all_dap = 3'd5, xyzm_buttons = 3'd6, thirdpart_buttons = 3'd7;

	bit   [6:0]    gpad_zyxm_latency;

	logic				old_select = '0;
	logic [16:0]	genpad6b_res_timer = '0;
	logic				genpad6b_timeout = '0;
	logic [6:0]		genpad6b_select_cnt = '0;

	initial
		gpad_zyxm_latency = $urandom_range(gpad_zyxm_latency_bottom, gpad_zyxm_latency_upper);

	always @(iSELECT) begin
		if (genpad6b_select_cnt < gpad_zyxm_latency) begin
			genpad6b_select_cnt <= genpad6b_select_cnt + 1'd1;
		end
		else
			if (~iSELECT) genpad6b_select_cnt <= 'd0;

		if (gpad_zyxm_latency <= gpad_zyxm_latency_upper)
			gpad_zyxm_latency <= gpad_zyxm_latency + $urandom_range(7'h0,7'h2); // gamepads have jitter ZYXM buttons latency in 2 select ticks
		else if (gpad_zyxm_latency > gpad_zyxm_latency_bottom)
					gpad_zyxm_latency <= gpad_zyxm_latency - $urandom_range(7'h0,7'h2); // gamepads have jitter ZYXM buttons latency in 2 select ticks

	end

	// Genesis PAD output
	logic [2:0] pad6b_next_state;

	always @(iSELECT or posedge genpad6b_timeout) begin
		if (~genpad6b_timeout && iN_RESET && iPADTYPE == 2'b10)
			oPAD6B_STATE <= pad6b_next_state;
		else
			oPAD6B_STATE <= '0;
	end

	always_comb begin
		case (oPAD6B_STATE)
			buttons3_S0: begin
				if (iSELECT) begin
					pad6b_next_state = buttons3_S2;
				end
				else
					pad6b_next_state = buttons3_S1;
			end

			buttons3_S1,buttons3_S2,buttons3_S3:
				pad6b_next_state = oPAD6B_STATE + 3'd1;

			buttons3_S4:
				if (iSELECT && genpad6b_select_cnt >= gpad_zyxm_latency) begin
					pad6b_next_state = oPAD6B_STATE + 3'd1;
				end
				else pad6b_next_state = buttons3_S4;

			all_dap,xyzm_buttons,thirdpart_buttons:
				pad6b_next_state = oPAD6B_STATE + 3'd1;

			default:
				pad6b_next_state = 'x;

		endcase;
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
					buttons3_S0, buttons3_S1, buttons3_S2, buttons3_S3, buttons3_S4:
						if (iSELECT)
							oGENPAD = ~{iBUTTONS[6:5],iBUTTONS[3:0]};
						else
							oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],iBUTTONS[3:2],1'b1,1'b1}; // START and A buttons set. It is impossible to press Left and Right at the same time, this is a 3-buttons PAD sign
					all_dap:
						if (~iSELECT) begin
							oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],1'b1,1'b1,1'b1,1'b1};					// All D-PAD is "pressed" before extra buttons
						end
						else oGENPAD = 'x;
					xyzm_buttons:
						if (iSELECT) begin
							oGENPAD = ~{iBUTTONS[6:5],iBUTTONS[11:8]};										// It's C, B and extra (MXYZ) buttons set
						end
						else oGENPAD = 'x;
					thirdpart_buttons:
						if (~iSELECT) begin
							oGENPAD = ~{iBUTTONS[7],iBUTTONS[4],1'b0,1'b0,1'b0,1'b0};					// All D-PAD of 6-buttons gamepad is "released" after extra buttons
						end																								// A third-party gamepad can give there its extra buttons
						else oGENPAD = 'x;
				endcase
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
