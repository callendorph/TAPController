-- Test Controller for the TAPController unit tests

library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;
  use std.textio.all ;

library OSVVM ;
  context OSVVM.OsvvmContext ;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library TbJtagVC;
  use TbJtagVC.JtagTbPkg.all;

library TAP;
  use TAP.JTAG.all;

library tools;
  use tools.BitTools.all;

library work;
  use work.TapCtlTbPkg.all;

entity TestCtrl is
  generic (
    tperiod_CLK    : time;
    DATA_WIDTH     : integer;
    BWIDTH         : integer := Log2(DATA_WIDTH)
  );
  port (
    -- Record Interface
    DevRec         : inout JtagDevRecType;

    -- Global Signal Interface
    CLK            : in    std_logic;
    RESET_n        : in    std_logic;

    JTAG_CLK           : in    std_logic;

    -- Fifo Interface to the TAP Controller

    FORCE_RESET : out std_logic;
    DR_IR : out std_logic;
    DIN : out std_logic_vector(DATA_WIDTH-1 downto 0);
    BITS_IN : out std_logic_vector(Log2(DATA_WIDTH)-1 downto 0);
    END_OF_SCAN : out std_logic;
    WE : out std_logic;
    WACK : in std_logic;

    UNDER_FLOW : in std_logic;
    SCAN_DONE : in std_logic;

    DOUT : in std_logic_vector(DATA_WIDTH-1 downto 0);
    BITS_OUT : in std_logic_vector(Log2(DATA_WIDTH)-1 downto 0);
    DOUT_VALID : in std_logic;
    DOUT_ACK : out std_logic;
    OVER_FLOW : in std_logic

  );
end TestCtrl;
