library ieee;
use ieee.std_logic_1164.all;

library work;
use work.JTAG.all;
use work.BitTools.all;


package CompDefs is

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

  component JTAG_DUT is
    generic (
      ID_WIDTH : in integer := 32;
      BYPASS_WIDTH : in integer := 1;
      SCAN_WIDTH : in integer := 64
      );
    port (
      --------------------------
      -- Sync Interface
      --------------------------
      CLK : in std_logic;
      RESET_n : in std_logic;

      --------------------------
      -- JTAG Interface
      --------------------------
      TDI : in std_logic;
      TDO : buffer std_logic;
      TMS : in std_logic;
      TCK : in std_logic;

      --------------------------
      -- User Interface
      --------------------------

      -- Instruction Register State
      IR : buffer std_logic_vector(3 downto 0);
      -- User provides this Boundary Scan input and it
      --  is sampled in the CAPTURE_DR state
      BS : in std_logic_vector(SCAN_WIDTH-1 downto 0);
      -- Holds the current state of the Boundary Scan register
      --  This holds the sample of BS and then gets clocked out
      --  on TDO as the user reads it.
      BSR : buffer std_logic_vector(SCAN_WIDTH-1 downto 0);
      -- Identifier for the chip that is read when
      --  the IDCODE instruction is written to the IR.
      ID : in std_logic_vector(ID_WIDTH-1 downto 0);

      -- Current JTAG state of the device
      --   this is primarily useful for debugging.
      curr_state : buffer JTAG_STATE_t
      );

end component JTAG_DUT;


end package;
