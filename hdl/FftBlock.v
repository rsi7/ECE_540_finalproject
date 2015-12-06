// FftBlock.v - 
//
// Description:
// ------------
// 
//
////////////////////////////////////////////////////////////////////////////////////////////////

module FftBlock (

  /******************************************************************/
  /* Top-level port declarations                                    */
  /******************************************************************/

  input           flgStartAcquisition,
  input           btnL,
  input   [2:0]   sw,
  input           ckaTime,
  output          enaTime,
  output          weaTime,
  output  [9:0]   addraTime,
  input   [7:0]   dinaTime,
  input           ckFreq,
  output          flgFreqSampleValid,
  output  [9:0]   addrFreq,
  output  [7:0]   byteFreqSample);

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  // internal signals

  wire            intEnaTime;
  wire            intWeaTime;             // does this get assigned anywhere?
  reg    [10:0]   intAddraTime;

  // xfft_1 signals

  reg             aresetn;                              // reset signal (set by FSM)
  localparam      s_axis_config_tdata = 8'b00000000;    // config data
  localparam      s_axis_config_tvalid = 1'b1;          // input flag for FFT (config data always valid) 
  wire            s_axis_config_tready;                 // output flag from FFT
  wire    [15:0]  s_axis_data_tdata;                    // might need to register this
  wire    [7:0]   s_axis_data_tbyte;                    // output data from TimeBlkMemForFft
  localparam      s_axis_data_tvalid = 1'b1;            // input flag for FFT (debug always valid)
  wire            s_axis_data_tready;                   // output flag from FFT
  reg             s_axis_data_tlast;                    // input flag to FFT (set by FSM)
  wire    [47:0]  m_axis_data_tdata;                    // output data from FFT
// wire    [7:0]   m_axis_data_tbyte;                    // a byte of 'm_axis_data_tdata' (unused)
// wire            m_axis_data_tvalid;                   // output flag from FFT (unused)
  localparam      m_axis_data_tready = 1'b1;            // always ready to get frequency samples
  wire            m_axis_data_tlast;                    // output data from FFT
// wire            event_frame_started;                 // event ouput from FFT (unused)
// wire            event_tlast_unexpected;              // event ouput from FFT (unused)
// wire            event_tlast_missing;                 // event ouput from FFT (unused)
// wire            event_status_channel_halt;           // event ouput from FFT (unused)
// wire            event_data_in_channel_halt;          // event ouput from FFT (unused)
// wire            event_data_out_channel_halt;         // event ouput from FFT (unused)

  // AXI state machine signals

  localparam stRes0 	= 4'b0001;
  localparam stRes1 	= 4'b0010;
  localparam stConfig = 4'b0100;
  localparam stIdle 	= 4'b1000;

  reg   [4:0]     stAxiLoadNext;
  reg 	[4:0]     stAxiLoadCur;
   
  // time acquisition signals

  reg   [7:0]     oldDinaTime;      // previous time sample (for edge detection)
  reg             flgReset;         // reset for time acquisition counter (includes edge sync)

  // load & unload counter signals

  reg   [9:0]     cntFftLoadTime;       
  reg   [9:0]     cntFftUnloadFreq;
  reg             flgCountLoad;           // active while counting
//reg            cenLoadCounter;         // count enable for Load counter
//reg            cenUnloadCounter;       // count enable for Unload counter

  // 18x18 bit multiplication for signal power

  wire    [35:0]  m_axis_data_tpower;     // 18x18 bit multiplication

  /******************************************************************/
  /* TimeBlkMemForFft instantiation                                 */
  /******************************************************************/

  blk_mem_gen_0 TimeBlkMemForFft (

    .clka     (ckaTime),              // I [ 0 ]
    .ena      (intEnaTime),           // I [ 0 ]
    .wea      (intWeaTime),           // I [ 0 ]
    .addra    (intAddraTime[9:0]),    // I [9:0]
    .dina     (dinaTime),             // I [7:0]
    .clkb     (ckaTime),              // I [ 0 ]
    .enb      (1'b1),                 // I [ 0 ]
    .addrb    (cntFftLoadTime),       // I [9:0]
    .doutb    (s_axis_data_tbyte));   // O [7:0]

  /******************************************************************/
  /* FftInst instantiation                                          */
  /******************************************************************/

  xfft_1 FftInst (
    
    .aclk                           (ckaTime),                          // I [ 0 ]
    .aresetn                        (aresetn),                          // I [ 0 ]
    .s_axis_config_tdata            (s_axis_config_tdata),              // I [7:0]
    .s_axis_config_tvalid           (s_axis_config_tvalid),             // I [ 0 ]
    .s_axis_config_tready           (s_axis_config_tready),             // O [ 0 ]
    .s_axis_data_tdata              (s_axis_data_tdata),                // I [15:0]
    .s_axis_data_tvalid             (s_axis_data_tvalid),               // I [ 0 ]
    .s_axis_data_tready             (s_axis_data_tready),               // O [ 0 ]
    .s_axis_data_tlast              (s_axis_data_tlast),                // I [ 0 ]
    .m_axis_data_tdata              (m_axis_data_tdata),                // O [47:0]
    .m_axis_data_tvalid             (flgFreqSampleValid),               // O [ 0 ]
    .m_axis_data_tready             (m_axis_data_tready),               // I [ 0 ]
    .m_axis_data_tlast              (m_axis_data_tlast),                // O [ 0 ]
    .event_frame_started            (     ),                            // O [ 0 ]
    .event_tlast_unexpected         (     ),                            // O [ 0 ]
    .event_tlast_missing            (     ),                            // O [ 0 ]
    .event_status_channel_halt      (     ),                            // O [ 0 ]
    .event_data_in_channel_halt     (     ),                            // O [ 0 ]
    .event_data_out_channel_halt    (     ));                           // O [ 0 ]

  /******************************************************************/
  /* Output registers block                                         */
  /******************************************************************/

  always@posedge(ckaTime) begin
  	enaTime <= intEnaTime;
  	weaTime <= intWeaTime;
  	addraTime <= intAddraTime[9:0]; 			// 10 bit output
  	addrFreq <= cntFftUnloadFreq;
  end

  /******************************************************************/
  /* Continuous assignment                                          */
  /******************************************************************/

  assign intEnaTime = !(intAddraTime[10]);							          // block when cnt[10] == 1
  assign s_axis_data_tdata = {8'b00000000, s_axis_data_tbyte};		// imaginary part of time data --> zero

  // 18x18 bit multiplication
  // 36-bit signed result (always positive)

  assign m_axis_data_tpower = m_axis_data_tdata(18 downto 1) * m_axis_data_tdata(18 downto 1) + m_axis_data_tdata(42 downto 25) * m_axis_data_tdata(42 downto 25);

  /******************************************************************/
  /* AXI FSM (3 'always' block style)                               */
  /******************************************************************/

  always@posedge(ckaTime) begin
    if(btnL == 1) begin
      stAxiLoadCur <= stRes0;
    end
    else begin
      stAxiLoadCur <= stAxiLoadNext;
    end
  end

  always@posedge(ckaTime) begin
    stAxiLoadNext <= 4'bxxxx;

    case (stAxiLoadCur) begin
      stRes0 : stAxiLoadNext <= stRes1;
      stRes1 : stAxiLoadNext <= stConfig;
      stConfig : stAxiLoadNext <= s_axis_config_tready ? stIdle : stConfig;
      stIdle : stAxiLoadNext <= stIdle;        
    endcase

  end

  always@posedge(ckaTime) begin
    s_axis_data_tlast <= !(flgCountLoad);       // not active while counting

    case (stAxiLoadCur) begin
      stRes0, stRes1 : aresetn <= 1'b0;
      stConfig, stIdle : aresetn <= 1'b1;
    endcase

  end

  /******************************************************************/
  /* TimeAcqSync block                                              */
  /******************************************************************/

  always@posedge(ckaTime) begin 				// sync time acquisition on rising edge
  	if (intWeaTime == 1) begin
  		oldDinaTime <= dinaTime; 			  	// store current sample for later
  	end
  	if (flgStartAcquisition == 1) begin
  		flgReset <= 1'b1;
  	end
  	else if ((intWeaTime == 1) && (oldDinaTime < 0) && (dinaTime >= 0)) begin 		// valid sample && last sample negative && current sample positive
  		flgReset <= 1'b0;
  	end
  end

  /******************************************************************/
  /* TimeCounter block                                              */
  /******************************************************************/                 
   
   always@posedge(ckaTime) begin
	if (flgReset == 1) begin
		intAddraTime <= (10'b0000000000);
	end
	else if (intWeaTime == 1) begin
		if (intAddraTime[10] == 1) begin 			// blocking condition
		// do nothing (null)
		end
		else begin
			intAddraTime <= intAddraTime + 1;
		end
	end   	
   end

  /******************************************************************/
  /* FftLoadCounter block                                           */
  /******************************************************************/             

  always@posedge(ckaTime) begin
  	if (s_axis_data_tready == 1) begin
  		cntFftLoadTime <= cntFftLoadTime + 1;
  	end
  	flgCountLoad <= 1'b1; 							// active low
  	if (cntFftLoadTime == 10'b1111111110) begin
  		flgCountLoad <= 1'b0; 						// active low
  	end
  	if (aresetn == 0) begin 						// fft reset
  		cntFftLoadTime <= 10'b0000000000); 			// reset (sync with fft)
  	end
  end

  /******************************************************************/
  /* FftUnloadCounter block                                         */
  /******************************************************************/     

  always@(posedge ckaTime) begin
  	cntFftUnloadFreq <= cntFftUnloadFreq + 1;
  	if (cntFftUnloadFreq == 10'b1111111111) begin
  		cntFftUnloadFreq <= 10'b0000000000; 		// reset (useless)
  	end
  	else if (m_axis_data_tlast == 1) begin 			// sync
  		cntFftUnloadFreq <= 10'b0000000000; 		// reset (sync)
  	end
  end

  /******************************************************************/
  /* m_axis_data_tdata block                                        */
  /******************************************************************/ 

  // 18x18 bit multiplication --> 36 bit signed result (always Positive)
  // m_axis_data_tdata has 19 significant bits each in real part & imaginary part

  always@posedge(ckaTime) begin  	
  	case (sw[2:0]) begin 		// FFT output range (gain)
  		000 : byteFreqSample <= m_axis_data_tpower[30:23];
  		001 : byteFreqSample <= m_axis_data_tpower[29:22];
  		010 : byteFreqSample <= m_axis_data_tpower[28:21];
  		011 : byteFreqSample <= m_axis_data_tpower[27:20];
  		100 : byteFreqSample <= m_axis_data_tpower[26:19];
  		101 : byteFreqSample <= m_axis_data_tpower[25:18];
  		110 : byteFreqSample <= m_axis_data_tpower[24:17];
  		111 : byteFreqSample <= m_axis_data_tpower[23:16];
  	endcase
  end                        

endmodule