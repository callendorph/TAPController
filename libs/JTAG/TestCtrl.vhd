-- Test Controller for Jtag Device unit tests.
-- This is the framework - individual tests will
--  implement this interface

library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;
  use std.textio.all ;

library OSVVM ;
  context OSVVM.OsvvmContext ;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

use work.JtagTbPkg.all;
use work.OsvvmTestCommonPkg.all;

entity TestCtrl is
  generic (
    tperiod_CLK    : time
  );
  port (
    -- Record Interface
    DevRec         : inout JtagDevRecType;

    -- Global Signal Interface
    CLK            : in    std_logic;
    RESET_n        : in    std_logic;

    JTAG_CLK           : in    std_logic;

    TDI                : out std_logic;
    TDO                : in     std_logic;
    TMS                : out    std_logic;
    TCK                : out    std_logic

  );
end TestCtrl;
