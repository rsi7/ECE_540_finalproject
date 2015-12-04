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

  integer           cntHor;
  integer           cntVer;

  wire              inHS;
  wire              inVS;
  wire              inAl;
  wire              inAf;

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
    if (inHS ==1) begin
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