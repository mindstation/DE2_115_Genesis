module rom_loader
(
	input               iclk,
	input               ireset,

	output reg		  oloading,
	
// SDRAM	
	input               iram_ack,
	output		 [24:1] oram_addr,
	output reg [15:0] oram_wrdata,
	output reg        oram_req,
	output reg        oram_Wrl, oram_Wrh,

//Flash
	output 		 [23:1] ofl_addr,
	input			 [15:0] ifl_data,
	output reg        ofl_req,
	input					  ifl_ack
);

localparam FL_SIZE		= 23'b1111111_11111111_11111110; // DE2-115 has 8MB Flash, word aligned address

localparam INIT			= 3'd0,
			  FL_READ		= 3'd1,
			  FL_ACK_WAIT	= 3'd2,
			  RAM_WRITE		= 3'd3,
			  RAM_ACK_WAIT	= 3'd4,
			  ADDR_INC		= 3'd5,
			  STOP			= 3'd6;

reg [2:0]  fsm_state;
reg [23:1] fl_addr_counter;
reg [24:1] ram_addr_counter;

// oram_addr[24:23] is a bank number, oram_addr[13:1] is a row number, oram_addr[22:14] is a column number
assign oram_addr = ram_addr_counter;
assign ofl_addr = fl_addr_counter;

always @(posedge iclk)
	begin
		if (ireset)
				fsm_state <= INIT;
		else
			case (fsm_state)
				INIT:
					begin
						fl_addr_counter <= 23'd0;
						ram_addr_counter <= 24'd0;
						oloading <= 1'b1;
						// If oWrl or oWrh is 1, then write SDRAM
						{oram_Wrl,oram_Wrh} <= 2'b11;
						
						fsm_state <= FL_READ;
					end
				FL_READ:
					begin						
						ofl_req <= ~ifl_ack;
						fsm_state <= FL_ACK_WAIT;
					end
				FL_ACK_WAIT:
					if (ofl_req == ifl_ack)
						fsm_state <= RAM_WRITE;
				RAM_WRITE:
					begin
						oram_wrdata <= ifl_data;
						oram_req <= ~iram_ack;
						fsm_state <= RAM_ACK_WAIT;
					end
				RAM_ACK_WAIT:
					if (oram_req == iram_ack)
						fsm_state <= ADDR_INC;
				ADDR_INC:
					if (fl_addr_counter < FL_SIZE)
						begin
							fl_addr_counter <= fl_addr_counter + 23'd2;
							ram_addr_counter <= ram_addr_counter + 24'd1;
							fsm_state <= FL_READ;
						end
					else
						fsm_state <= STOP;
				STOP:
					begin
						{oram_Wrl,oram_Wrh} <= 2'b00;
						oloading <= 1'b0;
					end
				default:
					fsm_state <= INIT;
			endcase;
	end
endmodule
