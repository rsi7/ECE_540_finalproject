// nexys4fpga.v - top-level block for Nexys4 board
//
// Description:
// ------------
// Top level module for the ECE 540 Final Project
// on the Nexys4 DDR Board (Xilinx XC7A100T-CSG324)
//
//  Use the pushbuttons to control the menu:
//
//	btnl			(function)
//	btnu			(function)
//	btnr			(function)
//	btnd			(function)
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

	// Pushbuttons & switches

	input				btnL, btnR,				// pushbutton inputs - left (db_btns[4])and right (db_btns[2])
	input				btnU, btnD,				// pushbutton inputs - up (db_btns[3]) and down (db_btns[1])
	input				btnC,					// pushbutton inputs - center button -> db_btns[5]
	input				btnCpuReset,			// red pushbutton input -> db_btns[0]
	input 	[15:0]		sw,						// switch inputs
	
	// LEDs & 7-segment display

	output	[15:0]		led,  					// LED outputs	
	output	[6:0]		seg,					// 7-segment display cathode pins
	output				dp,						// 7-segment decimal points
	output	[7:0]		an,						// 7-segment display anode pins	

	// VGA signals

	output 				vga_hsync,				// horizontal sync pulse
	output 				vga_vsync,				// vertical sync pulse
	output 	[3:0]		vga_red,				// red pixel data --> send to screen
	output 	[3:0]		vga_green,				// green pixel data --> send to screen
	output 	[3:0]		vga_blue,				// blue pixel data --> send to screen

	// Microphone signals

	input 				micData,
	output 				micClk,
	output 				micLRSel);

	/******************************************************************/
	/* Local parameters and variables				                  */
	/******************************************************************/

	localparam 			cstDivPresc = 2500000;		// divide the 100MHz clock for 10Hz flags

	wire				sysreset;					// system reset signal - asserted high to force reset

	// Connections between Nexys4 <--> ClockWiz

	wire 				CLK_100MHZ;
	wire 				CLK_25MHZ;
	wire 				CLK_6MHZ;
	wire 				clk_locked;

	// Connections between KCPSM6 <--> PicoblazeMemory

	wire	[11:0]		address;
	wire	[17:0]		instruction;
	wire				bram_enable;

	// Connections between KCPSM6 <--> nexys4_rgb_if

	wire	[7:0]		port_id;
	wire	[7:0]		out_port;
	wire	[7:0]		in_port;
	wire				k_write_strobe;
	wire				write_strobe;
	wire				read_strobe;
	wire				interrupt;
	wire				interrupt_ack;

	// Connections between debounce <--> PicoBlaze

	wire 	[15:0]		db_sw;						// debounced switches
	wire 	[5:0]		db_btns;					// debounced buttons
	
	// Connections between sevensegment <--> PicoBlaze

	wire 	[4:0]		dig7, dig6, dig5, dig4, 	// display digits [7:4]
						dig3, dig2, dig1, dig0;		// display digits [3:0]

	// Connections between sevensegment <--> Nexys4

	wire 	[7:0]		decpts;						// decimal points
	wire    [7:0]       segs_int;               	// segments and the decimal point
	wire 	[63:0]		digits_out;					// ASCII digits (only for simulation)

	// Connections between audio_demo <--> FFT

	wire	[15:0]		wordTimeSample;				// data_mic (audio_demo) --> dina (Time buffer)
	wire 				flgTimeSampleValid;			// data_mic_valid (audio_demo) --> wea (Time buffer)
	wire 				flgTimeFrameActive;			// time address counter (FFT_Block) --> ena (Time buffer)
	wire 	[9:0] 		addraTime;					// time address counter (FFT_Block) --> addra (Time buffer)
	wire 	[7:0] 		byteFreqSample; 			// data_mic (FFT_Block) --> dina (Time buffer)
	wire 				flgFreqSampleValid;			// flgFreqSampleValid (FFT_Block) --> wea (frequency buffer)
	wire 	[9:0] 		addraFreq;					// frequency address counter (FFT_Block) --> addra (frequency buffer)

	// Connections between VgaCtrl <--> ImgCtrl

	wire 				flgActiveVideo;
	wire 	[9:0]		adrHor;
	wire	[9:0]		adrVer;

	// Internal signals for 10Hz flag generator block

	reg 				flgStartAcquisition;		// 10Hz flag
	integer 			cntPresc;					// counter from 0 - 2,499,999

	// RGB wire between RGBInterface <--> ImgCtrl

	wire 	[11:0]		PicoblazeRGB;

	// RGB output ImgCtrl; gets split and sent to VGA monitor

	wire 	[11:0] 		OutputRGB;

	// debugging

	reg 	[7:0]		led_reg;

	/******************************************************************/
	/* Global Assignments							                  */
	/******************************************************************/			
	
	assign 	sysreset = ~db_btns[0]; 	// btnCpuReset is asserted low --> sysreset is active-high

	assign 	dp  = segs_int [7];			// sending decimal signals --> FPGA pins
	assign 	seg = segs_int [6:0];		// sending digit signals --> FPGA pins

	assign 	led = led_reg;

	assign 	vga_red = {OutputRGB[11:8]};
	assign 	vga_green = {OutputRGB[7:4]};
	assign 	vga_blue = {OutputRGB[3:0]};

	/******************************************************************/
	/* 10Hz flag generator block					                  */
	/******************************************************************/

	always@(posedge CLK_25MHZ) begin

		if (cntPresc == (cstDivPresc-1)) begin
			cntPresc <= 1'b0;
			flgStartAcquisition <= 1'b1;
		end

		else begin
			cntPresc <= cntPresc + 1'b1;
			flgStartAcquisition <= 1'b0;
		end
	end

	always@(posedge CLK_25MHZ) begin

		if (flgStartAcquisition) begin
			led_reg <= byteFreqSample;
		end

	end

	/******************************************************************/
	/* ClockWiz instantiation		           	                      */
	/******************************************************************/

	clk_wiz_0 ClockWiz (

		// Clock Input ports
		.clk_in1	(clk),					// Give ClockWiz the 100MHz crystal oscillator signal

		// Clock Output ports
		.clk_out1	(CLK_25MHZ),			// Generate 25MHz clock to use in VGA_Controller
		.clk_out2 	(CLK_6MHZ),				// Generate 6MHz clock to use in pdm_filter
		.clk_out3 	(CLK_100MHZ), 			// Generate 100MHz clock to use on system signals

		// Status and control signals
		.reset 		(1'b0),					// active-high reset for the clock generator
		.locked 	(clk_locked));			// set high when output clocks have correct frequency & phase

	/******************************************************************/
	/* debounce instantiation						                  */
	/******************************************************************/

	debounce DB (

		// connections with Picoblaze

		.pbtn_db	(db_btns),
		.swtch_db	(db_sw),

		// connections with Nexys4

		.clk 		(CLK_100MHZ),	
		.pbtn_in	({btnC,btnL,btnU,btnR,btnD,btnCpuReset}),
		.switch_in	(sw));
	
	
	/******************************************************************/
	/* sevensegment instantiation					                  */
	/******************************************************************/

	sevensegment SSB (
		
		// connections with Picoblaze

		.d0(dig0), .d1(dig1), .d2(dig2), .d3(dig3),
		.d4(dig4), .d5(dig5), .d6(dig6), .d7(dig7),
		.dp(decpts),
		
		// connections with Nexys4

		.seg (segs_int),			
		.an (an),
		.clk (CLK_100MHZ), 
		.reset (sysreset),
		.digits_out (digits_out));	

	/******************************************************************/
	/* AudioGen instantiation                  					  	  */
	/******************************************************************/

	audio_demo AudioGen (

		.clk_i 					(CLK_100MHZ),				// I [ 0 ]
		.clk_6_144MHz 			(CLK_6MHZ),					// I [ 0 ]
		.clk_locked				(clk_locked),				// I [ 0 ] 
		.rst_i					(1'b0),						// I [ 0 ]  active-high reset for audio_demo

		// PDM interface with the MIC

		.pdm_clk_o 				(micClk),					// O [ 0 ]
		.pdm_lrsel_o 			(micLRSel),					// O [ 0 ]
		.pdm_data_i				(micData),					// I [ 0 ]

		// Parallel data from MIC

		.data_mic_valid 		(flgTimeSampleValid),		// O [ 0 ]  output from audio_demo and FftBlock (48MHz data enable)
		.data_mic 				(wordTimeSample));			// O [15:0] data from PDM decoder

	/******************************************************************/
	/* FFT instantiation                       					  	  */
	/******************************************************************/

	FftBlock FFT (

		.flgStartAcquisition	(flgStartAcquisition),		// I [ 0 ] resets the state machine
		.btnL 					(db_btns[4]),
		.sw 					(db_sw[2:0]),				// I [2:0] selecting output data byte (sensitivity)
		.ckaTime 				(CLK_100MHZ),				// I [ 0 ]
		.enaTime 				(flgTimeFrameActive),		// O [ 0 ]
		.weaTime 				(flgTimeSampleValid),		// I [ 0 ] output from audio_demo and FftBlock
		.addraTime 				(addraTime),				// O [9:0]
		.dinaTime 				(wordTimeSample[10:3]),		// I [7:0]
		.ckFreq 				(CLK_25MHZ),				// I [ 0 ]
		.flgFreqSampleValid 	(flgFreqSampleValid),		// O [ 0 ]
		.addrFreq 				(addraFreq),				// O [9:0]
		.byteFreqSample 		(byteFreqSample));			// O [7:0]

	/******************************************************************/
	/* DTG instantiation      			      					  	  */
	/******************************************************************/

 	dtg DTG (

 		.clock 			(CLK_25MHZ),		// I [ 0 ]
 		.rst 			(sysreset),			// I [ 0 ]
 		.horiz_sync 	(vga_hsync),		// O [ 0 ]
 		.vert_sync		(vga_vsync),		// O [ 0 ]
 		.video_on 		(flgActiveVideo),	// O [ 0 ]
 		.pixel_row 		(adrVer),			// O [9:0]
 		.pixel_column 	(adrHor));			// O [9:0]

	/******************************************************************/
	/* Image_Controller instantiation          					  	  */
	/******************************************************************/

	ImgCtrl Image_Controller (

		.ck100MHz 				(CLK_100MHZ), 				// I [ 0 ]

		// Time-domain signals

		.enaTime 				(flgTimeFrameActive),		// I [ 0 ]
		.weaTime 				(flgTimeSampleValid),		// I [ 0 ] output from audio_demo and FftBlock
		.addraTime 				(addraTime),				// I [9:0]
		.dinaTime 				(wordTimeSample[10:3]),		// I [7:0]

		// Frequency-domain signals

// 		.enaFreq 				(1'b1)						// I [ 0 ]
		.weaFreq				(flgFreqSampleValid),		// I [ 0 ]
		.addraFreq 				(addraFreq),				// I [9:0]
		.dinaFreq				(byteFreqSample),			// I [7:0]

		// Video Signals

		.ckVideo				(CLK_25MHZ),				// I [ 0 ]
		.flgActiveVideo 		(flgActiveVideo),			// I [ 0 ]
		.adrHor					(adrHor),					// I [9:0]
		.adrVer					(adrVer),					// I [9:0]

		// RGB output from ImgCtrl

		.OutputRGB 				(OutputRGB),				// O [11:0]

		// RGB input from Picoblaze

		.PicoblazeRGB			(PicoblazeRGB));			// I [11:0]

	/******************************************************************/
	/* RGBInterface instantiation		                              */
	/******************************************************************/

	nexys_RGB_if RGBInterface (

		// connections with Nexys4 board

		.clk 				(CLK_100MHZ),			// I [ 0 ] system clock input from Nexys4 board
		.reset 				(sysreset),				// I [ 0 ] system reset signal from Nexys4 board

		// connections with debounce

		.db_btns 			(db_btns),				// I [5:0] debounced pushbutton inputs

		// connections with sevensegment

		.dig7 	(dig7),			// O [4:0] digit #7 signal for sevensegment
		.dig6 	(dig6),			// O [4:0] digit #6 signal for sevensegment
		.dig5 	(dig5),			// O [4:0] digit #5 signal for sevensegment
		.dig4 	(dig4),			// O [4:0] digit #4 signal for sevensegment
		.dig3 	(dig3),			// O [4:0] digit #3 signal for sevensegment
		.dig2 	(dig2),			// O [4:0] digit #2 signal for sevensegment
		.dig1 	(dig1),			// O [4:0] digit #1 signal for sevensegment
		.dig0 	(dig0),			// O [4:0] digit #0 signal for sevensegment

		// connections with ImgCtrl

		.PicoblazeRGB			(PicoblazeRGB),			// O [11:0]

		// connections with KCPSM6

		.port_id 			(port_id),				// I [7:0] address of port id
		.out_port 			(out_port),				// I [7:0] output from KCPSM6 --> input to interface
		.in_port 			(in_port),				// O [7:0] output from inteface --> input to KCPSM6
		.k_write_strobe 	(k_write_strobe),		// I [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUT'
		.write_strobe 		(write_strobe),			// I [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUTK'
		.read_strobe 		(read_strobe),			// I [ 0 ] pulses high for one cycle when KCPSM6 runs 'INPUT'
		.interrupt 			(interrupt),			// O [ 0 ] driven high --> force KCPSM to perform interrupt
		.interrupt_ack		(interrupt_ack));		// I [ 0 ] pulses high for one cycle when KCPSM6 calls interrupt vector

	/******************************************************************/
	/* KCPSM6  instantiation		                              	  */
	/******************************************************************/

	kcpsm6 #(
		.interrupt_vector			(12'h3FF),
		.scratch_pad_memory_size	(64),
		.hwbuild					(8'h00))

	KCPSM6 (

		// connections with FinalProject

		.address 			(address),				// O [11:0] program address going to Proj2Demo
		.instruction 		(instruction),			// I [17:0] instructions from Proj2Demo
		.bram_enable 		(bram_enable),			// O [ 0 ] read enable for program memory
		.reset 				(sysreset),				// I [ 0 ] driven high --> resets processor

		// connections with nexys_RGB_if

		.port_id 			(port_id),				// O [7:0] defines which port KCPSM6 should read/write
		.write_strobe 		(write_strobe),			// O [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUT'
		.k_write_strobe 	(k_write_strobe),		// O [ 0 ] pulses high for one cycle when KCPSM6 runs 'OUTPUTK'
		.out_port 			(out_port),				// O [7:0] output data from KCPSM6 --> peripheral
		.read_strobe 		(read_strobe),			// O [ 0 ] pulses high for one cycle when KCPSM6 runs 'READ'
		.in_port 			(in_port),				// I [7:0] input data from peripheral --> KCPSM6
		.interrupt 			(interrupt),			// I [ 0 ] driven high --> generates interrupt for KCPSM6
		.interrupt_ack 		(interrupt_ack),		// O [ 0 ] pulses high for one cycle when KCPSM6 calls interrupt vector

		// connections with Nexys4 board

		.sleep				(1'b0),					// I [ 0 ] tied to 1'b0 to disable input
		.clk 				(CLK_100MHZ));			// I [ 0 ] system clock from Nexys4 board

	/******************************************************************/
	/* PicoblazeMemory instantiation                    			  */
	/******************************************************************/	

	finalproject #(
		.C_FAMILY		   		("7S"),			// 7-Series device
		.C_RAM_SIZE_KWORDS		(2),   			// RAM capacity: 2K instructions
		.C_JTAG_LOADER_ENABLE	(1))     		// set to 1'b1 --> includes JTAG Loader

	PicoblazeMemory (

		// connections with KCPSM6

		.rdl 			(		),				// O [ 0 ]  reset during load signal for JTAG Loader
		.enable 		(bram_enable),			// I [ 0 ]  read-enable for program memory
		.address 		(address),				// I [11:0] program address coming from KCPSM6
		.instruction 	(instruction),			// O [17:0] instructions going to KCPSM6

		// connections with Nexys4 board

		.clk 			(CLK_100MHZ));			// I [ 0 ] system clock from Nexys4 board	

endmodule