// nexys4fpga.v - top-level block for Nexys4 board
//
// Description:
// ------------
// Top level module for the ECE 540 Final Project
// on the Nexys4 DDR Board (Xilinx XC7A100T-CSG324)
//
//  Use the pushbuttons to control the FFT color:
//
//	btnL			Scroll through color menu
//	btnR			Scroll through color menu
//	btnU			Increase R/G/B value
//	btnD			Decrease R/G/B value
//  btnC			Resets the FFT core
//	btnCpuReset		CPU RESET Button: active-low on board --> sets 'sysreset' high
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

	input				btnL, btnR,				// pushbutton inputs - left and right
	input				btnU, btnD,				// pushbutton inputs - up and down
	input				btnC,					// pushbutton inputs - center button
	input				btnCpuReset,			// red pushbutton input
	input 	[15:0]		sw,						// switch inputs
	
	// LEDs & 7-segment display

	output	[15:0]		led,  					// LED outputs	
	output	[6:0]		seg,					// 7-segment display cathode pins
	output				dp,						// 7-segment decimal points
	output	[7:0]		an,						// 7-segment display anode pins	

	// VGA signals

	output 				vga_hsync,				// horizontal sync pulse for 512x480 screen (60Hz refresh)
	output 				vga_vsync,				// vertical sync pulse for 512x480 screen (60Hz refresh)
	output 	[3:0]		vga_red,				// red data for current pixel --> send to screen
	output 	[3:0]		vga_green,				// green data for current pixel --> send to screen
	output 	[3:0]		vga_blue,				// blue data for current pixel --> send to screen

	// Analog-to-digital converter signals

	input 				micData,				// pulse-density modulated data coming from ADC
	output 				micClk,					// 3MHz clock needed by the on-board ADC
	output 				micLRSel);				// tied to 1'b0 for left channel only

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

	// Connections between KCPSM6 <--> RGBInterface

	wire	[7:0]		port_id;
	wire	[7:0]		out_port;
	wire	[7:0]		in_port;
	wire				k_write_strobe;
	wire				write_strobe;
	wire				read_strobe;
	wire				interrupt;
	wire				interrupt_ack;

	// Connections between debounce <--> Picoblaze

	wire 	[15:0]		db_sw;						// debounced switches
	wire 				btnC_db;					// debounced center pushbutton
	wire 				btnL_db;					// debounced left pushbutton
	wire 				btnU_db;					// debounced up pushbutton
	wire 				btnR_db;					// debounced right pushbutton
	wire 				btnD_db;					// debounced down pushbutton
	wire 				btnCpuReset_db;				// debounced CpuReset

	// Connections between sevensegment <--> Picoblaze

	wire 	[4:0]		dig7, dig6, dig5, dig4, 	// display digits [7:4]
						dig3, dig2, dig1, dig0;		// display digits [3:0]

	// Connections between sevensegment <--> Nexys4

	wire 	[7:0]		decpts;						// decimal points
	wire    [7:0]       segs_int;               	// segments and the decimal point
	wire 	[63:0]		digits_out;					// ASCII digits (only for simulation)

	// Connections between AudioGen <--> FFT & ImgCtrl

	wire	[15:0]		wordTimeSample;				// time-domain sample: AudioGen --> FFT & ImgCtrl
	wire 				flgTimeSampleValid;			// write enable for time buffer: AudioGen --> FFT & ImgCtrl

	// Connections between FFT <--> ImgCtrl

	wire 				flgTimeFrameActive;			// port A enable for time buffer: FFT --> ImgCtrl
	wire 	[9:0] 		addraTime;					// time buffer address: FFT --> ImgCtrl
	wire 	[7:0] 		byteFreqSample; 			// frequency power (bin height):  FFT --> ImgCtrl
	wire 				flgFreqSampleValid;			// write enable for frequency buffer: FFT --> ImgCtrl
	wire 	[9:0] 		addraFreq;					// frequency buffer address: FFT --> ImgCtrl

	// Connections between DTG <--> ImgCtrl

	wire 				flgActiveVideo;				// flag indicating whether current pixel is in 512x480 frame
	wire 	[9:0]		adrHor;						// pixel column (x-coordinate)
	wire	[9:0]		adrVer;						// pixel row (y-coordinate)

	// Connections between RGBInterface <--> ImgCtrl

	wire 	[11:0]		PicoblazeRGB;				// RGB values to use in FFT display

	// Connections between ImgCtrl <--> Nexys4

	wire 	[11:0] 		OutputRGB;					// RGB values for VGA current pixel

	// Internal signals for flgStartAcquisition block

	reg 				flgStartAcquisition;		// 10Hz flag to restart FFT state machine
	integer 			cntPresc;					// counter from 0 - 2,499,999

	// Internal register for LED debugging

	reg 	[15:0] 		led_reg;

	/******************************************************************/
	/* Global Assignments							                  */
	/******************************************************************/			
	
	assign 	sysreset = ~btnCpuReset_db; 		// btnCpuReset is asserted low --> sysreset is active-high

	assign 	dp  = segs_int [7];					// sending decimal signals --> FPGA pins
	assign 	seg = segs_int [6:0];				// sending digit signals --> FPGA pins

	assign 	vga_red = {OutputRGB[11:8]};		// send 4-bits for red value in current pixel
	assign 	vga_green = {OutputRGB[7:4]};		// send 4-bits for green value in current pixel
	assign 	vga_blue = {OutputRGB[3:0]};		// send 4-bits for blue value in current pixel

	assign led[7:0] = led_reg[7:0];
	assign led[15:8] = led_reg[15:8];

	/******************************************************************/
	/* flgStartAcquisition generator block 			                  */
	/******************************************************************/

	// generates a flag every 10Hz
	// used to reset FFT state machine

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

	// show time-domain and frequency domain data on LEDs
	// used for debugging

	always@(posedge CLK_25MHZ) begin
		if (flgStartAcquisition == 1) begin
			led_reg[7:0]   <= byteFreqSample;
			led_reg[15:8]  <= wordTimeSample[10:3];
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

		.pbtn_db	({btnC_db,btnL_db,btnU_db,btnR_db,btnD_db,btnCpuReset_db}),
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

		.clk_i 					(CLK_100MHZ),				// I [ 0 ] 100MHz system clock from ClockWiz
		.clk_6_144MHz 			(CLK_6MHZ),					// I [ 0 ] 6.144MHz clock from ClockWiz
		.clk_locked				(clk_locked),				// I [ 0 ] active-high flag indicating clock is stable
		.rst_i					(1'b0),						// I [ 0 ] active-high reset for module

		// Connections with board's analog-to-digital converter

		.pdm_clk_o 				(micClk),					// O [ 0 ] 3MHz clock needed by the on-board ADC
		.pdm_lrsel_o 			(micLRSel),					// O [ 0 ] tied to 1'b0 for left channel only
		.pdm_data_i				(micData),					// I [ 0 ] pulse-density modulated data coming from ADC

		// Connections with FFT & ImgCtrl

		.data_mic_valid 		(flgTimeSampleValid),		// O [ 0 ]  sampling frequency a.k.a. time-domain data enable signal (48kHz)
		.data_mic 				(wordTimeSample));			// O [15:0] decoded time-sample data from PDM filter

	/******************************************************************/
	/* FFT instantiation                       					  	  */
	/******************************************************************/

	FftBlock FFT (

		.flgStartAcquisition	(flgStartAcquisition),		// I [ 0 ] resets the FFT state machine every 10Hz
		.btnC 					(btnC_db),					// I [ 0 ] pushbutton to reset FFT state machine
		.sw 					(db_sw[2:0]),				// I [2:0] selecting output data byte (sensitivity)
		.ckaTime 				(CLK_100MHZ),				// I [ 0 ] 100MHz system clock from ClockWiz
		.ckFreq 				(CLK_25MHZ),				// I [ 0 ] 25MHz clock from ClockWiz

		// Connections with AudioGen

		.weaTime 				(flgTimeSampleValid),		// I [ 0 ] sampling frequency a.k.a. time-domain data enable signal (48kHz)
		.dinaTime 				(wordTimeSample[10:3]),		// I [7:0] decoded time-sample data from PDM filter

		// Connections with ImgCtrl

		.enaTime 				(flgTimeFrameActive),		// O [ 0 ] port A enable for time buffer: FFT --> ImgCtrl
		.addraTime 				(addraTime),				// O [9:0] time buffer address: FFT --> ImgCtrl
		.flgFreqSampleValid 	(flgFreqSampleValid),		// O [ 0 ] write enable for frequency buffer: FFT --> ImgCtrl
		.addrFreq 				(addraFreq),				// O [9:0] frequency buffer address: FFT --> ImgCtrl
		.byteFreqSample 		(byteFreqSample));			// O [7:0] frequency power (bin height): FFT --> ImgCtrl

	/******************************************************************/
	/* DTG instantiation      			      					  	  */
	/******************************************************************/

 	dtg DTG (

 		// Global signals

 		.clock 			(CLK_25MHZ),		// I [ 0 ] 25MHz clock for video timing signals from ClockWiz
 		.rst 			(sysreset),			// I [ 0 ] active-high system reset for module

 		// Generated timing signals

 		.horiz_sync 	(vga_hsync),		// O [ 0 ] horizontal sync pulse for 512x480 screen (60Hz refresh)
 		.vert_sync		(vga_vsync),		// O [ 0 ] vertical sync pulse for 512x480 screen (60Hz refresh)
 		.video_on 		(flgActiveVideo),	// O [ 0 ] active-high flag if current pixel is in 512x480 display frame

 		// pixel coordinates

 		.pixel_row 		(adrVer),			// O [9:0] y-coordinate of current pixel
 		.pixel_column 	(adrHor));			// O [9:0] x-coordinate of current pixel

	/******************************************************************/
	/* Image_Controller instantiation          					  	  */
	/******************************************************************/

	ImgCtrl Image_Controller (

		// Global signals

		.ck100MHz 				(CLK_100MHZ), 				// I [ 0 ] 100MHz system clock from ClockWiz

		// Connections with AudioGen

		.weaTime 				(flgTimeSampleValid),		// I [ 0 ] sampling frequency a.k.a. time-domain data enable signal (48kHz)
		.dinaTime 				(wordTimeSample[10:3]),		// I [7:0] decoded time-sample data from PDM filter

		// Connections with FFT

		.enaTime 				(flgTimeFrameActive),		// I [ 0 ] port A enable for time buffer: FFT --> ImgCtrl
		.addraTime 				(addraTime),				// I [9:0] time buffer address: FFT --> ImgCtrl
		.weaFreq				(flgFreqSampleValid),		// I [ 0 ] write enable for frequency buffer: FFT --> ImgCtrl
		.addraFreq 				(addraFreq),				// I [9:0] frequency buffer address: FFT --> ImgCtrl
		.dinaFreq				(byteFreqSample),			// I [7:0] frequency power (bin height): FFT --> ImgCtrl

		// Connections with DTG

		.ckVideo				(CLK_25MHZ),				// I [ 0 ] 25MHz clock for video timing signals from ClockWiz
		.flgActiveVideo 		(flgActiveVideo),			// I [ 0 ] active-high flag if current pixel is in 512x480 display frame
		.adrHor					(adrHor),					// I [9:0] x-coordinate of current pixel
		.adrVer					(adrVer),					// I [9:0] y-coordinate of current pixel

		// Connections with VGA display

		.OutputRGB 				(OutputRGB),				// O [11:0] RGB values for VGA current pixel

		// Connections with RGBInterface

		.PicoblazeRGB			(PicoblazeRGB));			// I [11:0] RGB values to use in FFT display

	/******************************************************************/
	/* RGBInterface instantiation		                              */
	/******************************************************************/

	nexys_RGB_if RGBInterface (

		// connections with Nexys4 board

		.clk 				(CLK_100MHZ),			// I [ 0 ] system clock input from Nexys4 board
		.reset 				(sysreset),				// I [ 0 ] system reset signal from Nexys4 board

		// connections with debounce

		.db_btns 			({btnC_db,btnL_db,btnU_db,btnR_db,btnD_db,btnCpuReset_db}),		// I [5:0] debounced pushbuttons

		// connections with sevensegment

		.dig7 	(dig7),			// O [4:0] digit #7 signal --> sevensegment
		.dig6 	(dig6),			// O [4:0] digit #6 signal --> sevensegment
		.dig5 	(dig5),			// O [4:0] digit #5 signal --> sevensegment
		.dig4 	(dig4),			// O [4:0] digit #4 signal --> sevensegment
		.dig3 	(dig3),			// O [4:0] digit #3 signal --> sevensegment
		.dig2 	(dig2),			// O [4:0] digit #2 signal --> sevensegment
		.dig1 	(dig1),			// O [4:0] digit #1 signal --> sevensegment
		.dig0 	(dig0),			// O [4:0] digit #0 signal --> sevensegment

		// connections with ImgCtrl

		.PicoblazeRGB			(PicoblazeRGB),		// O [11:0] RGB values to use in FFT display

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