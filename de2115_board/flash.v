module flash
(
	input               iclk,
	input               ireset,
	
	input  		 [7:0]  iFL_DQ,
	output reg [22:0] oFL_ADDR,	
	output reg	     oFL_RST_N,
	output reg	     oFL_CE_N,
	output reg	     oFL_OE_N,
	output			     oFL_WE_N,
	output			     oFL_WP_N, // write protection is disabled forever (set to 1)
	
	input        [22:0] ifl_addr,
	output reg [15:0] ofl_dout,
	input               ifl_req,
	output reg        ofl_ack
);

// 54MHz iclk flash latencies in cycles
localparam	RESET_LATENCY = 6'd28,// ~500ns
				INIT_LATENCY  = 6'd3, // ~50ns
				READ_LATENCY  = 6'd6; // ~110ns

// Flash FSM states
localparam	RESET = 6'd0,
				INIT = RESET + RESET_LATENCY,
				IDLE = INIT + INIT_LATENCY,
				ACTIVE = IDLE + 6'd1,
				READ_BYTE = ACTIVE + READ_LATENCY,
				NEXT_BYTE_ADDR = READ_BYTE + 6'd1,
				NEXT_BYTE = NEXT_BYTE_ADDR + READ_LATENCY;
				
reg [5:0]  fsm_state;
reg [7:0]  fstbyte;

assign oFL_WP_N = 1'b1;
assign oFL_WE_N = 1'b1;

always @(posedge iclk)
	begin
		if (ireset)
			fsm_state <= RESET;
		else
			begin
				case(fsm_state)
					RESET:
						begin
							oFL_ADDR <= 23'b0;
							fstbyte <= 8'b0;
							oFL_RST_N <= 1'b0;
							ofl_ack <= ifl_req;
						end
					INIT:
						oFL_RST_N <= 1'b1;
					IDLE:
						if (ifl_req != ofl_ack)
							fsm_state <= ACTIVE;
					ACTIVE:
						begin
							oFL_CE_N <= 1'b0;
							oFL_OE_N <= 1'b0;
							oFL_ADDR <= ifl_addr;
						end
					READ_BYTE:
						fstbyte <= iFL_DQ;
					NEXT_BYTE_ADDR:
						oFL_ADDR <= oFL_ADDR + 6'd1;
					NEXT_BYTE:
						begin
							ofl_dout <= {fstbyte, iFL_DQ}; // Flash data word
							ofl_ack <= ifl_req;
							fsm_state <= IDLE;
						end					
				endcase
				if (fsm_state != IDLE && fsm_state != NEXT_BYTE)
					fsm_state <= fsm_state + 6'd1;
			end
	end

endmodule
