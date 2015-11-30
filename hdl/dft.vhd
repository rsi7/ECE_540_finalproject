-- (c) Copyright 1995-2015 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:dft:4.0
-- IP Revision: 9

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

LIBRARY dft_v4_0_9;
USE dft_v4_0_9.dft_v4_0_9;

ENTITY dft IS
  PORT (
    CLK : IN STD_LOGIC;
    SCLR : IN STD_LOGIC;
    XN_RE : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    XN_IM : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
    FD_IN : IN STD_LOGIC;
    FWD_INV : IN STD_LOGIC;
    SIZE : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    RFFD : OUT STD_LOGIC;
    XK_RE : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    XK_IM : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
    BLK_EXP : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    FD_OUT : OUT STD_LOGIC;
    DATA_VALID : OUT STD_LOGIC
  );
END dft;

ARCHITECTURE dft_arch OF dft IS
  ATTRIBUTE DowngradeIPIdentifiedWarnings : string;
  ATTRIBUTE DowngradeIPIdentifiedWarnings OF dft_arch: ARCHITECTURE IS "yes";

  COMPONENT dft_v4_0_9 IS
    GENERIC (
      C_XDEVICEFAMILY : STRING;
      C_COMPONENT_NAME : STRING;
      C_DATA_WIDTH : INTEGER;
      C_SIZE_1536 : INTEGER;
      C_HAS_CE : INTEGER;
      C_HAS_SCLR : INTEGER;
      C_FMAX : INTEGER
    );
    PORT (
      CLK : IN STD_LOGIC;
      CE : IN STD_LOGIC;
      SCLR : IN STD_LOGIC;
      XN_RE : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      XN_IM : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
      FD_IN : IN STD_LOGIC;
      FWD_INV : IN STD_LOGIC;
      SIZE : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
      RFFD : OUT STD_LOGIC;
      XK_RE : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      XK_IM : OUT STD_LOGIC_VECTOR(17 DOWNTO 0);
      BLK_EXP : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      FD_OUT : OUT STD_LOGIC;
      DATA_VALID : OUT STD_LOGIC
    );
  END COMPONENT dft_v4_0_9;
  ATTRIBUTE X_CORE_INFO : STRING;
  ATTRIBUTE X_CORE_INFO OF dft_arch: ARCHITECTURE IS "dft_v4_0_9,Vivado 2015.3";
  ATTRIBUTE CHECK_LICENSE_TYPE : STRING;
  ATTRIBUTE CHECK_LICENSE_TYPE OF dft_arch : ARCHITECTURE IS "dft,dft_v4_0_9,{}";
  ATTRIBUTE CORE_GENERATION_INFO : STRING;
  ATTRIBUTE CORE_GENERATION_INFO OF dft_arch: ARCHITECTURE IS "dft,dft_v4_0_9,{x_ipProduct=Vivado 2015.3,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=dft,x_ipVersion=4.0,x_ipCoreRevision=9,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,C_XDEVICEFAMILY=artix7,C_COMPONENT_NAME=dft,C_DATA_WIDTH=18,C_SIZE_1536=0,C_HAS_CE=0,C_HAS_SCLR=1,C_FMAX=307}";
  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_INFO OF CLK: SIGNAL IS "xilinx.com:signal:clock:1.0 clk_intf CLK";
  ATTRIBUTE X_INTERFACE_INFO OF SCLR: SIGNAL IS "xilinx.com:signal:reset:1.0 sclr_intf RST";
  ATTRIBUTE X_INTERFACE_INFO OF XN_RE: SIGNAL IS "xilinx.com:signal:data:1.0 xn_re_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF XN_IM: SIGNAL IS "xilinx.com:signal:data:1.0 xn_im_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF FD_IN: SIGNAL IS "xilinx.com:signal:data:1.0 fd_in_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF FWD_INV: SIGNAL IS "xilinx.com:signal:data:1.0 fwd_inv_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF SIZE: SIGNAL IS "xilinx.com:signal:data:1.0 size_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF RFFD: SIGNAL IS "xilinx.com:signal:data:1.0 rffd_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF XK_RE: SIGNAL IS "xilinx.com:signal:data:1.0 xk_re_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF XK_IM: SIGNAL IS "xilinx.com:signal:data:1.0 xk_im_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF BLK_EXP: SIGNAL IS "xilinx.com:signal:data:1.0 blk_exp_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF FD_OUT: SIGNAL IS "xilinx.com:signal:data:1.0 fd_out_intf DATA";
  ATTRIBUTE X_INTERFACE_INFO OF DATA_VALID: SIGNAL IS "xilinx.com:signal:data:1.0 data_valid_intf DATA";
BEGIN
  U0 : dft_v4_0_9
    GENERIC MAP (
      C_XDEVICEFAMILY => "artix7",
      C_COMPONENT_NAME => "dft",
      C_DATA_WIDTH => 18,
      C_SIZE_1536 => 0,
      C_HAS_CE => 0,
      C_HAS_SCLR => 1,
      C_FMAX => 307
    )
    PORT MAP (
      CLK => CLK,
      CE => '0',
      SCLR => SCLR,
      XN_RE => XN_RE,
      XN_IM => XN_IM,
      FD_IN => FD_IN,
      FWD_INV => FWD_INV,
      SIZE => SIZE,
      RFFD => RFFD,
      XK_RE => XK_RE,
      XK_IM => XK_IM,
      BLK_EXP => BLK_EXP,
      FD_OUT => FD_OUT,
      DATA_VALID => DATA_VALID
    );
END dft_arch;
