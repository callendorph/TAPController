library ieee;
  use ieee.std_logic_1164.all;

library tools;
  use tools.BitTools.all;

package TAPPkg is

  component TAPController is
  generic (
    DATA_WIDTH : in integer := 32
    );
  port (
    CLK : in std_logic;
    RESET_n : in std_logic;
    JTAG_CLK : in std_logic;

    TDI : buffer std_logic;
    TDO : in std_logic;
    TMS : buffer std_logic;
    TCK : buffer std_logic;

    FORCE_RESET : in std_logic;
    DR_IR : in std_logic;
    DIN : in std_logic_vector(DATA_WIDTH-1 downto 0);
    BITS_IN : in std_logic_vector(Log2(DATA_WIDTH)-1 downto 0);
    END_OF_SCAN : in std_logic;
    WE : in std_logic;
    WACK : buffer std_logic;

    UNDER_FLOW : buffer std_logic;
    SCAN_DONE : out std_logic;

    DOUT : out std_logic_vector(DATA_WIDTH-1 downto 0);
    BITS_OUT : out std_logic_vector(Log2(DATA_WIDTH)-1 downto 0);
    DOUT_VALID : buffer std_logic;
    DOUT_ACK : in std_logic;
    OVER_FLOW : buffer std_logic

    );
  end component TAPController;

end TAPPkg;
