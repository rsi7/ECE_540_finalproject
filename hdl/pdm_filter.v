// pdm_filter.v - module for decoding & filtering microphone data
//
// Description:
// 
// This module decodes the pulse-density modulated (PDM) data from
// analog-to-digital converter on Nexys4DDR board. It then passes the
// data through a series of 4 filters: CIC, halfband, lowpass, highpass
//
// It is heavily based Mihaita Nagy's "pdm_filter.vhd" module
// Most of the filters can be generated from Vivado FIR & CIC Compiler tools in the IP Catalog
//
// The module samples input data at 3.072MHz and outputs 16-bit samples at 96kHz
//
////////////////////////////////////////////////////////////////////////////////////////////////

module pdm_filter (

	/******************************************************************/
	/* Top-level port declarations	   						          */
	/******************************************************************/

	// Global signals

	input 				clk_i,				// 100MHz system clock from ClockWiz
	input 				clk_6_144MHz,		// 6.144MHz clock from ClockWiz
	input 				clk_locked,        	// active-high flag indicating clock is stable
	input				rst_i,				// active-high reset for module

	// Connections with board's analog-to-digital converter

	output 				pdm_clk_o,       	// 3MHz clock needed by the on-board ADC
	input 				pdm_data_i,      	// pulse-density modulated data coming from ADC
      
	// Connections with AudioGen
	
	output reg			fs_o,              // sampling frequency from lowpass filter
	output reg 	[15:0]	data_o);           // output data from lowpass filter

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
	//* 3.072MHz Clock Generator							           */
	//******************************************************************/

	// Use built-in BUFR device to divide 6.144MHz clock --> 3.072MHz clock
	// because ClockWiz cannot generate lower than 4MHz

	BUFR  #(

		.BUFR_DIVIDE	(2),
		.SIM_DEVICE		("7SERIES"))

	ClkDivideBy2 (

		.I			(clk_6_144MHz),
		.CE			(1'b1),
		.CLR 		(1'b0),
		.O			(clk_3_072MHz));
   
   // Buffering the 3.072MHz clock
   
	BUFG ClkDivBuf(

		.I 			(clk_3_072MHz),
		.O			(clk_3_072MHz_buf));
					
	/******************************************************************/
	/* Global Assignments							                  */
	/******************************************************************/

	// Outputing the 3.072MHz clock to the analog-to-digital converter
  
	assign pdm_clk_o = clk_locked ? clk_3_072MHz_buf : 1'b1;

	// Giving pulse-density modulated input data from ADC to the CIC filter

	assign 	s_cic_tdata = {{7{!pdm_data_i}}, 1'b1};

	/******************************************************************/
	/* CIC instantiation		 	          	                      */
	/******************************************************************/

	// Cascaded-Integrator-Comb (CIC) filter which downsamples the incoming 3.072MHz signal to 192kHz
   	// cic.vhd module generated from Vivado CIC Compiler 3.0
   	// N = 5, R = 8, M = 1

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
   
   	// halfband FIR filter with decimation ratio = 2 and fs = 192kHz
   	// further downsamples the data to 96kHz output sample rate
   	// hb_fir.vhd module generated from Vivado FIR Compiler 6.3
   	// uses hb_fir.mif for initialization

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

   	// lowpass FIR filter with no decimation and fs = 96kHz
   	// lp_fir.vhd module generated from Vivado FIR Compiler 6.3
   	// uses lp_fir.mif for initialization

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

	// highpass filter 
	// hp_rc.vhd module by Mihaita Nagy (Digilent)
	// Based on Xilinx's WP279, this module models a first-order highpass RC filter

	hp_rc HP(
   
		.clk_i                	(clk_3_072MHz_buf),
		.rst_i                	(rst_i),
		.en_i                 	(m_lp_tvalid),
		.data_i               	(m_lp_tdata[16:1]),
		.data_o               	(data_o_HP));

	/******************************************************************/
	/* Synchronizing data from 3MHz filters and registering outputs   */
	/******************************************************************/

	always @(posedge clk_i) begin

		// synchronizing the sampling frequency output

		fs_o_temp <= m_lp_tvalid;
		fs_o <= fs_o_temp;

		// synchronizing the filtered time-domain data

		data_o_temp <= data_o_HP;
		data_o <= data_o_temp;
	end

endmodule