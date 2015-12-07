// VgaCtrl.v -
//
// Description:
// ------------
//
//
//
//
////////////////////////////////////////////////////////////////////////////////////////////////

module VgaCtrl (

  /******************************************************************/
  /* Top-level port declarations                                    */
  /******************************************************************/

  input             ckVideo,
  input             reset,

  // Video timing signals

  output reg  [9:0]  adrHor,
  output reg  [9:0]  adrVer,
  output reg         flgActiveVideo,
  output reg         HS,
  output reg         VS);

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  localparam        cstHorSize = 800;
  localparam        cstHorAl = 640;     // # of pixels: active line
  localparam        cstHorFp = 16;      // # of pixels: front porch
  localparam        cstHorPw = 96;      // # of pixels: pulse with
  localparam        cstHorBp = 48;      // # of pixels: back porch

  localparam        cstVerSize = 524;
  localparam        cstVerAf = 480;     // # of lines: active frame
  localparam        cstVerFp = 11;      // # of lines: front porch
  localparam        cstVerPw = 2;       // # of lines: pulse with
  localparam        cstVerBp = 31;      // # of lines: back porch

  /******************************************************************/
  /* HorCounter block                                               */
  /******************************************************************/

  always@(posedge ckVideo) begin
    if (reset) begin
      adrHor <= 10'd0;
    end
    else if (adrHor >= 10'd799) begin
      adrHor <= 10'd0;
    end
    else begin
      adrHor <= adrHor + 1'd1;
    end
  end

  /******************************************************************/
  /* HorSync block                                                  */
  /******************************************************************/

  always@(posedge ckVideo) begin
    if ((adrHor >= 10'd655) && (adrHor <= 10'd751)) begin
      HS <= 1'b0;
    end
    else begin
      HS <= 1'b1;
    end
  end

  /******************************************************************/
  /* VerCounter block                                               */
  /******************************************************************/

  always@(posedge ckVideo) begin
    if (reset) begin
      adrVer <= 10'd0;
    end
    else if ((adrVer >= 10'd523) && (adrHor >= 10'd799)) begin
      adrVer <= 10'd0;
    end
    else begin
      adrVer <= adrVer + 1'd1;
    end
  end

  /******************************************************************/
  /* VerSync block                                                  */
  /******************************************************************/

  always@(posedge ckVideo) begin
      if ((adrVer >= 10'd490) && (adrVer <= 10'd492)) begin
        VS <= 1'b0;
      end
      else begin
        VS <= 1'b1;
      end
  end

  /******************************************************************/
  /* flgActiveVideo block                                           */
  /******************************************************************/

  always@(posedge ckVideo) begin
    if ((adrHor >= 10'd639) || (adrVer >= 10'd479)) begin
      flgActiveVideo <= 1'b0;
    end
    else begin
      flgActiveVideo <= 1'b1;
    end
  end

endmodule