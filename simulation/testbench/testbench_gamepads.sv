`timescale 1ns/1ps

module testbench_gamepads();

	logic				fpga_clk_50;
	logic [5:0]		decode_error_count = '0;
	
	logic	[1:0] 	pad_type = '0;
	logic				pad_hold_buttons = '0;
	
	wire				genpad_select;
	wire	[5:0]		dummy_genpad;
	wire	[11:0]	dummy_buttons, genpad_decoded;
	
	// instatiate device to be tested
	genesis_gamepad dut (
		.iCLK(fpga_clk_50),
		
		.iGENPAD(dummy_genpad),
		
		.oGENPAD_SELECT(genpad_select),
		.oGENPAD_DECODED(genpad_decoded)
	);
	
	// Genesis gamepad dummy
	genpad_dummy genesis_pad (
		.iCLK(fpga_clk_50),
		
		.iPADTYPE(pad_type),
		.iHOLD_BUTTONS(pad_hold_buttons),
		.iSELECT(genpad_select),
		
		.oGENPAD(dummy_genpad),
		.oBUTTONS(dummy_buttons)
	);

////// initilize testbench
	initial begin
	
	end
	
////// generate clock to sequence tests
	always begin
			fpga_clk_50 <= 1; #10; fpga_clk_50 <= 0; #10;
		end

////// results check
	always @(negedge fpga_clk_50) begin
		if ((~pad_hold_buttons && dummy_buttons[12] === '1) || dummy_buttons === '1) begin
			pad_hold_buttons <= ~pad_hold_buttons;
			if (pad_hold_buttons) begin // PAD type tests was completed with and without hold buttons
				pad_type <= pad_type + '1;
				case (pad_type)
					2'b01: // 3-buttons Genesis PAD
						$display ("pad_type is %b. Genesis 3-buttons PAD testing.", pad_type);
					2'b10: // 6-buttons Genesis PAD
						$display ("pad_type is %b. Genesis 6-buttons PAD testing.", pad_type);
					default: // MasterSystem PAD
						$display ("pad_type is %b. MasterSystem PAD testing.", pad_type);
				endcase
			end
		end

		if (genpad_decoded !== dummy_buttons) begin
			$display ("Gamepad decoding ERROR! genpad_decoded=%b is not equal to dummy_buttons=%b", genpad_decoded, dummy_buttons);
			decode_error_count <= decode_error_count + '1;
		end

		if (pad_type === '3) begin
			$display ("All PAD type tests are complited with %d errors.", decode_error_count);
			$finish;
		end
	end
		
endmodule:testbench_gamepads

/////////////////////////  Genesis gamepad dummy  //////////////////////////////////
module genpad_dummy(
		input					iCLK,

		input		[1:0]		iPADTYPE,
		input					iHOLD_BUTTONS,
		input 				iSELECT,
		
		output	[5:0]		oGENPAD, // {C/Start, B/A, Up/Z, Down/Y, Left/X, Right/Mode}
		output	[11:0]	oBUTTONS // {Z,Y,X,M,S,C,B,A,U,D,L,R}
	);

	logic [11:0]	buttons = '0;
	logic	[5:0]		genpad_out,
	
	logic	[2:0]		genpad6b_state = '0;
	logic [16:0]	genpad6b_res_timer = '0;
	logic				genpad6b_timeout = 0';
	logic				old_select;
	
	assign oGENPAD = genpad_out;
	assign oBUTTONS = buttons;
	
	// press buttons
	always @(posedge iCLK) begin
		if	(iHOLD_BUTTONS)
			buttons <= buttons + '1;
		else
			if (buttons)
				buttons <= buttons << '1;
			else
				buttons <= 12'b000000000001; 
		#18000000; // 18ms - is bigger than 60Hz VSync period, but less than 50Hz. Like button press at one frame.
	end
	
	// Genesis PAD output
	always @(iSELECT or posedge genpad6b_timeout) begin
		if (genpad6b_timeout)
			genpad6b_state <= '0;
		else
			genpad6b_state <= genpad6b_state + '1;
	
		case(iPADTYPE)
			2'b01: begin // 3-buttons Genesis PAD
				if (iSELECT)
					genpad_out <= ~{buttons[6],buttons[5],buttons[3],buttons[2],buttons[1],buttons[0]};
				else
					genpad_out <= ~{buttons[7],buttons[4],buttons[3],buttons[2],1'b1,1'b1}; // It is not possible to press Left and Right at the same time, this is a 3-buttons PAD sign.
			end
			2'b10: begin // 6-buttons Genesis PAD
				if (iSELECT)
					case(genpad6b_state)
						3'b000, 3'b010, 3'b100:
							genpad_out <= ~{buttons[6],buttons[5],buttons[3],buttons[2],buttons[1],buttons[0]};
						3'b110:
							genpad_out <= ~{1'b0,1'b0,buttons[8],buttons[9],buttons[10],buttons[11]}; // START and A released - it's extra (MXYZ) buttons set sign.
				else
					case(genpad6b_state)
						3'b001, 3'b011:
							genpad_out <= ~{buttons[7],buttons[4],buttons[3],buttons[2],1'b1,1'b1}; // START and A buttons set
						3'b101:
							genpad_out <= ~{buttons[7],buttons[4],1'b1,1'b1,1'b1,1'b1};					// All D-PAD is "pressed" before extra buttons
						3'b111:
							genpad_out <= ~{buttons[7],buttons[4],1'b0,1'b0,1'b0,1'b0};					// All D-PAD of 6-buttons gamepad is "released" after extra buttons
																															// A third-party gamepad can give there its extra buttons
			end
			default: // MasterSystem PAD
				// (oGENPAD B is Button 1, oGENPAD C is Button 2)
				genpad_out <= ~{buttons[6],buttons[5],buttons[3],buttons[2],buttons[1],buttons[0]};
		endcase
	end
	
	// Genesis 6-buttons PAD - extra buttons timeout
	always @(posedge iCLK) begin // 1 / 50 MHz = 20ns
		if (iSELECT === old_select)
			genpad6b_res_timer <= genpad6b_res_timer + '1;
		else begin
			old_select <= iSELECT;
			genpad6b_res_timer <= '0;
			genpad6b_timeout <= '0;
		end
		
		if (genpad6b_res_timer == 17'd75000) begin // 75000 * 20ns = 1,5 ms extra buttons timeout
			genpad6b_timeout <= '1;
			genpad6b_res_timer <= '0;
		end
	end
	
endmodule:genpad_dummy
