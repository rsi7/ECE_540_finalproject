// nexys_bot_if.v - interface block between the KCPSM6 and BotSim
//
// Description:
// ------------
// This module presents BotSim's location, sensor data, and distance counters
// to the KCPSM6 processor, and passes motor control (MotCtl) signals to the bot.
//
////////////////////////////////////////////////////////////////////////////////////////////////

`timescale  1 ns / 1 ns

module nexys_RGB_if #(

	/******************************************************************/
	/* Parameter declarations						                  */
	/******************************************************************/

	// Pushbutton

	parameter	PA_PBTNS 			= 8'h00, // (i) slide switches

	// Sevensegement display digits

	parameter 	PA_DIG7 			= 8'h01,
	parameter 	PA_DIG6 			= 8'h02,
	parameter 	PA_DIG5 			= 8'h03,
	parameter 	PA_DIG4 			= 8'h04,
	parameter 	PA_DIG3 			= 8'h05,
	parameter 	PA_DIG2 			= 8'h06,
	parameter 	PA_DIG1 			= 8'h07,
	parameter 	PA_DIG0 			= 8'h08,

	// FFT interface registers
	
	parameter	PA_PicoblazeRed    		=	8'h0A,		
	parameter	PA_PicoblazeGreen    	=	8'h0B,		
	parameter	PA_PicoblazeBlue    	=	8'h0C)		
	
	/******************************************************************/
	/* Port declarations							                  */
	/******************************************************************/

	(
	
	// Global signals from Nexys4

	input 				clk, 				// sysclock signal from Nexys4
	input 				reset,				// sysreset signal from Nexys4

	// Debounced pushbuttons
	
	input 	[5:0]		db_btns,			// debounce pushbutton input in from kcpsm6.v
	
	// Interface with sevensegment
	
	output	reg [4:0]	dig7,dig6,			// output for sevensegement display
						dig5,dig4,
						dig3,dig2,
						dig1,dig0,

	// RGB values for ImgCtrl
	
	output	reg	[11:0]	PicoblazeRGB,

	// Interface with KCPSM6

	input 		[7:0]	port_id,			// address of port id
						out_port,			// output from kcpm6.v and input for interface
	output 	reg	[7:0]	in_port,			// input from kcpsm6.v and output for interface
	input				k_write_strobe,		// input from kcpsm6.v and output for interface
						write_strobe,		// input from kcpsm6.v and output for interface
						read_strobe,		// input from kcpsm6.v and output for interface
						interrupt_ack,		// input from kcpsm6.v and output for interface
	output	reg			interrupt);			// input from kcpsm6.v and output for interface	

	/******************************************************************/
	/* Decoding pushbutton inputs from debounced signals           	  */
	/******************************************************************/

	wire 	btnCenter 	= db_btns[5];
	wire 	btnLeft 	= db_btns[4];
	wire 	btnUp 		= db_btns[3];
	wire 	btnRight 	= db_btns[2];
	wire 	btnDown 	= db_btns[1];

	reg 	[3:0]		PicoblazeRed;
	reg 	[3:0]		PicoblazeGreen;
	reg 	[3:0]		PicoblazeBlue;

	integer clk_cnt_2Hz;
	reg 	flag_2Hz;

	/******************************************************************/
	/* Servicing the KCPSM6 "READ" command		                  	  */
	/******************************************************************/
	
	always@(posedge clk) begin
		
		//  apply reset --> clear input data going to KCPSM6

		if (reset) begin
			in_port <= 8'b0;
		end

		// if active, decode "port_id" and place appropriate data on "in_port" to KCPSM6

		else begin
			
			case (port_id)
				PA_PBTNS: in_port <= {3'b000, btnCenter, btnLeft, btnUp, btnRight, btnDown};
			endcase
		end
	end
		
	/******************************************************************/
	/* Servicing the KCPSM6 "WRITE" command			                  */
	/******************************************************************/

	always@(posedge clk) begin

		//  apply reset --> clear output signals

		if (reset) begin		
			dig7 		<= 5'd0;
			dig6 		<= 5'd0;
			dig5 		<= 5'd0;
			dig4 		<= 5'd0;
			dig3 		<= 5'd0; 
			dig2 		<= 5'd0; 
			dig1 		<= 5'd0; 
			dig0 		<= 5'd0;
			PicoblazeRed 	<= 8'd0;
			PicoblazeBlue 	<= 8'd0;
			PicoblazeGreen 	<= 8'd0;
		end
		
		// check for "write_strobe" signals from KCPSM6
		// if applied, decode "port_id" and present data on "out_port" to appropriate peripheral

		else if (write_strobe || k_write_strobe) begin
				
			case (port_id)

				PA_DIG7: dig7 <= out_port[4:0];
				PA_DIG6: dig6 <= out_port[4:0];
				PA_DIG5: dig5 <= out_port[4:0];
				PA_DIG4: dig4 <= out_port[4:0];			
				PA_DIG3: dig3 <= out_port[4:0];			
				PA_DIG2: dig2 <= out_port[4:0];				
				PA_DIG1: dig1 <= out_port[4:0];				
				PA_DIG0: dig0 <= out_port[4:0];		
				PA_PicoblazeRed : PicoblazeRed <= out_port;
				PA_PicoblazeGreen : PicoblazeGreen <= out_port;
				PA_PicoblazeBlue : PicoblazeBlue <= out_port; 

			endcase
		end
	end

	/******************************************************************/
	/* Servicing the KCPSM6 interrupts				                  */
	/******************************************************************/

	always@(posedge clk) begin
		
		//  apply reset --> clear interrupt flag going to KCPSM6

		if (reset) begin
			interrupt <= 1'b0;
		end

		// check for "interrupt_ack" signal from KCPSM6
		// if active, clear interrupt flag for KCPSM6

		else if (interrupt_ack) begin
			interrupt <= 1'b0;
		end

		// check for 2_Hz flag
		// if active, set interrupt flag for KCPSM6

		else if (flag_2Hz) begin
			interrupt <= 1'b1;	
		end

		// otherwise, maintain interrupt status

		else begin
			interrupt <= interrupt;
		end

	end

	// procedural block to generate the 1 Hz flag
	// if 'reset' is active, clear the flag & counter
	// otherwise, if cycle completed ---> set the flag & reset counter
	// otherwise, keep the flag off & increment counter

	always @(posedge clk) begin
		if (reset) begin
			flag_2Hz <= 1'b0;
			clk_cnt_2Hz <= 0;
		end
		else if (clk_cnt_2Hz == 50000000) begin
			flag_2Hz <= 1'b1;
			clk_cnt_2Hz <= 0;
		end
		else begin
			flag_2Hz <= 1'b0;
			clk_cnt_2Hz <= clk_cnt_2Hz + 1'b1;
		end
	end

	/******************************************************************/
	/* Outputting the 12-bit RGB values			                  	  */
	/******************************************************************/

	always@(posedge clk) begin
		PicoblazeRGB <= {PicoblazeRed, PicoblazeGreen, PicoblazeBlue};
	end

endmodule