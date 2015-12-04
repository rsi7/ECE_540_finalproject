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

   input             clk_i,
   input             rst_i,

   // PDM interface with Mic

   output            pdm_clk_o,
   output            pdm_lrsel_o,
   input             pdm_data_i,

   // parallel data from mic

   output            data_mic_valid,
   output   [15:0]   data_mic);

   /******************************************************************/
   /* Local parameters and variables                                 */
   /******************************************************************/
   
   wire     [15:0]   data_int;
   wire     [16:0]   pdm_acc;
   wire     [15:0]   pdm_data;
   wire              fs_int;
   wire              fs_tmp;
   wire              fss_tmp;
   wire              fs_comb;
   wire              fs_rise;

   integer           cnt = 0;

   /******************************************************************/
   /* PDM instantiation                                              */
   /******************************************************************/

   pdm_filter PDM (

      // Global signals
      .clk_i         (clk_i),               // I [ 0 ] 100MHz system clock
      .rst_i         (rst_i),               // I [ 0 ] active-high system reset

      // PDM interface to microphone
      .pdm_clk_o     (pdm_clk_o),           // O [ 0 ]
      .pdm_lrsel_o   (pdm_lrsel_o),         // O [ 0 ]
      .pdm_data_i    (pdm_data_i),          // I [ 0 ]

      // output data
      .fs_o          (fs_int),              // O [ 0 ]
      .data_o        (data_int));           // O [15:0]

   /******************************************************************/
   /* always modules                                                 */
   /******************************************************************/

   always@posedge(clk_i) begin
      fs_tmp <= fs_int;
      fss_tmp <= fs_tmp;
   end
   
   always@posedge(fs_int) begin
      if ((fs_tmp == 1) && (fss_tmp == 0)) begin
         fs_rise <= 1'b1;
      end
      else begin
         fs_rise <= 1'b0;
      end
   end

   // divide the fs by 2, resulting in 48kHz impulse rate

   always@posedge(clk_i) begin
      if (rst_i == 1) begin
         cnt <= 0;
      end
      else if ((fs_rise == 1) && (cnt >= 1)) begin
         cnt <= 0;
      end
      else begin
         cnt <= cnt + 1;
      end
   end
   
   always@posedge() begin
      if (cnt == 1) && (fs_rise == 1) begin
         fs_comb <= 1;
      end
      else begin
         fs_comb <= 0;
      end
   end

   always@posedge(clk_i) begin
      data_mic_valid <= fs_comb;
      data_mic <= data_int;
   end

endmodule