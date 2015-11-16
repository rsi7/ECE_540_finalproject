// nexys_bot_if.v - interface block between the KCPSM6 and BotSim
//
// Description:
// ------------
// This module presents BotSim's location, sensor data, and distance counters
// to the KCPSM6 processor, and passes motor control (MotCtl) signals to the bot.
//
////////////////////////////////////////////////////////////////////////////////////////////////

`timescale  1 ns / 1 ns

module nexys_bot_if #(

	/******************************************************************/
	/* Parameter declarations						                  */
	/******************************************************************/

	parameter	PA_PBTNS 			=	8'h00,		// (i) pushbuttons inputs
	parameter	PA_SLSWTCH			=	8'h01,		// (i) slide switches
	parameter	PA_LEDS				=	8'h02,		// (o) LEDs
	parameter	PA_DIG3				=	8'h03,		// (o) digit 3 port address
	parameter	PA_DIG2				=	8'h04,		// (o) digit 2 port address
	parameter	PA_DIG1    			=	8'h05,		// (o) digit 1 port address
	parameter	PA_DIG0    			=	8'h06,		// (o) digit 0 port address
	parameter	PA_DP    			=	8'h07,		// (o) decimal points 3:0 port address
	parameter	PA_RSVD    			=	8'h08,		// (o) *RESERVED* port address

	// Rojobot interface registers

	parameter	PA_MOTCTL_IN    	=	8'h09,		// (o) Rojobot motor control output from system
	parameter	PA_LOCX    			=	8'h0A,		// (i) X coordinate of rojobot location
	parameter	PA_LOCY    			=	8'h0B,		// (i) Y coordinate of rojobot location
	parameter	PA_BOTINFO    		=	8'h0C,		// (i) Rojobot info register
	parameter	PA_SENSORS    		=	8'h0D,		// (i) Sensor register
	parameter	PA_LMDIST    		=	8'h0E,		// (i) Rojobot left motor distance register
	parameter	PA_RMDIST    		=	8'h0F,		// (i) Rojobot right motor distance register

	// Extended I/O interface port addresses for the Nexys4.  Your Nexys4_Bot interface module
	// should include these additional ports even though they are not used in this program

	parameter	PA_PBTNS_ALT    	=	8'h10,		// (i) pushbutton inputs alternate port address
	parameter	PA_SLSWTCH1508  	=	8'h11,		// (i) slide switches 15:8 (high byte of switches
	parameter	PA_LEDS1508    		=	8'h12,		// (o) LEDs 15:8 (high byte of switches)
	parameter	PA_DIG7    			=	8'h13,		// (o) digit 7 port address
	parameter	PA_DIG6    			=	8'h14,		// (o) digit 6 port  address
	parameter	PA_DIG5    			=	8'h15,		// (o) digit 5 port address
	parameter	PA_DIG4    			=	8'h16,		// (o) digit 4 port address
	parameter	PA_DP0704    		=	8'h17,		// (o) decimal points 7:4 port address
	parameter	PA_RSVD_ALT    		=	8'h18,		// (o) *RESERVED* alternate port address

	// Extended Rojobot interface registers.  These are alternate Port addresses

	parameter	PA_MOTCTL_IN_ALT    =	8'h19,		// (o) Rojobot motor control output from system
	parameter	PA_LOCX_ALT    		=	8'h1A,		// (i) X coordinate of rojobot location
	parameter	PA_LOCY_ALT    		=	8'h1B,		// (i))Y coordinate of rojobot location
	parameter	PA_BOTINFO_ALT    	=	8'h1C,		// (i) Rojobot info register
	parameter	PA_SENSORS_ALT    	=	8'h1D,		// (i) Sensor register
	parameter	PA_LMDIST_ALT    	=	8'h1E,		// (i) Rojobot left motor distance register
	parameter	PA_RMDIST_ALT    	=	8'h1F)		// (i) Rojobot right motor distance register

	/******************************************************************/
	/* Port declarations							                  */
	/******************************************************************/

	// system interface registers from Bot.v
	(
	output 	reg [7:0]	MotCtl,				// Motor control input	
	input		[7:0] 	LocX,				// X-coordinate of rojobot's location		
						LocY,				// Y-coordinate of rojobot's location
						Sensors,			// Sensor readings
						botInfo,			// Information about rojobot's activity
						lmdist,				// left motor distance register
						rmdist,				// right motor distance register
							
	input				upd_sysregs,		// update system register
	
	//system interface with kcpsm6.v

	input 		[7:0]	port_id,			// address of port id
						out_port,			// output from kcpm6.v and input for interface
	output 	reg	[7:0]	in_port,			// input from kcpsm6.v and output for interface
	input				k_write_strobe,		// input from kcpsm6.v and output for interface
						write_strobe,		// input from kcpsm6.v and output for interface
						read_strobe,		// input from kcpsm6.v and output for interface
						interrupt_ack,		// input from kcpsm6.v and output for interface
	output	reg			interrupt,			// input from kcpsm6.v and output for interface
							
	//sytem interface with debounce.v
	
	input 	[5:0]		db_btns,			// debounce pushbutton input in from kcpsm6.v
	input	[15:0]		db_sw,				// debounce slide switch input from kcpsm6.v
	
	//system interface with sevensegement.v
	
	output	reg [4:0]	dig7,dig6,			// output for sevensegement display
						dig5,dig4,
						dig3,dig2,
						dig1,dig0,

	output	reg [7:0]	dp,					// decimal output for sevensegement
	output	reg [15:0]	led,				// output for green LEDs
	
	//system interface with Nexys4

	input 	clk, 							// sysclock signal from Nexys4
	input 	reset);							// sysreset signal from Nexys4

	/******************************************************************/
	/* Decoding pushbutton inputs from debounced signals           	  */
	/******************************************************************/

	wire BtnCenter 	= db_btns[5];
	wire BtnLeft 	= db_btns[4];
	wire BtnUp 		= db_btns[3];
	wire BtnRight 	= db_btns[2];
	wire BtnDown 	= db_btns[1];

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
		
				PA_PBTNS: begin
						in_port <= {3'b000, BtnCenter, BtnLeft, BtnUp, BtnRight, BtnDown};
					end
			
				PA_SLSWTCH: begin
						in_port <= db_sw[7:0];
					end
			
				PA_LOCX: begin
						in_port <= LocX;
					end
				
				PA_LOCY: begin
						in_port <= LocY;
					end
				
				PA_BOTINFO: begin
						in_port <= botInfo;
					end
				
				PA_SENSORS: begin
						in_port <= Sensors;
					end
			
				PA_LMDIST: begin
						in_port <= lmdist;
					end
			
				PA_RMDIST: begin
						in_port <= rmdist;
					end
			
				default: begin
						in_port <= 8'bXXXXXXXX;
					end
				
			endcase
		end
	end
		
	/******************************************************************/
	/* Servicing the KCPSM6 "WRITE" command			                  */
	/******************************************************************/

	always@(posedge clk) begin

		//  apply reset --> clear output signals going to LEDs, sevensegment, and motor

		if (reset) begin		
			led  <= 16'd0;
			dig7 <= 5'd0;
			dig6 <= 5'd0;
			dig5 <= 5'd0;
			dig4 <= 5'd0;
			dig3 <= 5'd0; 
			dig2 <= 5'd0; 
			dig1 <= 5'd0; 
			dig0 <= 5'd0;
			MotCtl <= 8'd0;
		end
		
		// check for "write_strobe" signals from KCPSM6
		// if applied, decode "port_id" and present data on "out_port" to appropriate peripheral

		else if (write_strobe || k_write_strobe) begin
				
			case (port_id)
		
				PA_LEDS: begin
						led [7:0] <= out_port;
					end

				PA_DIG7: begin
						dig7 <= out_port[4:0];
					end

				PA_DIG6: begin
						dig6 <= out_port[4:0];
					end

				PA_DIG5: begin
						dig5 <= out_port[4:0];
					end

				PA_DIG4: begin
						dig4 <= out_port[4:0];
					end
			
				PA_DIG3: begin
						dig3 <= out_port[4:0];
					end
			
				PA_DIG2: begin
						dig2 <= out_port[4:0];
					end
				
				PA_DIG1: begin
						dig1 <= out_port[4:0];
					end
				
				PA_DIG0: begin
						dig0 <= out_port[4:0];
					end
				
				PA_DP: begin
						dp <= out_port;
					end
					
				PA_MOTCTL_IN: begin
						MotCtl <= out_port;
						led[15:8] <= out_port;			// used for debugging MotCtl signal
					end
			
				default: begin
						led  <= led;
						dig7 <= dig7;
						dig6 <= dig6;
						dig5 <= dig5;
						dig4 <= dig4;
						dig3 <= dig3;
						dig2 <= dig2;
						dig1 <= dig1;
						dig0 <= dig0;
						MotCtl <= MotCtl;
					end
					
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

		// check for "upd_sysreg" signal from BotSim
		// if active, set interrupt flag for KCPSM6

		else if (upd_sysregs) begin
			interrupt <= 1'b1;	
		end

		// otherwise, maintain interrupt status

		else begin
			interrupt <= interrupt;
		end

	end

endmodule