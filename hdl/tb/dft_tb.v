// dft_tb.v - testbench for the Discrete Fourier Transform (DFT) IP core
//
// Description:
// ------------
// This module is to be used as the testbench for validating functionality of the Discrete Fourier Transform (DFT) core.
// It instantiates the DFT and connects it to a block ROM with a sine wave stored in fixed-point format.
// The output is a file (dft_tb.out) that should show the results for XK_RE and XK_IM.
//   
///////////////////////////////////////////////////////////////////////////

`timescale 1ns / 100ps

module dft_tb;

localparam CLK_PERIOD = 10;     // define clock period in nanoseconds
localparam SIZE = 6'd1;         // size encoding for N = 24
localparam BINS = 24;           // number of FFT bins
localparam FWD_INV = 1'b1;      // set 'high' for forward DFT
localparam XN_IM = 18'b0;       // wave input has no sine components

  /******************************************************************/
  /* Declaring the internal variables                               */
  /******************************************************************/

  wire  signed    [17:0]    xk_re;            // Real Data Output in natural order and fixed-point format
  wire  signed    [17:0]    xk_im;            // Imaginary Data Output in natural order and fixed-point format
  wire            [3:0]     blk_exp;          // Block exponent as unsigned integer
  wire                      rffd;             // Goes 'high' when the core's ready for a new frame; goes 'low' one cycle after FD_IN
  wire                      fd_out;           // Goes 'high' one cycle to indicate that the core's ready to output data
  wire                      data_valid;       // Goes 'high' to indicate that data output is valid

  reg   signed    [17:0]    xn_re;            // Real Data Input in two's complement fixed-point format
  reg   signed    [17:0]    xn_im;            // Imaginary Data Input in two's complement fixed-point format
  reg                       clk;              // Clock signal input
  reg                       sclr;             // Set 'high' for a single cycle to reset the core
  reg                       fd_in;            // Set 'high' to indicate start of data input frame
  reg             [4:0]     mem_addr;         // input address for block ROM

  integer                   i;
  integer                   fhandle;

  /******************************************************************/
  /* Instantiating the DUT                                          */
  /******************************************************************/

  (* x_core_info = "dft_v4_0_9,Vivado 2015.3" *)

  dft dft_tester (

    .CLK            (clk),              // I [ 0 ]      Clock signal input
    .SCLR           (sclr),             // I [ 0 ]      Set 'high' for a single cycle to reset the core
    .XN_RE          (xn_re),            // I [17:0]     Real Data Input in two's complement fixed-point format
    .XN_IM          (XN_IM),            // I [17:0]     Imaginary Data Input in two's complement fixed-point format
    .FD_IN          (fd_in),            // I [ 0 ]      Set 'high' to indicate start of data input frame
    .FWD_INV        (FWD_INV),          // I [ 0 ]      Set 'high' to perform forward transform; set 'low' for inverse transform
    .SIZE           (SIZE),             // I [5:0]      Size of transform to be performed
    .RFFD           (rffd),             // O [ 0 ]      Goes 'high' when the core's ready for a new frame; goes 'low' one cycle after FD_IN
    .XK_RE          (xk_re),            // O [17:0]     Real Data Output in natural order and fixed-point format
    .XK_IM          (xk_im),            // O [17:0]     Imaginary Data Output in natural order and fixed-point format
    .BLK_EXP        (blk_exp),          // O [3:0]      Block exponent as unsigned integer
    .FD_OUT         (fd_out),           // O [ 0 ]      Goes 'high' one cycle to indicate that the core's ready to output data
    .DATA_VALID     (data_valid));      // O [ 0 ]      Goes 'high' to indicate that data output is valid

  /******************************************************************/
  /* Instantiating the ROM                                          */
  /******************************************************************/

  (* x_core_info = "blk_mem_gen_v8_3_0,Vivado 2015.3" *)
  
  WaveMemory WaveROM (

    .clka   (clk),        // I [ 0 ]
    .addra  (mem_addr),   // I [4:0]
    .douta  (xn_re));     // O [17:0]

  /******************************************************************/
  /* Running the testbench simluation                               */
  /******************************************************************/

  initial begin
    #0 clk <= 1'b0;
    #0 sclr <= 1'b0;
    #0 xn_re <= 18'b0;
    #0 fd_in <= 0;
    #0 i <= 0;
    #0 mem_addr <= 0;
    fhandle = $fopen("C:/Users/Rehan/OneDrive/Documents/ECE_540/FinalProject/hdl/dft_tb.out");
    #(CLK_PERIOD * 2048) $fdisplay (fhandle, "*** END OF SIMULATION ***");
    $stop;
  end

  always begin
    #(CLK_PERIOD/2) clk <= !clk;
  end

  always begin
    #(CLK_PERIOD * 128)
    if (rffd == 1) begin
      fd_in = 1;
      for(i = 0; i < BINS; i = i + 1) begin
        #(CLK_PERIOD) mem_addr <= i + 1;
      end
      i = 0;
      fd_in = 0;
    end
  end

always@(posedge clk) begin
  if (data_valid == 1) begin
      #(CLK_PERIOD/2) $fdisplay (fhandle, "time = ", $time, "\t xk_re = %b \t xk_im = %b \t blk_exp = %b \n", xk_re, xk_im, blk_exp);
  end
end

endmodule