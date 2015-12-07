// audio_demo.v - audio controller
//
// Description:
// ------------
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

module audio_demo (

   /******************************************************************/
   /* Top-level port declarations                                    */
   /******************************************************************/

	input            	clk_i,
	input 				clk_6_144MHz,
	input 				clk_locked, 
	input             	rst_i,

   // PDM interface with Mic

	input             	pdm_data_i,
	output 	         	pdm_clk_o,
	output reg         	pdm_lrsel_o,

   // parallel data from mic

	output reg    		data_mic_valid,
	output reg 	[15:0]	data_mic);
				
   /******************************************************************/
   /* Local parameters and variables                                 */
   /******************************************************************/
   
	wire	[15:0]		data_int;
	wire    [16:0]  	pdm_acc;
	wire    [15:0]  	pdm_data;
	wire    			fs_int;
	wire       			fs_rise;
	wire				fs_comb;
	reg          		fs_tmp;
	reg					fss_tmp;
				
	integer     		cnt = 0;

   /******************************************************************/
   /* PDM instantiation                                              */
   /******************************************************************/

	pdm_filter PDM (

		// Global signals
				
		.clk_i         	(clk_i),               	// I [ 0 ] 100MHz system clock
		.clk_6_144MHz 	(clk_6_144MHz),			// I [ 0 ]
		.clk_locked		(clk_locked), 			// I [ 0 ]
		.rst_i         	(rst_i),               	// I [ 0 ] active-high system reset

		// PDM interface w/ microphone
				
		.pdm_clk_o     (pdm_clk_o),           // O [ 0 ]
		.pdm_data_i    (pdm_data_i),          // I [ 0 ]

		// output data to audio_demo

		.fs_o          (fs_int),              // O [ 0 ]
		.data_o        (data_int));           // O [15:0]	
	
   /******************************************************************/
   /* Synchronize signals from the PDM                               */
   /******************************************************************/
   
	always @(posedge clk_i) begin
		fs_tmp 	<= fs_int;
		fss_tmp <= fs_tmp;
	end

	/******************************************************************/
	/* Local parameters and variables				                  */
	/******************************************************************/

   	assign 	fs_rise =  fs_tmp ? (fss_tmp ? 1'b0: 1'b1) : (1'b0);
   
/*	always	@(posedge fs_int) begin
		if ((fs_tmp == 1) && (fss_tmp == 0)) begin	
			fs_rise <= 1'b1;
		end

		else begin	
			fs_rise <= 1'b0;
		end
	end	*/	


   	assign	fs_comb = cnt ? (fs_rise ? 1'b1 : 1'b0 ) : (1'b0);

/*	always@ (posedge clk_i) begin
		if ((cnt == 1) && (fs_rise == 1)) begin  
			fs_comb <= 1;
		end

		else begin
			fs_comb <= 0;
		end
	end*/	
	
   /******************************************************************/
   /* Divide the fs by two (48kHz sampling rate)                     */
   /******************************************************************/

	always @ (posedge clk_i) begin

		if (rst_i == 1) begin								// reset logic
			cnt <= 0;
		end

		else if ((fs_rise == 1) && (cnt >= 1)) begin
			cnt <= 0;
		end

		else begin	
			cnt <= cnt + 1;
		end
	end

   /******************************************************************/
   /* Registered outputs						                     */
   /******************************************************************/

	always @ (posedge clk_i) begin
		data_mic_valid 	<= fs_comb;
		data_mic 		<= data_int;
		pdm_lrsel_o 	<= 1'b1;
	end

endmodule