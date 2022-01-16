`timescale 1ns/1ps

module testbench_romloader();

	logic 			clk_sys, clk_ram;
	logic				reset;

	logic				write_count_error = 0;
	
	wire	[24:0]	loadrom_addr;
	wire	[15:0]	loadrom_wdata;
	wire				rom_loading, orom_load_wr;
	logic				rom_load_wait = 0;
	
	wire	[23:1]	fl_ctrl_addr;
	wire	[15:0]	fl_ctrl_data;
	wire				fl_ctrl_req, fl_ctrl_ack;
	
	wire	[15:0]	dram_data_dbg;
	wire				dram_clk, dram_cke, dram_we_n;
	wire				dram_ncs, dram_nras, dram_ncas;
	wire	[12:0]	dram_addr;
	tri	[15:0]	dram_dq;
	wire	 [1:0]	dram_ba;
	wire	 [1:0]	dram_dqm;
	
	logic				sdram_init_n;
	
	wire	 [7:0]	fl_dq;
	wire	[22:0]	fl_addr;
	wire				fl_rst_n, fl_ce_n, fl_oe_n, fl_we_n, fl_wp_n;
	
	wire				cart_download;	
	logic				old_download = 0, old_reset = 0;
	wire				sdrom_wrack;
	logic				old_sdrom_wrack = 0;
	logic				rom_wr = 0, old_rom_wr = 0;
	logic	[24:0]	rom_sz;
	
	//Make 'diff SDRAMdata.hex mt48lc4m16a2_data.hex' for RAM write checking
	//Compare SDRAMdata.hex or mt48lc4m16a2_data.hex with ROM.hex for rom_loader work checking
	//See ROM.hex path in the flash_dummy module
	string SDRAMdata_out_path = "/home/DE2_115_Genesis/simulation/testbench/SDRAMdata.hex";
	string mt48lc4m16a2_data_path = "/home/DE2_115_Genesis/simulation/testbench/mt48lc4m16a2_data.hex";	
	
	//instatiate device to be tested
	rom_loader dut(
		.iclk(clk_sys), .ireset(reset),
	
		.oloading(rom_loading),
		// SDRAM
		.irom_load_wait(rom_load_wait), .orom_load_wr(orom_load_wr), .oram_addr(loadrom_addr), .oram_wrdata(loadrom_wdata),
		//Flash
		.ofl_addr(fl_ctrl_addr), .ifl_data(fl_ctrl_data), .ofl_req(fl_ctrl_req), .ifl_ack(fl_ctrl_ack)
	);
	
	sdram sdramCtrl(
		.clk(clk_ram), .init(~sdram_init_n),
	
		.addr0(loadrom_addr[24:1]), .wrl0(1'b1), .wrh0(1'b1), .din0({loadrom_wdata[7:0],loadrom_wdata[15:8]}), .dout0(),
		.req0(rom_wr), .ack0(sdrom_wrack),
	
		.SDRAM_CLK(dram_clk), .SDRAM_CKE(dram_cke),
		.SDRAM_nCS(dram_ncs), .SDRAM_nCAS(dram_ncas), .SDRAM_nRAS(dram_nras),
		.SDRAM_nWE(dram_we_n),
		.SDRAM_A(dram_addr), .SDRAM_BA(dram_ba), .SDRAM_DQ(dram_dq),
		.SDRAM_DQML(dram_dqm[0]), .SDRAM_DQMH(dram_dqm[1])
	);	
	
	flash flashCtrl(
		.iclk(clk_sys),
	
		.ifl_addr(fl_ctrl_addr), .ofl_dout(fl_ctrl_data), .ifl_req(fl_ctrl_req), .ofl_ack(fl_ctrl_ack),
		.iFL_DQ(fl_dq), .oFL_ADDR(fl_addr), .oFL_RST_N(fl_rst_n), .oFL_CE_N(fl_ce_n), .oFL_OE_N(fl_oe_n), .oFL_WE_N(fl_we_n), .oFL_WP_N(fl_wp_n)
	);
	
	mt48lc4m16a2 sdramDevice(
	.Dq_wr_dbg(dram_data_dbg),
	.Dq(dram_dq), .Addr(dram_addr), .Ba(dram_ba),
	.Clk(dram_clk), .Cke(dram_cke),
	.Cs_n(dram_ncs), .Ras_n(dram_nras), .Cas_n(dram_ncas), .We_n(dram_we_n),
	.Dqm(dram_dqm)
	);
	
	flash_dummy flashDevice(
		.oFL_DQ(fl_dq), .iFL_ADDR(fl_addr), .iFL_RST_N(fl_rst_n), .iFL_CE_N(fl_ce_n), .iFL_OE_N(fl_oe_n), .iFL_WE_N(fl_we_n), .iFL_WP_N(fl_wp_n)
	);	
	
	assign cart_download = rom_loading;
	always @(posedge clk_sys)
		begin
			old_download <= cart_download;
			old_reset <= reset;

			if(~old_reset && reset) rom_load_wait <= 0;
			if (old_download & ~cart_download) rom_sz <= loadrom_addr[24:0];

			if (cart_download & orom_load_wr)
				begin
					rom_load_wait <= 1;
					rom_wr <= ~rom_wr;
				end
				else if(rom_load_wait && (rom_wr == sdrom_wrack))
							begin
								rom_load_wait <= 0;
							end
		end
	
	//initilize testbench
	int fileSDRAMdata_out;
	int mt48lc4m16a2_data;
	initial
		begin
			fileSDRAMdata_out = $fopen (SDRAMdata_out_path, "w");
			if (fileSDRAMdata_out == 0)
				begin
					$display ("Open SDRAMdata.hex ERROR!");
					$finish;
				end
			mt48lc4m16a2_data = $fopen (mt48lc4m16a2_data_path, "w");
			if (mt48lc4m16a2_data == 0)
				begin
					$display ("Open mt48lc4m16a2_data.hex ERROR!");
					$finish;
				end

			sdram_init_n <= 0; #22; sdram_init_n <= 1;
		end	
	initial
		begin
			reset <= 1; #44; reset <= 0;
		end
	
	//generate clock to sequence tests
	always
		begin
			clk_sys <= 1; #10; clk_sys <= 0; #10;
		end
		
	always
		begin
			clk_ram <= 1; #5; clk_ram <= 0; #5;
		end
	
	//check results
	always @(negedge clk_sys)
		begin
			if(rom_wr !== old_rom_wr)
				begin
					old_rom_wr <= rom_wr;
					//write SDRAM output of rom_loader
					$fdisplay(fileSDRAMdata_out, "%h", loadrom_wdata[7:0]);
					$fdisplay(fileSDRAMdata_out, "%h", loadrom_wdata[15:8]);
					
					//check ROM data input-output of rom_loader
					if (loadrom_wdata !== fl_ctrl_data)
						begin
							write_count_error = write_count_error + 1;
							$display ("ERROR! Flash word at %h address is %h and rom_loader word is %h. They are different!", fl_addr, fl_ctrl_data, loadrom_wdata);
						end
				end

			if ((fl_addr + 1) == rom_sz[22:0])
				begin
					$display ("All %d ROM bytes was readed from flash with %d errors.", rom_sz, write_count_error);
					$finish;
				end
			
			if (fl_addr > rom_sz[22:0])				
				begin
					$display ("ERROR! fl_addr %d is out of ROM.", fl_addr);
					$finish;
				end
				
			
		end
		
	//write RAM content
	always @(negedge dram_clk)
		begin
			if (old_sdrom_wrack !== sdrom_wrack)
				begin
					old_sdrom_wrack <= sdrom_wrack;
					$fdisplay(mt48lc4m16a2_data, "%h", dram_data_dbg[15:8]);
					$fdisplay(mt48lc4m16a2_data, "%h", dram_data_dbg[7:0]);

					if ({dram_data_dbg[7:0], dram_data_dbg[15:8]} !== fl_ctrl_data)
						begin
							write_count_error = write_count_error + 1;
							$display ("ERROR! Flash word at %h address is %h and SDRAM word is %h. They are different!", fl_addr, fl_ctrl_data, {dram_data_dbg[7:0], dram_data_dbg[15:8]});
						end
				end
		end
		
	//ROM loading must be completed at 2 seconds
	always @(negedge clk_sys)
		begin
			#(64'd2000000000);
			$fclose (fileSDRAMdata_out); $fclose (mt48lc4m16a2_data);
			$display ("Testbench time out! It's working 2 seconds.");
			$finish;
		end

endmodule

module flash_dummy (
		output logic	[7:0] oFL_DQ,
		input			  [22:0] iFL_ADDR,
		input 					iFL_RST_N, 
		input						iFL_CE_N, iFL_OE_N,
		input						iFL_WE_N, iFL_WP_N
	);
	
	logic 		latency_n = 0;
	logic [7:0]	ROM[8388608:0];

	//Convert bin to hex under linux by
	//hexdump -v -e '1/1 "%02x\n"' "ROM.bin" > "ROM.hex"
	string ROM_path = "/home/DE2_115_Genesis/simulation/testbench/ROM.hex";
	
	initial
		$readmemh(ROM_path, ROM);
	
	always @(negedge iFL_RST_N)
		begin
			latency_n <= 1; #500; latency_n <= 0;
		end
	always @(posedge iFL_RST_N)
		begin
			latency_n <= 1; #50; latency_n <= 0;
		end
		
	always @(negedge iFL_CE_N or iFL_ADDR)
		begin
			latency_n <= 1; #90; latency_n <= 0;
		end
		
	always @(negedge iFL_OE_N)
		begin
			latency_n <= 1; #25; latency_n <= 0;
		end
	
	always @(negedge latency_n)
		if (~latency_n & iFL_RST_N & ~iFL_CE_N & ~iFL_OE_N & iFL_WE_N)
				oFL_DQ <= ROM[iFL_ADDR];
	
endmodule	
