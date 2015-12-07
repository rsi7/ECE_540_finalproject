// ImgCtrl.v - image controller
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

module ImgCtrl ( 

	/******************************************************************/
	/* Top-level port declarations                          		  */
	/******************************************************************/

	input       		ck100MHz,           // 100MHz clock from on-board oscillator

	// time domain data signals

	input				enaTime,
	input        		weaTime,
	input   [9:0]  		addraTime,
	input   [7:0]  		dinaTime,

	// frequency domain data signals

	input      			weaFreq,
	input   [9:0]   	addraFreq,
	input   [7:0]   	dinaFreq,

	// video signals

	input           	ckVideo,
	input           	flgActiveVideo,
	input   [9:0]  		adrHor,
	input   [9:0]  		adrVer,

	output reg	[3:0]   red,
	output reg	[3:0]   green,
	output reg	[3:0]  	blue);

	/******************************************************************/
	/* Local parameters and variables                                 */
	/******************************************************************/

	localparam      	cstHorSize = 800;
	localparam      	cstHorAl = 640;     // # of pixels: active line
	localparam      	cstHorFp = 16;      // # of pixels: front porch
	localparam      	cstHorPw = 96;      // # of pixels: pulse with
	localparam      	cstHorBp = 48;      // # of pixels: back porch

	localparam      	cstVerSize = 521;
	localparam      	cstVerAf = 480;     // # of lines: active frame
	localparam      	cstVerFp = 11;      // # of lines: front porch
	localparam      	cstVerPw = 2;       // # of lines: pulse with
	localparam      	cstVerBp = 31;      // # of lines: back porch

	wire  [7:0]   	sampleDisplayTime;      // time domain sample for display
	wire  [7:0]   	sampleDisplayFreq;      // freq domain sample for display
						
	// accessing RAM for pixel

	wire  [9:0]   memAdrHor;              // pixel column counter

	// connections for output VGA ports

	reg  [3:0]   intRed;
	reg  [3:0]   intGreen;
	reg  [3:0]   intBlue;

	// internal signals

	wire 		[7:0]  FreqHeight;
	wire signed [7:0]  TimeHeight;
	wire signed [7:0]  sampleDisplayTime_signed;

	assign memAdrHor = (adrHor == 10'd799) ? (10'd0) : (adrHor + 1);
	assign FreqHeight = {1'b0,sampleDisplayFreq[7:0]};

	assign sampleDisplayTime_signed = sampleDisplayTime;
	assign TimeHeight = 10'sd120 - sampleDisplayTime_signed;

	/******************************************************************/
	/* intRed block					                                  */
	/******************************************************************/
 
 	always@(posedge ckVideo) begin
		if ((adrVer <= 10'd240) && (adrVer >= TimeHeight))
			intRed <= 4'b1111;
		else begin
			intRed <= 4'b0000;
		end
	end

	/******************************************************************/
	/* intGreen block				                                  */
	/******************************************************************/

	always@(posedge ckVideo) begin
		if ((adrVer >= 10'd240) && (adrVer >= (10'd470 - FreqHeight))) begin
			intGreen <= 4'b1111;
		end
		else begin
			intGreen <= 4'b0000;
		end
	end

	/******************************************************************/
	/* intBlue block				                                  */
	/******************************************************************/

	always@(posedge ckVideo) begin
		intBlue = 4'b0000;
	end

  /******************************************************************/
  /* Outputting pixel RGB values                                    */
  /******************************************************************/

	always@(posedge ckVideo) begin
			
		if (flgActiveVideo == 1) begin
			red 	<= intRed;
			green 	<= intGreen;
			blue 	<= intBlue;
		end

		else begin
			red 	<= 4'b0000;
			green 	<= 4'b0000;		
			blue 	<= 4'b0000; 	
		end
	end
				
  /******************************************************************/
  /* TimeBlkMemForDisplay instantiation                             */
  /******************************************************************/
  
	blk_mem_gen_0 TimeBlkMemForDisplay (

		.clka     (ck100MHz),                // I [ 0 ]
		.ena      (enaTime),   		         // I [ 0 ]
		.wea      (weaTime),           	     // I [ 0 ]
		.addra    (addraTime),               // I [9:0]
		.dina     (dinaTime),                // I [7:0]
		.clkb     (ckVideo),                 // I [ 0 ]
		.enb      (1'b1),                    // I [ 0 ]
		.addrb    (memAdrHor),               // I [9:0]
		.doutb    (sampleDisplayTime));      // O [7:0]			

  /******************************************************************/
  /* FreqBlkMemForDisplay instantiation                             */
  /******************************************************************/

	blk_mem_gen_0 FreqBlkMemForDisplay (

		.clka     (ck100MHz),                // I [ 0 ]
		.ena      (1'b1),                    // I [ 0 ]
		.wea      (weaFreq),                 // I [ 0 ]
		.addra    (addraFreq),               // I [9:0]
		.dina     (dinaFreq),                // I [7:0]
		.clkb     (ckVideo),                 // I [ 0 ]
		.enb      (1'b1),                    // I [ 0 ]
		.addrb    ({3'b0,memAdrHor[9:3]}),   // I [9:0] divide by 8 (display 640/8 = 80 points; point = 96kHz/512 = 187.5Hz)
		.doutb    (sampleDisplayFreq));      // O [7:0]

endmodule