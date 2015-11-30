// audio_gen.v --> simple one line description of module
//
// Description:
// ------------
// Give a longer, paragraph description here.
//
////////////////////////////////////////////////////////////////////////////////////////////////

module audio_gen #(


	/******************************************************************/
	/* Parameter declarations						                  */
	/******************************************************************/
	
			parameter			left_audio		= 	1'b0,
			parameter			right_audio		=	1'b1,
			parameter			one				=	1,
			parameter			zero			=	0,
			parameter			clock_devider 	=	4'b1111				// clock_devider to generte  (100 / (16*2)) 3.1 Mhz
			




)(
	/******************************************************************/
	/* Port declarations							                  */
	/******************************************************************/

			
			input						reset,							//  system reset
			input						clock,							//	system clock 100 Mhz
			input						mic_in_pdm,						//	output of mic in form of PDM
			output 		reg				clock_pdm,						// 	pdm clock for sampling mic input
			output		reg				sel_LR,							// select left or right channel
			output		reg				pdm_out							// PDM output


);


			reg		[3:0]				pdm_reg_clk;
			
			
	/******************************************************************/
	/* Generate mic clock							                  */
	/******************************************************************/
always @(posedge clock) begin
		
		
		if (reset) begin
		
				pdm_reg_clk		<= 4'b0000;
				clock_pdm		<= zero;
		
		end
		
		else if (pdm_reg_clk == clock_devider) begin
		
				pdm_reg_clk 	<= one;
				clock_pdm		<= ~ clock_pdm;
		end
		
		else begin
			
				pdm_reg_clk 	<= pdm_reg_clk + 1;
		   
		
		end
	end 
	
	/******************************************************************/
	/* getting data from mic						                  */
	/******************************************************************/

always @(posedge clock) begin

		sel_LR			<= 	left_audio;
		
		if (reset) begin
		
					
				pdm_out			<=	mic_in_pdm;
		
		
		end
		
		else if (pdm_reg_clk == clock_devider)begin
				
				pdm_out			<=	mic_in_pdm;
				
		
		end

end

endmodule

