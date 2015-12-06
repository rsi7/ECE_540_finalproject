module pdm_filter (

	/******************************************************************/
	/* Top-level port declarations	   						          */
	/******************************************************************/

	input 	clk_i,             
	input	rst_i,

	// PDM interface to microphone

	output	reg		pdm_clk_o,         
	output 	reg		pdm_lrsel_o,       
	input 			pdm_data_i,      
      
	// output data
	
	output	reg					fs_o,              
	output	reg 	[15:0]		data_o);          

    //******************************************************************/
	//* Clock related wires					          	      		   */
	//******************************************************************/


			wire 					clk_3_072MHz ;
			wire 					clk_3_072MHz_int ;
			wire 					clk_6_144MHz_int ;
			wire 					clk_6_144MHz_div ;
			wire 					clk_locked ;

	//******************************************************************/
	//* CIC filter wires					          	      		   */
	//******************************************************************/
	
	
			wire 		[7:0]		s_cic_tdata ;		
			wire 		[23:0]		m_cic_tdata ;
			wire 					m_cic_tvalid ;

	
	//******************************************************************/
	//* High band pass filter related wires					           */
	//******************************************************************/
	
			wire 					m_hb_tvalid ;
			wire 					m_hb_tready ;
			wire		[23:0] 		m_hb_tdata ;
			
	
	//******************************************************************/
	//* Low band pass filter related wires					           */
	//******************************************************************/
	
	
			wire 					m_lp_tvalid ;
			wire 					m_lp_tready ;
			wire 		[23:0]		m_lp_tdata ;
			wire        [15:0]      data_w_o;


			
				
	//******************************************************************/
	//* module_instantiate									           */
	//******************************************************************/
	
	
	 //Sampling clock generator (3.072 MHz)
	 
			
			clk_gen  ClkGen(
   
					.clk_100MHz_i 		(clk_i),
					.clk_6_144MHz_o		(clk_6_144MHz_int),
					.rst_i 				(rst_i),
					.locked_o 			(clk_locked)
	  
					);
   
	
	
	//Dividing by 2 the 6.144 MHz clock
   
			BUFR  #(
      
					.BUFR_DIVIDE		(2),
					.SIM_DEVICE			("7SERIES"))
  
			ClkDiv2 (
					
					.O					( clk_6_144MHz_div),
					.CE					(1),
					.CLR 				(0),
					.I					(clk_6_144MHz_int));
					
					
   
   // Buffering the divided clock (3.072 MHz)
   
   
			BUFG ClkDivBuf(
      
	  
					.O					(clk_3_072MHz_int),
					.I 					(clk_6_144MHz_div));
					
		
		
		// Outputing the microphone clock
 
  
			assign 		clk_3_072MHz	= clk_locked ? clk_3_072MHz_int : 1'b1 ; 			//(  clk_3_072MHz <= clk_3_072MHz_int when clk_locked = '1' else '1';)
		
		
			
			always @(posedge clk_i) begin
		
					pdm_clk_o 		<= clk_3_072MHz;
	
					pdm_lrsel_o 	<= 1'b0;
				
					fs_o 			<= 	m_lp_tvalid;
					
					data_o          <=  data_w_o;
			end
		
		
		
	
		
		
		
			assign 		s_cic_tdata [7:1] 	= { 7 {! pdm_data_i} } ;							//s_cic_tdata(7 downto 1) <= (others => (not pdm_data_i));
		
			assign 		s_cic_tdata [0] 	= 1'b1 ;
   
   //First stage: CIC decimator.
   // This filter downsample's the incomming 3.072 MHz signal to 192 kHz.
		
		
	cic  CIC(
  
				.aclk 					(clk_3_072MHz),
				.s_axis_data_tdata 		(s_cic_tdata),
				.s_axis_data_tvalid 	(1),
				.s_axis_data_tready 	(	),
				.m_axis_data_tdata 		(m_cic_tdata),
				.m_axis_data_tvalid 	(m_cic_tvalid));
   
   
   
   
   hb_fir HB(
   
				.aclk 					(clk_3_072MHz),
				.s_axis_data_tvalid 	(m_cic_tvalid),
				.s_axis_data_tready 	(	),
				.s_axis_data_tdata 		(m_cic_tdata),
				.m_axis_data_tvalid 	(m_hb_tvalid),
				.m_axis_data_tready 	(m_hb_tready),
				.m_axis_data_tdata 		(m_hb_tdata));
   
  
  lp_fir  LP(
      
	  
				.aclk					( clk_3_072MHz),
				.s_axis_data_tvalid 	( m_hb_tvalid),
				.s_axis_data_tready		(m_hb_tready),
				.s_axis_data_tdata    	(m_hb_tdata),
				.m_axis_data_tvalid   	(m_lp_tvalid),
				.m_axis_data_tdata    	(m_lp_tdata));
   
	//Fourth stage: First order highpass filter, used for removing any 
	// DC component.
   hp_rc HP(
   
   
				.clk_i                (clk_3_072MHz),
				.rst_i                (rst_i),
				.en_i                 (m_lp_tvalid),
				.data_i               (m_lp_tdata [16:1]),
				.data_o               (data_w_o));
   
   
		
		


endmodule