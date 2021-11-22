//============================================================================
//
//  DE2-115 rom_loader controller for copying ROM from Flash to SDRAM
//  (c)2020-2021 Alexander Kirichenko
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

module rom_loader
(
	input               iclk,
	input               ireset,

	output reg		  oloading = 1'b0,
	
// SDRAM
	input  	         irom_load_wait,
	output reg			orom_load_wr = 1'b0,
	output	  [24:0] oram_addr, //sdram uses only 24-bit address: [24:1]
	output reg [15:0] oram_wrdata,


//Flash
	output 		 [22:0] ofl_addr,
	input			 [15:0] ifl_data,
	output reg			  ofl_req = 1'b0,
	input  				  ifl_ack
);

localparam INIT					= 3'b000,
			  FL_READ				= 3'b001,
			  FL_ACK_WAIT			= 3'b010,
			  RAM_WRITE_READY		= 3'b011,
			  RAM_WRITE				= 3'b100,
			  RAM_WRITE_WAIT		= 3'b101,
			  ADDR_INC				= 3'b110,
			  STOP					= 3'b111;

reg [2:0]  fsm_state;
reg [24:0] addr_counter;
reg [31:0] rom_max_addres;
reg [63:0] cart_id;

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
						rom_max_addres <= 32'h200; // ROM header max address, it will be changed to actual ROM max address at loading
						oloading <= 1'b1;
						
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
					begin
						if(addr_counter == 'h182) cart_id[63:56] <= ifl_data[15:8];
						if(addr_counter == 'h184) cart_id[55:40] <= {ifl_data[7:0],ifl_data[15:8]};
						if(addr_counter == 'h186) cart_id[39:24] <= {ifl_data[7:0],ifl_data[15:8]};
						if(addr_counter == 'h188) cart_id[23:08] <= {ifl_data[7:0],ifl_data[15:8]};
						if(addr_counter == 'h18A) cart_id[07:00] <= ifl_data[7:0];
						if((addr_counter == 'h18C) && (cart_id == "T-12056 ")) rom_max_addres   <= 32'h4FFFFF; // SUPER STREET FIGHTER2 New Challengers
						
						if (cart_id != "T-12056 ")
							begin
								if (addr_counter == 25'h1A4)
									rom_max_addres[31:16] <= {ifl_data[7:0],ifl_data[15:8]}; // Take max ROM address from the header
								if (addr_counter == 25'h1A6)
									rom_max_addres[15:0] <= {ifl_data[7:0],ifl_data[15:8]};  // Take max ROM address from the header
							end
					
						if (addr_counter < rom_max_addres[24:0])
							begin
								addr_counter <= addr_counter + 25'd2;
								fsm_state <= FL_READ;
							end
						else
							fsm_state <= STOP;
					end
				STOP:
					oloading <= 1'b0;
				default:
					fsm_state <= INIT;
			endcase
	end
endmodule
