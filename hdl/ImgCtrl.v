// ImgCtrl.v - image controller
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

module ImgCtrl #(
				
				parameter				cstHorSize 	= 800,
				parameter				cstVerAf	= 480 
					

)(

  /******************************************************************/
  /* Top-level port declarations                            */
  /******************************************************************/

				input       				ck100MHz,           // 100MHz clock from on-board oscillator

		// time domain data signals

				input						enaTime,
				input           			weaTime,
				input   		[9:0]   	addraTime,
				input   		[7:0]   	dinaTime,

		
		// frequency domain data signals

				
				input           			weaFreq,
				input   		[9:0]   	addraFreq,
				input   		[7:0]   	dinaFreq,

		
		// video signals

				input           			ckVideo,
				input           			flgActiveVideo,
				input   		[9:0]  		adrHor,
				input   		[9:0]  		adrVer,
				
				output  reg		[3:0]   	red,
				output  reg		[3:0]   	green,
				output  reg		[3:0]  		blue );

				
  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

				wire  			[7:0]   sampleDisplayTime;      // time domain sample for display
				wire  			[7:0]   sampleDisplayFreq;      // freq domain sample for display
				
				
		//counters for pxel
		
		
				wire  			[9:0]   vecadrHor;              // pixel column counter
				wire  			[9:0]   vecadrVer;              // pixel row counter

		// connections for output VGA ports

				wire  			[3:0]   intRed;
				wire  			[3:0]   intGreen;
				wire  			[3:0]   intBlue;
				
				wire 			[9:0]	temp2 	= 	cstVerAf/2;
				wire 			[9:0]	temp4 	= 	cstVerAf/4;
				wire 			[9:0]	temp8 	= 	cstVerAf/8;
				
				wire 			[9:0]	temp_m 	= 	cstVerAf* 47/48;
				
				wire 			[9:0]	temp_intGreen	=	temp_m - {1'b0, sampleDisplayFreq [7:0]} ;
				
				
				
				wire			[9:0]	temp_adrHor		= ((adrHor == 1*48) ||  (adrHor == 2*48) ||  (adrHor == 3*48) ||  (adrHor == 4*48) ||  
													
															(adrHor == 5*48) ||   (adrHor == 6*48) ||  (adrHor == 7*48) ||   (adrHor == 8*48) ||  
								
															((adrHor >=  9*48) &&  (adrHor <= 10*48)) ||  
														
															(adrHor == 11*48) ||  (adrHor == 12*48) ||  (adrHor == 13*48)) ; 
														
				
				wire			[9:0] 	temp_adrHor1 	=	temp_intGreen && (  adrHor/8 == 0 ||  adrHor/8 == 10 ||  
				
														adrHor/8 == 20 ||  adrHor/8 == 30 ||  adrHor/8 == 40 ||  
														
														adrHor/8 == 50 ||  adrHor/8 == 60 ||  adrHor/8 == 70);
														
														
				wire			[9:0]	temp_adrVer1	=	cstVerAf*23/48;
				wire			[9:0]	temp_adrVer2	=	cstVerAf*24/48;
				
				
											

				
				
				
				assign	vecadrHor = (adrHor == cstHorSize - 1) ? {10 { 1'b0 }} : { adrHor + 1} ;
				assign 	vecadrVer = adrVer ;
				
				assign 	intRed 	 = (adrVer <= temp2) ? ((adrVer >= (temp4 -sampleDisplayTime)) ? 4'b1111: 4'b0000) : (4'b0000);
				
				
				assign	intGreen = (adrVer >=  temp_intGreen ) ? 4'b1111: 4'b0000;
				
				assign	intBlue	=	temp_adrHor1  ? (4'b1111) : (( (adrVer >= temp_adrVer1 ) && (adrVer < temp_adrVer2) &&  temp_adrHor) ? 4'b1111: 4'b0000) ; 
 
 
  /******************************************************************/
  /* always block                                                  */
  /******************************************************************/
				
			
				always@ (posedge ck100MHz) begin
						
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
						.ena      (enaTime),                 // I [ 0 ]
						.wea      (weaTime),                 // I [ 0 ]
						.addra    (addraTime),               // I [9:0]
						.dina     (dinaTime),                // I [7:0]
						.clkb     (ckVideo),                 // I [ 0 ]
						.enb      (1'b1),                    // I [ 0 ]
						.addrb    (vecadrHor),               // I [9:0]
						.doutb    (sampleDisplayTime));      // I [7:0]
						
						

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
					.addrb    ({3'b0,vecadrHor[9:3]}),   // I [9:0] divide by 8 (display 640/8 = 80 points; point = 96kHz/512 = 187.5Hz)
					.doutb    (sampleDisplayFreq));      // I [7:0]
					
					

				
				
 
  
endmodule
