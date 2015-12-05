// ImgCtrl.v - image controller
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

module ImgCtrl (

  /******************************************************************/
  /* Top-level port declarations                            */
  /******************************************************************/

  input       ck100MHz,           // 100MHz clock from on-board oscillator

  // time domain data signals

  input           enaTime,
  input           weaTime,
  input   [9:0]   addraTime,
  input   [7:0]   dinaTime,

  // frequency domain data signals

//input           enaFreq,
  input           weaFreq,
  input   [9:0]   addraFreq,
  input   [7:0]   dinaFreq,

  // video timing signals

  input           ckVideo,
  input           flgActiveVideo,
  input   [9:0]   adrHor,
  input   [9:0]   adrVer,

  // color signal outputs

  output  [3:0]   red,
  output  [3:0]   green,
  output  [3:0]   blue);

  /******************************************************************/
  /* Local parameters and variables                         */
  /******************************************************************/

  localparam      cstHorSize = 800;
  localparam      cstVerSize = 521;

  /******************************************************************/
  /* TimeBlkMemForDisplay instantiation                             */
  /******************************************************************/

  blk_mem_gen_0 TimeBlkMemForDisplay (

    .clka     (ck100MHz),                // I [ 0 ]
    .ena      (enaTime),                 // I [ 0 ]
    .wea      (weaTime),                 // I [ 0 ]
    .addra    (addraTime),               // I [9:0]
    .dina     (dinaTime),                // I [7:0]
    .clkb     (ckVideo),                 // I [ 0 ]
    .enb      (1'b1);                    // I [ 0 ]
    .addrb    (vecadrHor),               // I [9:0]
    .doutb    (sampleDisplayTime));      // I [7:0]

  /******************************************************************/
  /* FreqBlkMemForDisplay instantiation                             */
  /******************************************************************/

  blk_mem_gen_0 FreqBlkMemForDisplay (

    .clka     (ck100MHz),                // I [ 0 ]
    .ena      (1'b1),                    // I [ 0 ]
    .wea      (weaFreq),                 // I [ 0 ]
    .addra    (addraFreq),               // I [9:0]
    .dina     (dinaFreq),                // I [7:0] selected byte
    .clkb     (ckVideo),                 // I [ 0 ]
    .enb      (1'b1);                    // I [ 0 ]
    .addrb    ({3'b0,vecadrHor[9:3]}),   // I [9:0] divide by 8 (display 640/8 = 80 points; point = 96kHz/512 = 187.5Hz)
    .doutb    (sampleDisplayFreq));      // I [7:0]

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  wire  [7:0]   sampleDisplayTime;      // time domain sample for display
  wire  [7:0]   sampleDisplayFreq;      // freq domain sample for display
  wire  [9:0]   vecadrHor;              // pixel column counter
  wire  [9:0]   vecadrVer;              // pixel row counter

  // connections for output ports

  wire  [3:0]   intRed;
  wire  [3:0]   intGreen;
  wire  [3:0]   intBlue;

  /******************************************************************/
  /* always blocks                                                  */
  /******************************************************************/
  
  always@posedge(ck100MHz) begin
    if ((adrVer <= cstVerAf/2) && (adrVer >= cstVerAf/4 - conv_integer(sampleDisplayTime))) begin
      intRed <= 4'b1111;
    end
    else begin
      intRed <= 4'b0000;
    end
  end

  always@posedge(ck100MHz) begin
    if ((adrVer >= cstVerAf/2) && (adrVer >= cstVerAf*47/48 - conv_integer(sampleDisplayTime))) begin
      intGreen <= 4'b1111;
    end
    else begin
      intGreen <= 4'b0000;
    end
  end

  always@posedge(ck100MHz) begin
    if ((adrVer >= cstVerAf/2) && (adrVer >= cstVerAf*47/48 - conv_integer(sampleDisplayTime))) begin
      intBlue <= 4'b1111;
    end
    else begin
      intBlue <= 4'b0000;
    end
  end

  /******************************************************************/
  /* RGB outputs for current pixel                                  */
  /******************************************************************/

  always@posedge(ckVideo) begin
    if (flgActiveVideo == 1) begin
      red <= intRed;
      green <= intGreen;
      blue <= intBlue;
    end
    else begin
      red <= 4'b0000;
      green <= 4'b0000;
      blue <= 4'b0000;
    end
  end

endmodule