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

  // Video timing signals

  output    [9:0]   adrHor,
  output    [9:0]   adrVer,
  output            flgActiveVideo,
  output            HS,
  output            VS);

  /******************************************************************/
  /* Local parameters and variables                                 */
  /******************************************************************/

  reg       [9:0]   cntHor;
  reg       [9:0]   cntVer;

  localparam        cstHorSize = 800;
  localparam        cstHorAl = 640;     // # of pixels: active line
  localparam        cstHorFp = 16;      // # of pixels: front porch
  localparam        cstHorPw = 96;      // # of pixels: pulse with
  localparam        cstHorBp = 48;      // # of pixels: back porch

  localparam        cstVerSize = 521;
  localparam        cstVerAf = 480;     // # of lines: active frame
  localparam        cstVerFp = 10;      // # of lines: front porch
  localparam        cstVerPw = 2;       // # of lines: pulse with
  localparam        cstVerBp = 29;      // # of lines: back porch

  wire              inHS;               // Horizontal Sync (internal)
  wire              inVS;               // Vertical Sync (internal)
  wire              inAl;               // Active Line (internal)
  wire              inAf;               // Active Frame (internal)

  /******************************************************************/
  /* HorCounter block                                               */
  /******************************************************************/

  always@posedge(ckVideo) begin
    if (cntHor == cstHorSize - 1) begin
      cntHor <= 0;
    end
    else begin
      cntHor <= cntHor + 1;
    end
  end

  /******************************************************************/
  /* HorSync block                                                  */
  /******************************************************************/

  always@posedge(ckVideo) begin
    if (cntHor == cstHorAl + cstHorFp - 1) begin
      inHS <= 1'b0;
    end
    else if (cntHor == cstHorAl + cstHorFp + cstHorPw - 1) begin
      intHS <= 1'b1;
    end
  end

  /******************************************************************/
  /* ActiveLine block                                               */
  /******************************************************************/

  always@posedge(ckVideo) begin
    if (cntHor == cstHorSize - 1) begin
      inAl <= 1'b1;
    end
    else if (cntHor == cstHorAl - 1) begin
      inAl <= 1'b0;
    end
  end

  /******************************************************************/
  /* VerCounter block                                               */
  /******************************************************************/

  always@posedge(ckVideo) begin
    if (inHS == 1) begin
      if (cntVer == cstVerSize - 1) begin
        cntVer <= 0;
      end
      else begin
        cntVer <= cntVer + 1;
      end
    end
  end

  /******************************************************************/
  /* VerSync block                                                  */
  /******************************************************************/

  always@posedge(ckVideo) begin
    if (inHS == 1) begin
      if (cntVer == cstVerAf + cstVerFp - 1) begin
        inVS <= 1'b0;
      end
      else if (cntVer == cstVerAf + cstVerFp + cstVerPw - 1) begin
        inVS <= 1'b1;
      end
    end
  end

  /******************************************************************/
  /* ActiveFrame block                                              */
  /******************************************************************/
  
  always@posedge(ckVideo) begin
    if (inHS == 1) begin
      if (cntVer == cstVerSize - 1) begin
        inAf <= 1'b1;
      end
      else if (cntVer == cstVerAf - 1) begin
        inAf <= 1'b0;
      end
    end
  end

  /******************************************************************/
  /* Output block                                                   */
  /******************************************************************/

  always@posedge(ckVideo) begin
    VS <= inVS;
    HS <= inHS;
    flgActiveVideo <= (inAl && inAf);
    adrHor <= cntHor;
    adrVer <= cntVer;
  end

endmodule