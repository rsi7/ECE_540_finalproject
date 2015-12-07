module pdm_filter (

	/******************************************************************/
	/* Top-level port declarations	   						          */
	/******************************************************************/

	input 				clk_i,
	input 				clk_6_144MHz,
	input 				clk_locked,             
	input				rst_i,

	// PDM interface to microphone

	output 				pdm_clk_o,         
	input 				pdm_data_i,      
      
	// output data
	
	output reg			fs_o,              
	output reg 	[15:0]	data_o);          

	/******************************************************************/
	/* Local parameters and variables				                  */
	/******************************************************************/

	wire				clk_3_072MHz;
	wire 				clk_3_072MHz_buf;

	// CIC filter signals
	
	wire 	[7:0]		s_cic_tdata;		
	wire 	[23:0]		m_cic_tdata;
	wire 				m_cic_tvalid;

	// halfband filter signals

	wire 				m_hb_tvalid ;
	wire 				m_hb_tready ;
	wire	[23:0] 		m_hb_tdata ;
			
	// lowpass filter signals
	
	wire 				m_lp_tvalid ;
	wire 				m_lp_tready ;
	wire 	[23:0]		m_lp_tdata ;

	// highpass filter signals

	wire 	[15:0]			data_o_HP;

	// synchronizer registers
	
	reg 					fs_o_temp;
	reg 	[15:0]			data_o_temp;	
				
	//******************************************************************/
	//* ClockWiz6MHz instantiation							           */
	//******************************************************************/
	
/*	 //Sampling clock generator (3.072 MHz)

	clk_wiz_0 ClockWiz6MHz (

		// Clock Input ports
		.clk_in1	(clk_i),				// Give ClockWiz the 100MHz crystal oscillator signal

		// Clock Output ports
		.clk_out1	(clk_6_144MHz),			// Generate 6.144MHz clock to use

		// Status and control signals
		.reset 		(1'b0),					// active-high reset for the clock generator
		.locked 	(clk_locked));			// set high when output clocks have correct frequency & phase*/
	
	//******************************************************************/
	//* 3.072MHz clock generation							           */
	//******************************************************************/

	BUFR  #(

		.BUFR_DIVIDE	(2),
		.SIM_DEVICE		("7SERIES"))

	ClkDivideBy2 (

		.I			(clk_6_144MHz),
		.CE			(1'b1),
		.CLR 		(1'b0),
		.O			(clk_3_072MHz));
   
   // Buffering the divided clock (3.072 MHz)
   
	BUFG ClkDivBuf(

		.I 			(clk_3_072MHz),
		.O			(clk_3_072MHz_buf));
					
	// Outputing the microphone clock
  
	assign pdm_clk_o = clk_locked ? clk_3_072MHz_buf : 1'b1;

   	/******************************************************************/
	/* Send input data from PDM to CIC filter		                  */
	/******************************************************************/

   	assign 	s_cic_tdata = {{7{!pdm_data_i}}, 1'b1};

	/******************************************************************/
	/* CIC instantiation		 	          	                      */
	/******************************************************************/

   // This filter downsamples the incoming 3.072MHz signal to 192kHz.
			
	cic CIC(
  
		.aclk 					(clk_3_072MHz_buf),
		.s_axis_data_tdata 		(s_cic_tdata),
		.s_axis_data_tvalid 	(1'b1),
		.s_axis_data_tready 	(	 ),
		.m_axis_data_tdata 		(m_cic_tdata),
		.m_axis_data_tvalid 	(m_cic_tvalid));

	/******************************************************************/
	/* Halfband instantiation	 	          	                      */
	/******************************************************************/
   
   hb_fir HB(
   
		.aclk 					(clk_3_072MHz_buf),
		.s_axis_data_tvalid 	(m_cic_tvalid),
		.s_axis_data_tready 	(	 ),
		.s_axis_data_tdata 		(m_cic_tdata),
		.m_axis_data_tvalid 	(m_hb_tvalid),
		.m_axis_data_tready 	(m_hb_tready),
		.m_axis_data_tdata 		(m_hb_tdata));

	/******************************************************************/
	/* Lowpass instantiation	 	          	                      */
	/******************************************************************/

	lp_fir  LP(
      
		.aclk					(clk_3_072MHz_buf),
		.s_axis_data_tvalid 	(m_hb_tvalid),
		.s_axis_data_tready		(m_hb_tready),
		.s_axis_data_tdata    	(m_hb_tdata),
		.m_axis_data_tvalid   	(m_lp_tvalid),
		.m_axis_data_tdata    	(m_lp_tdata));
   

	/******************************************************************/
	/* Highpass instantiation	 	          	                      */
	/******************************************************************/

   hp_rc HP(
   
		.clk_i                	(clk_3_072MHz_buf),
		.rst_i                	(rst_i),
		.en_i                 	(m_lp_tvalid),
		.data_i               	(m_lp_tdata[16:1]),
		.data_o               	(data_o_HP));

	/******************************************************************/
	/* Synchronizing data from filters and registering outputs        */
	/******************************************************************/

	always @(posedge clk_i) begin
		fs_o_temp <= m_lp_tvalid;
		fs_o <= fs_o_temp;

		data_o_temp <= data_o_HP;
		data_o <= data_o_temp;
	end

endmodule