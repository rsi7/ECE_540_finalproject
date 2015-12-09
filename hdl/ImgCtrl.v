// ImgCtrl.v - determines what color to draw based on pixel (X,Y) and bin / wave height
//
// Description:
// ------------
// 
// This module stores the time-domain samples and frequency-domain samples into two seperate RAMs
// Then, based on the current pixel's x-coordinate it reads the RAM values for each
//
// If the current pixel's y-coordinate is in the display's top-half, it will draw the time display
// It draws Picoblaze-specified RGB value if current-pixel is in the time-domain wave's height
// Otherwise, it outputs a black pixel
//
// If the current pixel's y-coordinate is in the display's bottom-half, it will draw the frequency display
// It draws Picoblaze-specified RGB value if current-pixel is in the current bin's height
// Otherwise, it outputs a black pixel
//
////////////////////////////////////////////////////////////////////////////////////////////////////////

module ImgCtrl ( 

	/******************************************************************/
	/* Top-level port declarations                          		  */
	/******************************************************************/

	// Global signals

	input       		ck100MHz,           // 100MHz system clock from ClockWiz

	// Connections with AudioGen

	input        		weaTime,			// sampling frequency a.k.a. time-domain data enable signal (48kHz)
	input   [7:0]  		dinaTime,			// decoded time-sample data from PDM filter
	
	input				enaTime,			// port A enable for time buffer: FFT --> ImgCtrl
	input   [9:0]  		addraTime,			// time buffer address: FFT --> ImgCtrl
	input      			weaFreq,			// write enable for frequency buffer: FFT --> ImgCtrl
	input   [9:0]   	addraFreq,			// frequency buffer address: FFT --> ImgCtrl
	input   [7:0]   	dinaFreq,			// frequency power (bin height): FFT --> ImgCtrl

	// Connections with DTG

	input           	ckVideo,			// 25MHz clock for video timing signals from ClockWiz
	input           	flgActiveVideo,		// active-high flag if current pixel is in 512x480 display frame
	input   [9:0]  		adrHor,				// x-coordinate of current pixel
	input   [9:0]  		adrVer,				// y-coordinate of current pixel

	// Connections with VGA display

	output reg	[11:0]  OutputRGB,			// RGB values for VGA current pixel

	// Connections with Picoblaze

	input 		[11:0]	PicoblazeRGB);		// RGB values to use in FFT display

	/******************************************************************/
	/* Local parameters and variables                                 */
	/******************************************************************/

	// block RAM address for frequency-domain & time-domain buffers
	// current reading based on pixel x-coordinate value

	wire  [9:0]   		memAdrHor;

	// output data from block RAMs

	wire  [7:0]   		sampleDisplayTime;      // time-domain sample for display (decoded time-sample data from PDM filter)
	wire  [7:0]   		sampleDisplayFreq;      // freq domain sample for display (frequency power (bin height))
						
	// internal register to store RGB values before output

	reg  [11:0] 		intRGB;

	// internal signals for calculations

	wire 		[7:0]  FreqHeight;
	wire signed [7:0]  TimeHeight;

	// time data is signed (-128 : 128)
	// needs to be explicitly converted for calculations
	
	wire signed [7:0]  sampleDisplayTime_signed;

	/******************************************************************/
	/* Global Assignments							                  */
	/******************************************************************/

	// address for time-domain & frequency-domain buffers

	assign memAdrHor = (adrHor == 10'd799) ? (10'd0) : (adrHor + 1);

	// frequency data is unsigned (power reading)
	// just needs a 1'b0 prefix

	assign FreqHeight = {1'b0,sampleDisplayFreq[7:0]};
	
	// time data is signed (-128 : 128)
	// needs to be explicitly converted for calculations

	assign sampleDisplayTime_signed = sampleDisplayTime;
	assign TimeHeight = 10'sd120 - sampleDisplayTime_signed;

	/******************************************************************/
	/* Frequency Bars + Time Waveform Display block	                  */
	/******************************************************************/

	always@(posedge ckVideo) begin
		
 		// if (pixel in display top-half) && (pixel in time-domain wave height)

		if ((adrVer <= 10'd240) && (adrVer >= TimeHeight)) begin
			intRGB <= ~PicoblazeRGB;
		end

		// else if (pixel in display bottom-half) && (pixel in frequency-domain bar height)

		else if ((adrVer >= 10'd240) && (adrVer >= (10'd470 - FreqHeight))) begin
			intRGB <= PicoblazeRGB;
		end

		// otherwise, output black pixel

		else begin
			intRGB <= 12'h000;
		end
	end

  /******************************************************************/
  /* Outputting pixel RGB values                                    */
  /******************************************************************/

	always@(posedge ckVideo) begin

		// if current pixel is in 512x480 display frame --> output the calculated color

		if (flgActiveVideo == 1) begin
			OutputRGB <= intRGB;
		end

		// otherwise, output black

		else begin
			OutputRGB <= 12'h000; 	
		end
	end
				
  /******************************************************************/
  /* TimeBlkMemForDisplay instantiation                             */
  /******************************************************************/
  
	blk_mem_gen_0 TimeBlkMemForDisplay (

		.clka     (ck100MHz),                // I [ 0 ] 100MHz system clock from ClockWiz
		.ena      (enaTime),   		         // I [ 0 ] port A enable for time buffer: FFT --> ImgCtrl
		.wea      (weaTime),           	     // I [ 0 ] sampling frequency a.k.a. time-domain data enable signal (48kHz)
		.addra    (addraTime),               // I [9:0] time buffer address: FFT --> ImgCtrl
		.dina     (dinaTime),                // I [7:0] decoded time-sample data from PDM filter
		.clkb     (ckVideo),                 // I [ 0 ] 25MHz clock for video timing signals from ClockWiz
		.enb      (1'b1),                    // I [ 0 ] port B enable (always enabled)
		.addrb    (memAdrHor),               // I [9:0] address based on pixel x-coordinate
		.doutb    (sampleDisplayTime));      // O [7:0]	output byte for decoded time-sample data from PDM filter		

  /******************************************************************/
  /* FreqBlkMemForDisplay instantiation                             */
  /******************************************************************/

	blk_mem_gen_0 FreqBlkMemForDisplay (

		.clka     (ck100MHz),                // I [ 0 ] 100MHz system clock from ClockWiz
		.ena      (1'b1),                    // I [ 0 ] port A enable (always enabled)
		.wea      (weaFreq),                 // I [ 0 ] write enable for frequency buffer: FFT --> ImgCtrl
		.addra    (addraFreq),               // I [9:0] frequency buffer address: FFT --> ImgCtrl
		.dina     (dinaFreq),                // I [7:0] frequency power (bin height): FFT --> ImgCtrl
		.clkb     (ckVideo),                 // I [ 0 ] 25MHz clock for video timing signals from ClockWiz
		.enb      (1'b1),                    // I [ 0 ] port B enable (always enabled)
		.addrb    ({3'b0,memAdrHor[9:3]}),   // I [9:0] divide by 8 (display 640/8 = 80 points; point = 96kHz/512 = 187.5Hz)
		.doutb    (sampleDisplayFreq));      // O [7:0] freq domain sample for display (frequency power (bin height))

endmodule