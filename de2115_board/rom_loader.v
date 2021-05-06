module rom_loader
(
	input               iclk,
	input               ireset,

	output reg		  oloading,
	
// SDRAM	
	input             irom_load_wait,
	output reg			orom_load_wr,
	output reg        oram_Wrl, oram_Wrh,
	output	  [24:0] oram_addr, //sdram uses only 24-bit address: [24:1]
	output reg [15:0] oram_wrdata,
	

//Flash
	output 		 [22:0] ofl_addr,
	input			 [15:0] ifl_data,
	output reg			  ofl_req,
	input					  ifl_ack
);

localparam FL_SIZE		= 23'b1111111_11111111_11111110; // DE2-115 has 8MB Flash, word aligned address

localparam INIT					= 3'd0,
			  FL_READ				= 3'd1,
			  FL_ACK_WAIT			= 3'd2,
			  RAM_WRITE_READY		= 3'd3,
			  RAM_WRITE				= 3'd4,
			  RAM_WRITE_WAIT		= 3'd5,
			  ADDR_INC				= 3'd6,
			  STOP					= 3'd7;

reg [2:0]  fsm_state;
reg [24:0] addr_counter;

// oram_addr[24:23] is a bank number, oram_addr[13:1] is a row number, oram_addr[22:14] is a column number
assign oram_addr = addr_counter;
assign ofl_addr = addr_counter[22:0];

always @(posedge iclk)
	begin
		if (ireset)
				fsm_state <= INIT;
		else
			case (fsm_state)
				INIT:
					begin
						addr_counter <= 25'd0;
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
						fsm_state <= RAM_WRITE_READY;
				RAM_WRITE_READY:
					begin
						oram_wrdata <= ifl_data;
						orom_load_wr <= 1'b1;
						fsm_state <= RAM_WRITE;
					end
				RAM_WRITE:
					begin
						orom_load_wr <= 1'b0;
						fsm_state <= RAM_WRITE_WAIT;
					end
				RAM_WRITE_WAIT:
					if (irom_load_wait == 1'b0)
							fsm_state <= ADDR_INC;
				ADDR_INC:
					if (addr_counter < FL_SIZE)
						begin
							addr_counter <= addr_counter + 25'd2;
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
