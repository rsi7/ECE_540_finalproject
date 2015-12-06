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

	output 				Hsync,					// horizontal sync pulse
	output 				Vsync,					// vertical sync pulse
	output 	[3:0]		vgaRed,					// red pixel data --> send to screen
	output 	[3:0]		vgaGreen,				// green pixel data --> send to screen
	output 	[3:0]		vgaBlue,				// blue pixel data --> send to screen

	// Microphone signals

	input 				micData,
	output 				micClk,
	output 				micLRSel,

	// PWM interface with Audio Out

	output 				pdm_data_o,
	output 				pdm_en_o);

	/******************************************************************/
	/* Local parameters and variables				                  */
	/******************************************************************/

	parameter 			SIMULATE = 0;
	localparam 			cstDivPresc = 10000000;		// divide the 100MHz clock for 10Hz flags

	wire				sysreset;					// system reset signal - asserted high to force reset

	// Connections between Nexys4 <--> ClockWiz

	wire 				CLK_25MHZ;

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

	// Connections

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

	// Connections for 10Hz flag generator block

	reg 				flgStartAcquisition;		// 10Hz flag
	integer 			cntPresc;					// counter from 0 - 9999999


	/******************************************************************/
	/* Global Assignments							                  */
	/******************************************************************/			
	
	assign 	sysreset = ~db_btns[0]; 	// btnCpuReset is asserted low --> sysreset is active-high

	assign 	dp  = segs_int [7];			// sending decimal signals --> FPGA pins
	assign 	seg = segs_int [6:0];		// sending digit signals --> FPGA pins

	/******************************************************************/
	/* 10Hz flag generator block					                  */
	/******************************************************************/

	always@(posedge clk) begin
		if (cntPresc == (cstDivPresc-1)) begin
			cntPresc <= 1'b0;
			flgStartAcquisition <= 1'b1;
		end
		else begin
			cntPresc <= cntPresc + 1'b1;
			flgStartAcquisition <= 1'b0;
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

		// Status and control signals
		.reset 		(1'b0),					// active-high reset for the clock generator
		.locked 	(	  ));				// set high when output clocks have correct frequency & phase

	/******************************************************************/
	/* debounce instantiation						                  */
	/******************************************************************/

	debounce #(.SIMULATE (SIMULATE)) 

	DB (

		// connections with PicoBlaze

		.pbtn_db	(db_btns),
		.swtch_db	(db_sw),

		// connections with Nexys4

		.clk 		(clk),	
		.pbtn_in	({btnC,btnL,btnU,btnR,btnD,btnCpuReset}),
		.switch_in	(sw));
	
	
	/******************************************************************/
	/* sevensegment instantiation					                  */
	/******************************************************************/

	sevensegment #(.SIMULATE (SIMULATE)) 

	SSB (
		
		// connections with PicoBlaze

		.d0(dig0), .d1(dig1), .d2(dig2), .d3(dig3),
		.d4(dig4), .d5(dig5), .d6(dig6), .d7(dig7),
		.dp(decpts),
		
		// connections with Nexys4

		.seg (segs_int),			
		.an (an),
		.clk (clk), 
		.reset (sysreset),
		.digits_out (digits_out));	

	/******************************************************************/
	/* AudioGen instantiation                  					  	  */
	/******************************************************************/

	audio_demo AudioGen (

		.clk_i 					(clk),						// I [ 0 ]
		.rst_i					(1'b0),						// I [ 0 ]  active-high reset for audio_demo

		// PDM interface with the MIC

		.pdm_clk_o 				(micClk),					// O [ 0 ]
		.pdm_lrsel_o 			(micLRSel),					// O [ 0 ]
		.pdm_data_i				(micData),					// I [ 0 ]

		// Parallel data from MIC

		.data_mic_valid 		(flgTimeSampleValid),		// O [ 0 ]  output from audio_demo and FftBlock (48MHz data enable)
		.data_mic 				(wordTimeSample),			// O [15:0] data from PDM decoder

		// PWM interface with Audio Out

		.pdm_data_o 			(pdm_data_o),				// O [ 0 ]
		.pdm_en_o 				(pdm_en_o));				// O [ 0 ]	   

	/******************************************************************/
	/* FFT instantiation                       					  	  */
	/******************************************************************/

	FftBlock FFT (

		.flgStartAcquisition	(flgStartAcquisition),		// I [ 0 ] resets the state machine
		.btnL 					(db_btns[4]),
		.sw 					(db_sw[2:0]),				// I [2:0] selecting output data byte (sensitivity)
		.ckaTime 				(clk),						// I [ 0 ]
		.enaTime 				(flgTimeFrameActive),		// O [ 0 ]
		.weaTime 				(flgTimeSampleValid),		// O [ 0 ] output from audio_demo and FftBlock
		.addraTime 				(addraTime),				// O [9:0]
		.dinaTime 				(wordTimeSample[10:3]),		// I [7:0]
		.ckFreq 				(CLK_25MHZ),				// I [ 0 ]
		.flgFreqSampleValid 	(flgFreqSampleValid),		// O [ 0 ]
		.addrFreq 				(addraFreq),				// O [9:0]
		.byteFreqSample 		(byteFreqSample));			// O [7:0]

	/******************************************************************/
	/* VGA_Controller instantiation            					  	  */
	/******************************************************************/

	VgaCtrl VGA_Controller (

		.ckvideo 				(CLK_25MHZ),				// I [ 0 ]
		.adrHor					(adrHor),					// O [9:0]
		.adrVer					(adrVer),					// O [9:0]
		.flgActiveVideo 		(flgActiveVideo),			// O [ 0 ]
		.HS 					(Hsync),					// O [ 0 ]
		.VS 					(Vsync));					// O [ 0 ]

	/******************************************************************/
	/* Image_Controller instantiation          					  	  */
	/******************************************************************/

	ImgCtrl Image_Controller (

		.ck100MHz 				(clk), 						// I [ 0 ]

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
		.red 					(vgaRed),					// O [3:0]
		.green 					(vgaGreen),					// O [3:0]
		.blue 					(vgaBlue));					// O [3:0]

endmodule