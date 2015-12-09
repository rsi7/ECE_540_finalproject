// FftBlock.v - Fast Fouriet Transform (FFT) module
//
// Description:
// ------------
// This module stores PDM data from the AudioGen block into a block RAM and then executes a streaming FFT
// Using the FFT results, it calculates the power for each frequency bin and sends it to the block RAM in ImgCtrl
// From there, the bin height is used to draw the correct pixel
//
// This module instantiates the Fast Fourier Transform v9.0 IP core from Vivado
// This core uses an AXI4 interface, which has numerous master/slave signals
// This module creates the state machine to reset the FFT core, which is reset every 10Hz
//
// A number of counters are used to increment the address for frequency & time buffers
// They are kept in sync with the FFT through numerous flags
//
////////////////////////////////////////////////////////////////////////////////////////////////

module FftBlock (

  /******************************************************************/
  /* Top-level port declarations                                    */
  /******************************************************************/

  input               flgStartAcquisition,          // resets the FFT state machine every 10Hz
  input               btnL,                         // pushbutton to reset FFT state machine
  input       [2:0]   sw,                           // selecting output data byte (sensitivity)
  input               ckaTime,                      // 100MHz system clock from ClockWiz
  input               ckFreq,                       // 25MHz clock from ClockWiz

  // Connections with AudioGen

  output 	            weaTime,                      // sampling frequency a.k.a. time-domain data enable signal (48kHz)
  input       [7:0]   dinaTime,                     // decoded time-sample data from PDM filter

  // Connections with ImgCtrl

  output reg          enaTime,                      // port A enable for time buffer: FFT --> ImgCtrl
  output reg  [9:0]   addraTime,                    // time buffer address: FFT --> ImgCtrl
  output reg          flgFreqSampleValid,           // write enable for frequency buffer: FFT --> ImgCtrl
  output reg  [9:0]   addrFreq,                     // frequency buffer address: FFT --> ImgCtrl
  output reg  [7:0]   byteFreqSample);              // frequency power (bin height): FFT --> ImgCtrl

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  // internal signals for registered outputs

  wire            intEnaTime;                           // port A enable for time buffer: FFT --> ImgCtrl
  wire            intWeaTime;                           // sampling frequency a.k.a. time-domain data enable signal (48kHz)
  reg    [10:0]   intAddraTime;                         // time buffer address: FFT --> ImgCtrl
  wire 			      intflgFreqSampleValid;                // write enable for frequency buffer: FFT --> ImgCtrl

  // xfft_1 signals

  reg             aresetn;                              // active-high reset signal controlled by FSM
  wire            s_axis_config_tready;                 // asserted by core: ready to accept data on Config channel
  wire    [15:0]  s_axis_data_tdata;                    // carries the unprocessed sample data: XN_RE and XN_IM
  wire    [7:0]   s_axis_data_tbyte;                    // output byte from TimeBlkMemForFft
  wire            s_axis_data_tready;                   // asserted by core: ready to accept data on Data Input channel
  wire            s_axis_data_tlast;                    // asserted by external master: last sample of the frame
  wire    [47:0]  m_axis_data_tdata;                    // carries the processed sample data: XK_RE and XK_IM
  wire            m_axis_data_tvalid;                   // asserted by core: able to provide sample on Data Output channel
  wire            m_axis_data_tlast;                    // asserted by core: last sample of the frame

  // AXI state machine signals

  localparam stRes0 	= 4'b0001;                   // one-hot encoding for first state
  localparam stRes1 	= 4'b0010;                   // one-hot encoding for second state
  localparam stConfig = 4'b0100;                   // one-hot encoding for third state
  localparam stIdle 	= 4'b1000;                   // one-hot encoding for final state

  reg   [3:0]     stAxiLoadNext;                   // register to hold next state in FSM
  reg 	[3:0]     stAxiLoadCur;                    // register to hold current state in FSM

  // signals for TimeAcqSync block

  reg   [7:0]       oldDinaTime;                    // previous decoded time-sample data from PDM filter (used for edge detection)
  reg               flgReset;                       // active-high reset for TimeCounter block
  wire signed [7:0] oldDinaTime_signed;             // signed version of previous time-sample
  wire signed [7:0] dinaTime_signed;                // signed version of decoded time-sample data from PDM filter

  // signals for FftLoadCounter & FftUnloadCounter blocks

  reg   [9:0]     cntFftLoadTime;                   // counter for FftLoadCounter block --> port B address for TimeBlkMemForFft
  reg   [9:0]     cntFftUnloadFreq;                 // counter for FftUnloadCounter block --> frequency buffer address in ImgCtrl
  reg             flgCountLoad;           	        // active while counting in FftLoadCounter block

  // signed signals for power calculation

  wire signed [17:0] real_data_signed;              // signed version of m_axis_data_tdata[18:1]
  wire signed [35:0] real_data_squared;             // squaring the real component for power calculation

  wire signed [17:0] imaginary_data_signed;         // signed version of m_axis_data_tdata[42:25];
  wire signed [35:0] imaginary_data_squared;        // squaring the imaginary component for power calculation

  // frequency power
  // 18 x 18 bit multiplication of real & imaginary parts
  // then sum them together for signal power

  wire  [36:0]  m_axis_data_tpower;

  /******************************************************************/
  /* Global Assignments                                             */
  /******************************************************************/

  assign weaTime = intWeaTime;                                    // sampling frequency a.k.a. time-domain data enable signal (48kHz)
  assign intEnaTime = !(intAddraTime[10]);			                  // active while counting; port A enable for time buffer: FFT --> ImgCtrl

  assign s_axis_data_tlast    = !(flgCountLoad);                  // 'low' while counting in FftLoadCounter block --> indicates last sample of the frame
  assign s_axis_data_tdata = {8'b00000000, s_axis_data_tbyte};    //  set imaginary data to 8'b0; real data from TimeBlkMemForFft

  // signed signals for positive / negative comparison

  assign dinaTime_signed = dinaTime;                              // signed version of decoded time-sample data from PDM filter
  assign oldDinaTime_signed = oldDinaTime;                        // signed version of previous time-sample

  // signed signals for power calculation

  assign real_data_signed = m_axis_data_tdata[18:1];
  assign real_data_squared = (real_data_signed) * (real_data_signed);

  assign imaginary_data_signed = m_axis_data_tdata[42:25];
  assign imaginary_data_squared = (imaginary_data_signed) * (imaginary_data_signed);

  // frequency power
  // 18 x 18 bit multiplication of real & imaginary parts
  // then sum them together for signal power

  assign m_axis_data_tpower = (real_data_squared) + (imaginary_data_squared);

  /******************************************************************/
  /* AXI FSM (3 'always' block style)                               */
  /******************************************************************/

  // first block: apply reset if needed; otherwise advance the state

  always@(posedge ckaTime) begin
    if(btnL == 1) begin
      stAxiLoadCur <= stRes0;
    end
    else begin
      stAxiLoadCur <= stAxiLoadNext;
    end
  end

  // determine next state based on current state

  always@(posedge ckaTime) begin

    case (stAxiLoadCur)
      stRes0 : stAxiLoadNext <= stRes1;
      stRes1 : stAxiLoadNext <= stConfig;
      stConfig : stAxiLoadNext <= s_axis_config_tready ? stIdle : stConfig;
      stIdle : stAxiLoadNext <= stIdle;
      default : stAxiLoadNext <= stRes0;        
    endcase

  end

  // apply FSM outputs depending on current state

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

  always@(posedge ckaTime) begin
  	if (intWeaTime == 1) begin              // if time-domain enable is 'high'...
  		oldDinaTime <= dinaTime;              // store current sample for as previous sample
  	end
  end

  always@(posedge ckaTime) begin
    if (flgStartAcquisition == 1) begin     // if 10Hz reset flag from Nexys4 is active..
      flgReset <= 1'b1;                     // reset the TimeCounter so that AddraTime --> 11'd0
    end

  // if (time-domain enable) && (last sample negative) && (current sample positive)
  // reset the TimeCounter so that AddraTime --> 11'd0

    else if ((intWeaTime == 1) && (oldDinaTime_signed < 8'sd0) && (dinaTime_signed >= 8'sd0)) begin
      flgReset <= 1'b0;
    end
  end  


  /******************************************************************/
  /* TimeCounter block                                              */
  /******************************************************************/                 

  always@(posedge ckaTime) begin

    // reset the TimeCounter so that AddraTime --> 11'd0

    if (flgReset == 1) begin
  	  intAddraTime <= 11'd0;
    end

    // otherwise, if (time-domain enable) && (AddraTime < 1/2 max value)

    else if ((intWeaTime == 1) && (intAddraTime[10] == 0)) begin
        intAddraTime <= intAddraTime + 1'b1;
    end
  end

  /******************************************************************/
  /* FftLoadCounter block                                           */
  /******************************************************************/             

  always@(posedge ckaTime) begin

    // if active-low reset applied by FSM, reset the counter (sync with xfft_1)

    if (aresetn == 0) begin
  	cntFftLoadTime <= 10'b0000000000;
    end

    // otherwise, increment the counter

  	else if (s_axis_data_tready == 1) begin
  		cntFftLoadTime <= cntFftLoadTime + 1'b1;
  	end
  end

  always@(posedge ckaTime) begin

    // if counter reaches the maximum count...
    // set 'flgCountLoad' low --> sets 's_axis_data_tlast' high, indicating last sample of frame

    if (cntFftLoadTime == 10'b1111111110) begin
      flgCountLoad <= 1'b0;
    end

    // otherwise, keep 's_axis_data_tlast' low

    else begin
      flgCountLoad <= 1'b1;
    end
  end

  /******************************************************************/
  /* FftUnloadCounter block                                         */
  /******************************************************************/     

  always@(posedge ckaTime) begin

    // if counter reaches maximum value --> reset the counter

  	if (cntFftUnloadFreq == 10'b1111111111) begin
  		cntFftUnloadFreq <= 10'b0000000000; 		// reset (useless)
  	end

    // otherwise, if it's the last sample of the frame --> reset the counter (sync with xfft_1)

  	else if (m_axis_data_tlast == 1) begin
  		cntFftUnloadFreq <= 10'b0000000000;
  	end

    // otherwise, increment the counter

    else begin
    	cntFftUnloadFreq <= cntFftUnloadFreq + 1'b1;
    end
  end

  /******************************************************************/
  /* TimeBlkMemForFft instantiation                                 */
  /******************************************************************/

  blk_mem_gen_0 TimeBlkMemForFft (

    .clka     (ckaTime),                  // I [ 0 ] 100MHz system clock from ClockWiz
    .ena      (intEnaTime),               // I [ 0 ] port A enable for time buffer: FFT --> ImgCtrl
    .wea      (intWeaTime),               // I [ 0 ] sampling frequency a.k.a. time-domain data enable signal (48kHz)
    .addra    (intAddraTime[9:0]),        // I [9:0] time buffer address: FFT --> ImgCtrl
    .dina     (dinaTime),                 // I [7:0] decoded time-sample data from PDM filter
    .clkb     (ckaTime),                  // I [ 0 ] 100MHz system clock from ClockWiz
    .enb      (1'b1),                     // I [ 0 ] port B enable (always enabled)
    .addrb    (cntFftLoadTime),           // I [9:0] counter for FftLoadCounter block
    .doutb    (s_axis_data_tbyte));       // O [7:0] output byte for decoded time-sample data from PDM filter

  /******************************************************************/
  /* Registering outputs                                            */
  /******************************************************************/

  always@(posedge ckaTime) begin

    enaTime             <= intEnaTime;                // port A enable for time buffer: FFT --> ImgCtrl
    addraTime           <= intAddraTime[9:0];         // time buffer address: FFT --> ImgCtrl
    flgFreqSampleValid  <= intflgFreqSampleValid;     // write enable for frequency buffer: FFT --> ImgCtrl
    addrFreq            <= cntFftUnloadFreq;          // frequency buffer address: FFT --> ImgCtrl

  // Choose sensitivity (i.e. scale height of FFT bins) thru switches [2:0] on Nexys4 board

    case (sw[2:0])
      3'b000 : byteFreqSample <= m_axis_data_tpower[30:23];       // least sensitive (small bin height)
      3'b001 : byteFreqSample <= m_axis_data_tpower[29:22];
      3'b010 : byteFreqSample <= m_axis_data_tpower[28:21];
      3'b011 : byteFreqSample <= m_axis_data_tpower[27:20];
      3'b100 : byteFreqSample <= m_axis_data_tpower[26:19];
      3'b101 : byteFreqSample <= m_axis_data_tpower[25:18];
      3'b110 : byteFreqSample <= m_axis_data_tpower[24:17];
      3'b111 : byteFreqSample <= m_axis_data_tpower[23:16];       // most sensitive (large bin height)
    endcase

  	end

  /******************************************************************/
  /* FftInst instantiation                                          */
  /******************************************************************/

  xfft_1 FftInst (
    
    .aclk                           (ckaTime),                  // I [ 0 ]  100MHz system clock from ClockWiz
    .aresetn                        (aresetn),                  // I [ 0 ]  active-high reset signal controlled by FSM
    .s_axis_config_tdata            (8'h00),                    // I [7:0]  carries the config info: CP_LEN, FWD/INV, NFFT and SCALE_SCH
    .s_axis_config_tvalid           (1'b1),                     // I [ 0 ]  asserted by external master: able to provide data on Config channel
    .s_axis_config_tready           (s_axis_config_tready),     // O [ 0 ]  asserted by core: ready to accept data on Config channel
    .s_axis_data_tdata              (s_axis_data_tdata),        // I [15:0] carries the unprocessed sample data: XN_RE and XN_IM
    .s_axis_data_tvalid             (1'b1),                     // I [ 0 ]  asserted by external master: able to provide data on Data Input channel
    .s_axis_data_tready             (s_axis_data_tready),       // O [ 0 ]  asserted by core: ready to accept data on Data Input channel
    .s_axis_data_tlast              (s_axis_data_tlast),        // I [ 0 ]  asserted by external master: last sample of the frame
    .m_axis_data_tdata              (m_axis_data_tdata),        // O [47:0] carries the processed sample data: XK_RE and XK_IM
    .m_axis_data_tvalid             (intflgFreqSampleValid),    // O [ 0 ]  asserted by core: able to provide sample on Data Output channel
    .m_axis_data_tready             (1'b1),                     // I [ 0 ]  asserted by external slave: ready to accept data
    .m_axis_data_tlast              (m_axis_data_tlast),        // O [ 0 ]  asserted by core: last sample of the frame
    .event_frame_started            (       ),                  // O [ 0 ]  asserted by core: starting to process a new frame
    .event_tlast_unexpected         (       ),                  // O [ 0 ]  asserted by core: s_axis_data_tlast set 'high' on a sample that's not last in frame
    .event_tlast_missing            (       ),                  // O [ 0 ]  asserted by core: s_axis_data_tlast set 'low' on the sample of a frame
    .event_status_channel_halt      (       ),                  // O [ 0 ]  asserted by core: unable to write data to the Status channel
    .event_data_in_channel_halt     (       ),                  // O [ 0 ]  asserted by core: no data available on Data Input channel
    .event_data_out_channel_halt    (       ));                 // O [ 0 ]  asserted by core: unable to write data to Data Output channel

endmodule