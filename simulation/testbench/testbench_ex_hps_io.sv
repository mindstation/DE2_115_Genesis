`timescale 1ns/1ps

module testbench_ex_hps_io();

	logic			fpga_clk_50, clk_ram;
	logic				reset;

	logic				write_count_error = '0;

	wire				ioctl_download;
	wire	[7:0]		ioctl_index;
	wire				ioctl_wr;
	wire [24:0]		ioctl_addr;
	wire [15:0]		ioctl_data;
	logic				ioctl_wait;	
	
	wire				dram_clk, dram_cke, dram_we_n;
	wire				dram_ncs, dram_nras, dram_ncas;
	wire	[12:0]	dram_addr;
	tri	[15:0]	dram_dq;
	wire	 [1:0]	dram_ba;
	wire	 [1:0]	dram_dqm;
	
	logic				sdram_init_n;
	wire				sdrom_wrack;
	
	wire	 [7:0]	fl_dq;
	wire	[22:0]	fl_addr;
	wire				fl_rst_n, fl_ce_n, fl_oe_n, fl_we_n, fl_wp_n;
	logic	[15:0]	fl_ctrl_data;
	logic	[22:0]	old_fl_addr;
	
	wire				cart_download;	
	logic				old_download = '0, old_reset = '0;
	logic				rom_wr = '0, old_rom_wr = '0;
	logic	[24:0]	rom_sz;
	
	//instatiate device to be tested
	ex_hps_io #(.WIDE(1)) dut
	(
		.clk_sys(fpga_clk_50),
		.HPS_BUS({fl_dq,fl_addr,fl_rst_n,fl_ce_n,fl_oe_n,fl_we_n,fl_wp_n}),

		.forced_scandoubler(),
		.status(),

		.ioctl_download(ioctl_download),
		.ioctl_index(ioctl_index),
		.ioctl_wr(ioctl_wr),
		.ioctl_addr(ioctl_addr),
		.ioctl_dout(ioctl_data),
		.ioctl_wait(ioctl_wait)
	);
	
	sdram sdramCtrl(
		.clk(clk_ram), .init(~sdram_init_n),
	
		.addr0(ioctl_addr[24:1]), .wrl0(1'b1), .wrh0(1'b1), .din0({ioctl_data[7:0],ioctl_data[15:8]}), .dout0(),
		.req0(rom_wr), .ack0(sdrom_wrack),
	
		.SDRAM_CLK(dram_clk), .SDRAM_CKE(dram_cke),
		.SDRAM_nCS(dram_ncs), .SDRAM_nCAS(dram_ncas), .SDRAM_nRAS(dram_nras),
		.SDRAM_nWE(dram_we_n),
		.SDRAM_A(dram_addr), .SDRAM_BA(dram_ba), .SDRAM_DQ(dram_dq),
		.SDRAM_DQML(dram_dqm[0]), .SDRAM_DQMH(dram_dqm[1])
	);
	
	mt48lc4m16a2 sdramDevice(
	.Dq(dram_dq), .Addr(dram_addr), .Ba(dram_ba),
	.Clk(dram_clk), .Cke(dram_cke),
	.Cs_n(dram_ncs), .Ras_n(dram_nras), .Cas_n(dram_ncas), .We_n(dram_we_n),
	.Dqm(dram_dqm)
	);
	
	flash_dummy flashDevice(
		.oFL_DQ(fl_dq), .iFL_ADDR(fl_addr), .iFL_RST_N(fl_rst_n), .iFL_CE_N(fl_ce_n), .iFL_OE_N(fl_oe_n), .iFL_WE_N(fl_we_n), .iFL_WP_N(fl_wp_n)
	);
	
	assign cart_download = ioctl_download;
	always @(posedge fpga_clk_50)
		begin
			old_download <= cart_download;
			old_reset <= reset;

			if(~old_reset && reset) ioctl_wait <= 0;
			if (old_download & ~cart_download) rom_sz <= ioctl_addr[24:0];

			if (cart_download & ioctl_wr)
				begin
					ioctl_wait <= 1;
					rom_wr <= ~rom_wr;
				end
				else if(ioctl_wait && (rom_wr == sdrom_wrack))
							begin
								ioctl_wait <= 0;
							end
		end
	
//////initialize testbench
	initial
		begin
			reset <= 1; #44; reset <= 0;
		end

	initial
		begin
			sdram_init_n <= 0; #22; sdram_init_n <= 1;
		end

//////generate clock to sequence tests
	always
		begin
			fpga_clk_50 <= 1; #10; fpga_clk_50 <= 0; #10;
		end
		
	always
		begin
			clk_ram <= 1; #5; clk_ram <= 0; #5;
		end
	
//////results check
	always @(negedge fpga_clk_50)
		begin
			if (old_fl_addr !== fl_addr)
				begin		   
					if (~(fl_ce_n && fl_oe_n))
						begin
							old_fl_addr <= fl_addr;

							#110; //flash read latency
							if (fl_addr[0] == 1'b1)
								fl_ctrl_data[15:8] <= fl_dq;
							else
								fl_ctrl_data[7:0] <= fl_dq;
						end
				end
		end
		
	always @(negedge fpga_clk_50)
		begin
			if(rom_wr !== old_rom_wr)
				begin
					old_rom_wr <= rom_wr;

					//check ROM data input-output of ex_hps_io
					if (ioctl_data !== fl_ctrl_data)
						begin
							write_count_error = write_count_error + 1;
							$display ("ERROR! Flash word at %h address is %h and ex_hps_io word is %h. They are different!", fl_addr, fl_ctrl_data, ioctl_data);
						end
				end

			if (ioctl_index)
				$display ("ex_hps ioctl_index error! It's %b, but must be zero.", ioctl_index);

			if ((fl_addr + 1) == rom_sz[22:0])
				begin
					$display ("All %d ROM bytes was readed from flash with %d write errors.", rom_sz, write_count_error);
					$finish;
				end

			if (fl_addr > rom_sz[22:0])				
				begin
					$display ("ERROR! fl_addr %d is out of ROM.", fl_addr);
					$finish;
				end
		end
		
	//ROM loading must be completed at 2 seconds
	always @(negedge fpga_clk_50)
		begin
			#(64'd2000000000);
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
