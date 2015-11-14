// nexys4fpga.v - top-level block for Nexys4 board
//
// Description:
// ------------
// Top level module for the ECE 540 Project 2 Video Demo
// on the Nexys4 DDR Board (Xilinx XC7A100T-CSG324)
//
//  Use the pushbuttons to control the BotSim wheels:
//
//	btnl			Left wheel forward
//	btnu			Left wheel reverse
//	btnr			Right wheel forward
//	btnd			Right wheel reverse
//  btnc			Not used in this design
//	btnCpuReset		CPU RESET Button - system reset.  Asserted low by Nexys 4 board
//
//  External port names match pin names in the nexys4fpga.xdc constraints file
//
////////////////////////////////////////////////////////////////////////////////////////////////

module nexys4fpga (

	/******************************************************************/
	/* Top-level port declarations					                  */
	/******************************************************************/

	input				clk,					// 100MHz clock from on-board oscillator
	input				btnL, btnR,				// pushbutton inputs - left (db_btns[4])and right (db_btns[2])
	input				btnU, btnD,				// pushbutton inputs - up (db_btns[3]) and down (db_btns[1])
	input				btnC,					// pushbutton inputs - center button -> db_btns[5]
	input				btnCpuReset,			// red pushbutton input -> db_btns[0]
	input	[15:0]		sw,						// switch inputs
	
	output	[15:0]		led,  					// LED outputs	
	output	[6:0]		seg,					// Seven segment display cathode pins
	output				dp,						// Seven segment decimal points
	output	[7:0]		an,						// Seven segment display anode pins	
	output	[7:0]		JA,						// JA Header

	output 				vga_hsync,				// horizontal sync pulse from DTG
	output 				vga_vsync,				// vertical sync pulse from DTG
	output 	[3:0]		vga_red,				// red pixel data --> send to screen
	output 	[3:0]		vga_green,				// green pixel data --> send to screen
	output 	[3:0]		vga_blue				// blue pixel data --> send to screen
);

	/******************************************************************/
	/* Local parameters and variables				                  */
	/******************************************************************/

	parameter 			SIMULATE = 0;

	wire				sysclk;						// 75MHz system clock coming from ClockWiz
	wire 				vgaclk; 					// 25MHz VGA clock coming from ClockWiz
	wire				sysreset;					// system reset signal - asserted high to force reset

	// Connections between Nexys4 <--> ClockWiz

	wire 				CLK_75MHZ;
	wire 				CLK_25MHZ;

	// Connections between BotSim <--> BotInterface

	wire 	[7:0] 		MotCtl;
	wire 	[7:0] 		LocX;
	wire 	[7:0] 		LocY;
	wire 	[7:0] 		botInfo;
	wire 	[7:0] 		Sensors;
	wire 	[7:0] 		lmdist;
	wire 	[7:0] 		rmdist;
	wire 				upd_sysregs;

	// Connections between KCPSM6 <--> Proj2Demo

	wire	[11:0]		address;
	wire	[17:0]		instruction;
	wire				bram_enable;
	wire				kcpsm6_sleep;

	// Connections between KCPSM6 <--> BotInterface

	wire	[7:0]		port_id;
	wire	[7:0]		out_port;
	wire	[7:0]		in_port;
	wire				k_write_strobe;
	wire				write_strobe;
	wire				read_strobe;
	wire				interrupt;
	wire				interrupt_ack;

	// Connections between debounce <--> BotInterface

	wire 	[15:0]		db_sw;						// debounced switches
	wire 	[5:0]		db_btns;					// debounced buttons
	
	// Connections between sevensegment <--> BotInterface

	wire 	[4:0]		dig7, dig6, dig5, dig4, 	// display digits [7:4]
						dig3, dig2, dig1, dig0;		// display digits [3:0]

	wire 	[7:0]		decpts;						// decimal points
	wire    [7:0]       segs_int;               	// segments and the decimal point
	wire 	[63:0]		digits_out;					// ASCII digits (only for simulation)

	// Connections between VGA <--> BotSim

	wire 	[11:0] 		color;				// RGB pixel data --> send to screen
	wire 	[1:0]		world_pixel;		// map info (bkgnd, line, etc.) for current pixel
	wire 	[9:0]		pixel_row;			// Y-coordinate of the current pixel
	wire 	[9:0] 		pixel_column;		// X-coordinate of the current pixel

	/******************************************************************/
	/* Global Assignments							                  */
	/******************************************************************/			

	assign	sysclk = CLK_75MHZ;			// reference for 75MHz system clock
	assign  vgaclk = CLK_25MHZ;			// reference for 25MHz VGA clock
	
	assign 	sysreset = ~db_btns[0]; 	// btnCpuReset is asserted low
	assign 	kcpsm6_sleep = 1'b0;		// tied low to disable the input			

	assign 	dp  = segs_int [7];			// sending decimal signals --> FPGA pins
	assign 	seg = segs_int [6:0];		// sending digit signals --> FPGA pins

	assign	JA = {sysclk, sysreset, 6'b000000};

	assign vga_red 	 = color [11:8];
	assign vga_green = color [7:4];
	assign vga_blue  = color [3:0];

	/******************************************************************/
	/* ClockWiz instantiation		           	                      */
	/******************************************************************/

	clk_wiz_0_clk_wiz ClockWiz (

		// Clock Input ports
		.clk_in1	(clk),					// Give ClockWiz the 100MHz crystal oscillator signal

		// Clock Output ports
		.CLK_75MHZ	(CLK_75MHZ),			// Generate 75MHz clock to assign to 'sysclk'
		.CLK_25MHZ	(CLK_25MHZ),			// Generate 25MHz clock to assign to 'vgaclk'

		// Status and control signals
		.reset 		(1'b0),					// active-high reset for the clock generator
		.locked 	(	  ));				// set high when output clocks have correct frequency & phase

	/******************************************************************/
	/* BotSim instantiation							                  */
	/******************************************************************/

	bot BotSim (									

		// connections with BotInterface

		.MotCtl_in		(MotCtl),				// I [7:0] Motor control input
		.LocX_reg		(LocX),					// O [7:0] X-coordinate of BotSim's location
		.LocY_reg		(LocY),					// O [7:0] Y-coordinate of BotSim's location
		.Sensors_reg	(Sensors),				// O [7:0] Sensor readings
		.BotInfo_reg	(botInfo),				// O [7:0] Information about BotSim's activity
		.LMDist_reg		(lmdist),				// O [7:0] left motor distance register
		.RMDist_reg		(rmdist),				// O [7:0] right motor distance register
		.upd_sysregs	(upd_sysregs), 			// O [ 0 ] flag from BotSim to indicate that the system registers
												// (LocX, LocY, Sensors, BotInfo_reg) have been updated

		// // connections with video controller

		.vid_row		(pixel_row),			// I [9:0] Y-coordinate of the current pixel
		.vid_col		(pixel_column),			// I [9:0] X-coordinate of the current pixel
		.vid_pixel_out	(world_pixel),			// O [1:0] map info (bkgnd, line, etc.) for current pixel

		// connections with Nexys4

		.clk 			(sysclk),				// I [ 0 ] system clock from Nexys4 board
		.reset 			(sysreset));			// I [ 0 ] system reset signal from Nexys4 board

	/******************************************************************/
	/* BotInterface instantiation		                              */
	/******************************************************************/

	nexys_bot_if BotInterface (

		// connections with BotSim

		.MotCtl 		(MotCtl),				// O [7:0] Motor control of BotSim
		.LocX 			(LocX),					// I [7:0] X-coordinate of BotSim's location
		.LocY 			(LocY),					// I [7:0] Y-coordinate of BotSim's location
		.Sensors 		(Sensors), 				// I [7:0] Sensor readings from BotSim
		.botInfo 		(botInfo), 				// I [7:0] Information about BotSim's activity
		.lmdist 		(lmdist), 				// I [7:0] Left motor distance register
		.rmdist 		(rmdist), 				// I [7:0] Right motor distance register
		.upd_sysregs 	(upd_sysregs),			// I [ 0 ] update system register
	
		// connections with KCPSM6

		.port_id 			(port_id),				// I [7:0] address of port id
		.out_port 			(out_port),				// I [7:0] output from KCPSM6 --> input to interface
		.in_port 			(in_port),				// O [7:0] output from inteface --> input to KCPSM6
		.k_write_strobe 	(k_write_strobe),		// I [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUT'
		.write_strobe 		(write_strobe),			// I [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUTK'
		.read_strobe 		(read_strobe),			// I [ 0 ] pulses high for one cycle when KCPSM6 runs 'INPUT'
		.interrupt 			(interrupt),			// O [ 0 ] driven high --> force KCPSM to perform interrupt
		.interrupt_ack		(interrupt_ack),		// I [ 0 ] pulses high for one cycle when KCPSM6 calls interrupt vector
	
		// connections with debounce

		.db_btns 	(db_btns),			// I [5:0] debounced pushbutton inputs
		.db_sw 		(db_sw),			// I [15:0] debounced slide switch inputs

		// connections with sevensegment

		.dig7 	(dig7),			// O [4:0] digit #7 signal for sevensegment
		.dig6 	(dig6),			// O [4:0] digit #6 signal for sevensegment
		.dig5 	(dig5),			// O [4:0] digit #5 signal for sevensegment
		.dig4 	(dig4),			// O [4:0] digit #4 signal for sevensegment
		.dig3 	(dig3),			// O [4:0] digit #3 signal for sevensegment
		.dig2 	(dig2),			// O [4:0] digit #2 signal for sevensegment
		.dig1 	(dig1),			// O [4:0] digit #1 signal for sevensegment
		.dig0 	(dig0),			// O [4:0] digit #0 signal for sevensegment
		.dp 	(decpts),		// O [7:0] decimal point signal for sevensegment
	
		// connections with Nexys4

		.led 			(led),			// O [15:0] signals for writing Nexys4 LEDs
		.clk 			(sysclk),		// I [ 0 ] system clock input from Nexys4 board
		.reset 			(sysreset));	// I [ 0 ] system reset signal from Nexys4 board

	/******************************************************************/
	/* KCPSM6 instantiation                       					  */
	/******************************************************************/							
	
	kcpsm6 #(
		.interrupt_vector			(12'h3FF),
		.scratch_pad_memory_size	(64),
		.hwbuild					(8'h00))

	KCPSM6 (

		// connections with Proj2Demo

		.address 			(address),				// O [11:0] program address going to Proj2Demo
		.instruction 		(instruction),			// I [17:0] instructions from Proj2Demo
		.bram_enable 		(bram_enable),			// O [ 0 ] read enable for program memory
		.reset 				(sysreset),				// I [ 0 ] driven high --> resets processor

		// connections with BotInterface

		.port_id 			(port_id),				// O [7:0] defines which port KCPSM6 should read/write
		.write_strobe 		(write_strobe),			// O [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUT'
		.k_write_strobe 	(k_write_strobe),		// O [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUTK'
		.out_port 			(out_port),				// O [7:0] output data from KCPSM6 --> peripheral
		.read_strobe 		(read_strobe),			// O [ 0 ] pulses high for one cycle when KCPSM6 runs 'READ'
		.in_port 			(in_port),				// I [7:0] input data from peripheral --> KCPSM6
		.interrupt 			(interrupt),			// I [ 0 ] driven high --> generates interrupt for KCPSM6
		.interrupt_ack 		(interrupt_ack),		// O [ 0 ] pulses high for one cycle when KCPSM6 calls interrupt vector

		// connections with Nexys4

		.sleep				(kcpsm6_sleep),			// I [ 0 ] tied to 1'b0 to disable input
		.clk 				(sysclk));				// I [ 0 ] system clock from Nexys4 board

	/******************************************************************/
	/* Proj2Demo instantiation                    					  */
	/******************************************************************/	

	proj2demo #(
		.C_FAMILY		   		("7S"),			// 7-Series device
		.C_RAM_SIZE_KWORDS		(2),   			// RAM capacity: 2K instructions
		.C_JTAG_LOADER_ENABLE	(1))     		// set to 1'b1 --> includes JTAG Loader

	Proj2Demo (

		// connections with KCPSM6

		.rdl 			(		),				// O [ 0 ]  reset during load signal for JTAG Loader
		.enable 		(bram_enable),			// I [ 0 ]  read-enable for program memory
		.address 		(address),				// I [11:0] program address coming from KCPSM6
		.instruction 	(instruction),			// O [17:0] instructions going to KCPSM6

		// connections with Nexys4

		.clk 			(sysclk));				// I [ 0 ] system clock from Nexys4 board

	/******************************************************************/
	/* debounce instantiation						                  */
	/******************************************************************/

	debounce #(.SIMULATE (SIMULATE)) 

	DB (

		// connections with BotInterface

		.pbtn_db	(db_btns),
		.swtch_db	(db_sw),

		// connections with Nexys4

		.clk 		(sysclk),	
		.pbtn_in	({btnC,btnL,btnU,btnR,btnD,btnCpuReset}),
		.switch_in	(sw));
	
	
	/******************************************************************/
	/* sevensegment instantiation					                  */
	/******************************************************************/

	sevensegment #(.SIMULATE (SIMULATE)) 

	SSB (
		
		// connections with BotInterface

		.d0(dig0), .d1(dig1), .d2(dig2), .d3(dig3),
		.d4(dig4), .d5(dig5), .d6(dig6), .d7(dig7),
		.dp(decpts),
		
		// connections with Nexys4

		.seg (segs_int),			
		.an (an),
		.clk (sysclk), 
		.reset (sysreset),
		.digits_out (digits_out));	

	/******************************************************************/
	/* VGA instantiation                       					  	  */
	/******************************************************************/

	video_controller VGA (

		// connections with Nexys4

		.clock 			(vgaclk),				// I [ 0 ]  25MHz clock from ClockWiz module
		.reset 			(sysreset),				// I [ 0 ]  active-high debounced reset from Nexys4
		.horiz_sync 	(vga_hsync),			// O [ 0 ]  horizontal sync pulse from DTG
		.vert_sync 		(vga_vsync),			// O [ 0 ]  vertical sync pulse from DTG
		.color 			(color),				// O [11:0] RGB pixel data --> send to screen

		// connections with BotSim

		.LocX 			(LocX),					// I [7:0]  X-coordinate of Rojobot's location
		.LocY 			(LocY),					// I [7:0]  Y-coordinate of Rojobot's location
		.BotInfo 		(botInfo),				// I [7:0]  Rojobot's movement [7:4] and orientation [3:0]
		.world_pixel 	(world_pixel),			// I [1:0]  map info (bkgnd, line, etc.) for current pixel
		.pixel_row 		(pixel_row),			// O [9:0]  Y-coordinate of the current pixel
		.pixel_column 	(pixel_column));		// O [9:0]  X-coordinate of the current pixel

endmodule