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
  wire            intWeaTime;
  wire    [10:0]  intAddraTime;

  // xfft_1 signals

  wire            aresetn;
  localparam      s_axis_config_tdata = 8'b00000000;
  wire            s_axis_config_tvalid;
  wire            s_axis_config_tready;
  wire    [15:0]  s_axis_data_tdata;
  wire    [7:0]   s_axis_data_tbyte;
  wire            s_axis_data_tvalid;
  wire            s_axis_data_tready;
  wire            s_axis_data_tlast;
  wire    [47:0]  m_axis_data_tdata;
  wire    [7:0]   m_axis_data_tbyte;
  wire            m_axis_data_tvalid;
  wire            m_axis_data_tready;
  wire            m_axis_data_tlast;
  wire            event_frame_started;
  wire            event_tlast_unexpected;
  wire            event_tlast_missing;
  wire            event_status_channel_halt;
  wire            event_data_in_channel_halt;
  wire            event_data_out_channel_halt;

  // AXI state machine signals

  // type typeAxiLoad is (stRes0, stRes1, stConfig, stIdle);
  // signal stAxiLoadCur, stAxiLoadNext: typeAxiLoad := stRes0;
   
  // time acquisition signals

  wire    [7:0]   oldDinaTime;      // previous time sample (for edge detection)
  wire            flgReset;         // reset for time acquisition counter (includes edge sync)

  // load & unload counter signals

  wire    [9:0]   cntFftLoadTime;       
  wire    [9:0]   cntFftUnloadFreq;
  wire            flgCountLoad;           // active while counting
  wire            cenLoadCounter;         // count enable for Load counter
  wire            cenUnloadCounter;       // count enable for Unload counter
  wire            ckFft;                  // clock inside FFT block

  wire    [35:0]  m_axis_data_tpower;     // 18x18 bit multiplication


  /******************************************************************/
  /* TimeBlkMemForFft instantiation                                 */
  /******************************************************************/

  blk_mem_gen_0 TimeBlkMemForFft (

    .clka     (ckaTime),              // I [ 0 ]
    .ena      (intEnaTime),           // I [ 0 ]
    .wea      (intWeaTime),           // I [ 0 ]
    .addra    (intAddraTime),         // I [9:0]
    .dina     (dinaTime),             // I [7:0]
    .clkb     (ckFft),                // I [ 0 ]
    .enb      (1'b1),                 // I [ 0 ]
    .addrb    (cntFftLoadTime),       // I [9:0]
    .doutb    (s_axis_data_tbyte));   // O [7:0]

  /******************************************************************/
  /* FftInst instantiation                                          */
  /******************************************************************/

  xfft_1 FftInst (
    
    .aclk                           (ckFft),                            // I [ 0 ]
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

  /******************************************************************/
  /* always block                                                   */
  /******************************************************************/

begin

   enaTime <= intEnaTime;
   weaTime <= intWeaTime;
--   addraTime <= intAddraTime;
   
   ckFft <= ckaTime; -- run at 100MHz



   ResetStateMachine: process (ckFft)
   begin
      if (ckFftevent and ckFft = '1') then
--         if (btnL = '1') then      -- reset laod state machine
--            stAxiLoadCur <= stRes0;
--         else  
            stAxiLoadCur <= stAxiLoadNext;
--         end if;        
      end if;
   end process;
 
   --MOORE State-Machine - Outputs based on state only
   OUTPUT_DECODE: process (stAxiLoadCur)
   begin
   -- default values
      aresetn <= '1';  -- inactive
      s_axis_config_tvalid <= '1';  -- make it always active (config data  always vaslid)
--      s_axis_data_tvalid <= '0';  
      s_axis_data_tvalid <= '1';  -- debug ALWAYS valid
      s_axis_data_tlast <= not flgCountLoad;  --  not active while counting;
      m_axis_data_tready <= '1';  -- always ready to get frequency samples
      
      if stAxiLoadCur = stRes0 or stAxiLoadCur = stRes1  then
         aresetn <= '0';  -- active
      end if;

   end process;
 
   NEXT_STATE_DECODE: process (stAxiLoadCur)
   begin
      --declare default state for next_state to avoid latches
      stAxiLoadNext <= stAxiLoadCur;  --default is to stay in current state

      case (stAxiLoadCur) is
         when stRes0 =>
               stAxiLoadNext <= stRes1;

         when stRes1 =>
               stAxiLoadNext <= stConfig;

         when stConfig =>
            if s_axis_config_tready = '1' then
               stAxiLoadNext <= stIdle;
            end if;

-- stay forever in stIdle

         when stIdle =>
            null;

         when others =>
            stAxiLoadNext <= stRes0;
            
      end case;      
   end process;

   addraTime <= intAddraTime(9 downto 0);  -- 10bit out
   intEnaTime <= not intAddraTime(10);  -- blocked when cnt(10) = 1

TimeAcqSync: process(ckaTime)  -- sync time acquisition on rising edge at level zero
   begin
   if rising_edge(ckaTime) then
      if intWeaTime = '1' then
         oldDinaTime <= dinaTime;   -- store current sample for later
      end if;   
      if flgStartAcquisition = '1' then
         flgReset <= '1';
      elsif intWeaTime = '1' and -- valid sample
            oldDinaTime < 0 and  -- last sample negative
            dinaTime >= 0 then    -- current sample positive
         flgReset <= '0';
      end if;
   end if;
end process;                    
   
TimeCounter: process(ckaTime)
   begin
      if rising_edge(ckaTime) then
         if flgReset = '1' then
            intAddraTime <= (others => '0');
         elsif intWeaTime = '1' then
            if intAddraTime(10) = '1' then -- blocking condition
               null;
            else
               intAddraTime <= intAddraTime + '1';
            end if;
         end if;
      end if;
   end process;                    

FftLoadCounter: process(ckFft)
   begin
      if rising_edge(ckFft) then
         if s_axis_data_tready = '1' then
            cntFftLoadTime <= cntFftLoadTime + '1';
         end if;
         flgCountLoad <= '1'; -- active low
         if cntFftLoadTime = "1111111110" then
--            cntFftLoadTime <= (others => '0');  -- reset (useles)
            flgCountLoad <= '0'; -- active low
         end if;   
--         if event_tlast_missing = '1' then  -- lost of sync
         if aresetn = '0' then  -- fft reset
            cntFftLoadTime <= (others => '0');  -- reset (sync with fft)
         end if;   
      end if;
   end process;      

FftUnloadCounter: process(ckFft)
   begin
      if rising_edge(ckFft) then
         cntFftUnloadFreq <= cntFftUnloadFreq + '1';
         if cntFftUnloadFreq = "1111111111" then
            cntFftUnloadFreq <= (others => '0');  -- reset (useles)
         elsif m_axis_data_tlast = '1' then  -- sync
            cntFftUnloadFreq <= (others => '0');  -- reset (sync)
         end if;   
      end if;
   end process;      

   addrFreq <= cntFftUnloadFreq;
   

   s_axis_data_tdata(7 downto 0) <= s_axis_data_tbyte ;  -- real part of the time data
   s_axis_data_tdata(15 downto 8) <= (others => '0');    -- imaginary part of the time data

   m_axis_data_tpower <= m_axis_data_tdata(18 downto 1) * m_axis_data_tdata(18 downto 1) +   -- 18x18 bit multiplication
                         m_axis_data_tdata(42 downto 25) * m_axis_data_tdata(42 downto 25);  -- 36 bit signaed result (always positive)
   -- m_axis_data_tdata has 19 significant bits in each real and immaginary parts  
     
   byteFreqSample <= m_axis_data_tpower(30 downto 23) when sw(2 downto 0) = "000" else  -- FFT output range (gain) 
                     m_axis_data_tpower(29 downto 22) when sw(2 downto 0) = "001" else
                     m_axis_data_tpower(28 downto 21) when sw(2 downto 0) = "010" else
                     m_axis_data_tpower(27 downto 20) when sw(2 downto 0) = "011" else
                     m_axis_data_tpower(26 downto 19) when sw(2 downto 0) = "100" else
                     m_axis_data_tpower(25 downto 18) when sw(2 downto 0) = "101" else
                     m_axis_data_tpower(24 downto 17) when sw(2 downto 0) = "110" else
                     m_axis_data_tpower(23 downto 16);-- when sw(2 downto 0) = "111" else
                       
--  debugm_axis_data_tbyte <= m_axis_data_tbyte; -- debug                         


end Behavioral;
