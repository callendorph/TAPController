-- Test Controller for setting up the Fifo VC
--  unit tests.
-- This is the framework - individual tests will
--  implement this interface3

library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use ieee.numeric_std_unsigned.all ;
  use std.textio.all ;

library OSVVM ;
  context OSVVM.OsvvmContext ;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

use work.FifoTbPkg.all;
use work.OsvvmTestCommonPkg.all;

entity TestCtrl is
  generic (
    tperiod_CLK    : time;
    WIDTH : integer;
    DEPTH : integer
  );
  port (
    -- Record Interface
    FifoRec        : inout FifoRecType;

    -- Global Signal Interface
    CLK            : in    std_logic;
    RESET_n        : in    std_logic;

    -- Fifo Signal Interface

    -- Read Interface
    DOUT           : in    std_logic_vector(WIDTH-1 downto 0);
    VALID          : in    std_logic;
    RD_EN          : out   std_logic;
    -- Write Interface
    DIN            : out   std_logic_vector(WIDTH-1 downto 0);
    WR_EN          : out   std_logic;
    WR_ACK         : in    std_logic
  );
end TestCtrl;
