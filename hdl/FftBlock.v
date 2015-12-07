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

  input               flgStartAcquisition,
  input               btnL,
  input       [2:0]   sw,
  input               ckaTime,
  output              enaTime,
  output              weaTime,
  output      [9:0]   addraTime,
  input 	  [7:0]   dinaTime,
  input               ckFreq,
  output              flgFreqSampleValid,
  output      [9:0]   addrFreq,
  output reg  [7:0]   byteFreqSample);

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  // internal signals

  wire            intEnaTime;
  wire            intWeaTime;
  reg    [10:0]   intAddraTime;

  // xfft_1 signals

  reg             aresetn;                              // reset signal (set by FSM)
  localparam      s_axis_config_tdata = 8'h00;    		// config data
  
  wire            s_axis_config_tvalid;                 // input flag for FFT (config data always valid) 
  wire            s_axis_config_tready;                 // output flag from FFT
  wire    [15:0]  s_axis_data_tdata;                    // might need to register this
  wire    [7:0]   s_axis_data_tbyte;                    // output data from TimeBlkMemForFft
  wire            s_axis_data_tvalid;                   // input flag for FFT (debug always valid)
  wire            s_axis_data_tready;                   // output flag from FFT
  wire            s_axis_data_tlast;                    // input flag to FFT (set by FSM)
  wire    [47:0]  m_axis_data_tdata;                    // output data from FFT
  wire    [7:0]   m_axis_data_tbyte;                    // a byte of 'm_axis_data_tdata' (unused)
  wire            m_axis_data_tvalid;                   // output flag from FFT (unused)
  wire            m_axis_data_tready;                   // always ready to get frequency samples
  wire            m_axis_data_tlast;                    // output data from FFT
  wire            event_frame_started;                  // event ouput from FFT (unused)
  wire            event_tlast_unexpected;               // event ouput from FFT (unused)
  wire            event_tlast_missing;                  // event ouput from FFT (unused)
  wire            event_status_channel_halt;            // event ouput from FFT (unused)
  wire            event_data_in_channel_halt;           // event ouput from FFT (unused)
  wire            event_data_out_channel_halt;          // event ouput from FFT (unused)

  // AXI state machine signals

  localparam stRes0 	= 4'b0001;
  localparam stRes1 	= 4'b0010;
  localparam stConfig 	= 4'b0100;
  localparam stIdle 	= 4'b1000;

  reg   [3:0]     stAxiLoadNext;
  reg 	[3:0]     stAxiLoadCur;
   
  // time acquisition signals

  reg   [7:0]     oldDinaTime;      // previous time sample (for edge detection)
  reg             flgReset;         // reset for time acquisition counter (includes edge sync)

  // load & unload counter signals

  reg   [9:0]     cntFftLoadTime;       
  reg   [9:0]     cntFftUnloadFreq;
  reg             flgCountLoad;           	// active while counting
  reg             cenLoadCounter;		  	// count enable for Load counter
  reg             cenUnloadCounter;			// count enable for Unload counter

  // 18x18 bit multiplication for signal power

  wire    [35:0]  m_axis_data_tpower;     // 18x18 bit multiplication

  // signals for signed comparison

  wire signed [7:0] oldDinaTime_signed;
  wire signed [7:0] dinaTime_signed;

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  assign enaTime = intEnaTime;
  assign weaTime = intWeaTime;

  assign s_axis_config_tvalid = 1'b1;
  assign s_axis_data_tvalid = 1'b1;
  assign s_axis_data_tlast = !(flgCountLoad);		// not active while counting
  assign m_axis_data_tready = 1'b1;

  assign addraTime = intAddraTime[9:0];
  assign intEnaTime = !(intAddraTime[10]);			// active while counting
  assign addrFreq = cntFftUnloadFreq;

  assign s_axis_data_tdata = {8'b00000000, s_axis_data_tbyte};
  assign m_axis_data_tpower = (m_axis_data_tdata[18:1] * m_axis_data_tdata[18:1]) + (m_axis_data_tdata[42:25] * m_axis_data_tdata[42:25]);
  // assign byteFreqSample = m_axis_data_tpower[23:16];

  assign dinaTime_signed = dinaTime;
  assign oldDinaTime_signed = oldDinaTime;

  /******************************************************************/
  /* AXI FSM (3 'always' block style)                               */
  /******************************************************************/

  always@(posedge ckaTime) begin
    if(btnL == 1) begin
      stAxiLoadCur <= stRes0;
    end
    else begin
      stAxiLoadCur <= stAxiLoadNext;
    end
  end

  always@(posedge ckaTime) begin

    case (stAxiLoadCur)
      stRes0 : stAxiLoadNext <= stRes1;
      stRes1 : stAxiLoadNext <= stConfig;
      stConfig : stAxiLoadNext <= s_axis_config_tready ? stIdle : stConfig;
      stIdle : stAxiLoadNext <= stIdle;
      default : stAxiLoadNext <= stRes0;        
    endcase

  end

  always@(posedge ckaTime) begin

    case (stAxiLoadCur)
      stRes0, stRes1 : aresetn <= 1'b0;
      stConfig, stIdle : aresetn <= 1'b1;
      default : aresetn <= 1'b1;
    endcase

  end

  /******************************************************************/
  /* TimeAcqSync block                                              */
  /******************************************************************/

  always@(posedge ckaTime) begin 				// sync time acquisition on rising edge
  	if (intWeaTime == 1) begin
  		oldDinaTime <= dinaTime; 			  	// store current sample for later
  	end
  end

  always@(posedge ckaTime) begin
    if (flgStartAcquisition == 1) begin
      flgReset <= 1'b1;
    end

	// valid sample && last sample negative && current sample positive

    else if ((intWeaTime == 1) && (oldDinaTime_signed < 8'sd0) && (dinaTime_signed >= 8'sd0)) begin
      flgReset <= 1'b0;
    end
  end  


  /******************************************************************/
  /* TimeCounter block                                              */
  /******************************************************************/                 
   
  always@(posedge ckaTime) begin
    if (flgReset == 1) begin
		  intAddraTime <= 11'd0;
    end
    else if ((intWeaTime == 1) && (intAddraTime[10] == 0)) begin
        intAddraTime <= intAddraTime + 1'b1;
    end
  end

  /******************************************************************/
  /* FftLoadCounter block                                           */
  /******************************************************************/             

  always@(posedge ckaTime) begin
    if (aresetn == 0) begin             		// fft reset
		cntFftLoadTime <= 10'b0000000000;      	// reset (sync with fft)
    end
/*    else if (cntFftLoadTime == 10'b1111111110) begin
    	cntFftLoadTime <= 10'b0000000000;
    end*/
  	else if (s_axis_data_tready == 1) begin
  		cntFftLoadTime <= cntFftLoadTime + 1'b1;
  	end
  end

  always@(posedge ckaTime) begin
    if (cntFftLoadTime == 10'b1111111110) begin
      flgCountLoad <= 1'b0;             // active low
    end
    else begin
      flgCountLoad <= 1'b1;
    end
  end

  /******************************************************************/
  /* FftUnloadCounter block                                         */
  /******************************************************************/     

  always@(posedge ckaTime) begin
  	if (cntFftUnloadFreq == 10'b1111111111) begin
  		cntFftUnloadFreq <= 10'b0000000000; 		// reset (useless)
  	end
  	else if (m_axis_data_tlast == 1) begin 			// sync
  		cntFftUnloadFreq <= 10'b0000000000; 		// reset (sync)
  	end
    else begin
    	cntFftUnloadFreq <= cntFftUnloadFreq + 1'b1;
    end
  end

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
  /* Registering outputs                                            */
  /******************************************************************/

  // Choose power (height of FFT bars) thru switches [2:0] on Nexys4 board
  
  always@(posedge ckaTime) begin
    case (sw[2:0])
      3'b000 : byteFreqSample <= m_axis_data_tpower[30:23];
      3'b001 : byteFreqSample <= m_axis_data_tpower[29:22];
      3'b010 : byteFreqSample <= m_axis_data_tpower[28:21];
      3'b011 : byteFreqSample <= m_axis_data_tpower[27:20];
      3'b100 : byteFreqSample <= m_axis_data_tpower[26:19];
      3'b101 : byteFreqSample <= m_axis_data_tpower[25:18];
      3'b110 : byteFreqSample <= m_axis_data_tpower[24:17];
      3'b111 : byteFreqSample <= m_axis_data_tpower[23:16];
    endcase

 	end

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
    .event_frame_started            (event_frame_started),              // O [ 0 ]
    .event_tlast_unexpected         (event_tlast_unexpected),           // O [ 0 ]
    .event_tlast_missing            (event_tlast_missing),              // O [ 0 ]
    .event_status_channel_halt      (event_status_channel_halt),        // O [ 0 ]
    .event_data_in_channel_halt     (event_data_in_channel_halt),       // O [ 0 ]
    .event_data_out_channel_halt    (event_data_out_channel_halt));     // O [ 0 ]

endmodule