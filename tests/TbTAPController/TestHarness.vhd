library ieee ;
  use ieee.std_logic_1164.all ;
  use ieee.numeric_std.all ;

  use std.textio.all ;

library osvvm ;
  context osvvm.OsvvmContext ;

library TbJtagVC;
  use TbJtagVC.JtagTbPkg.all;

library tools;
  use tools.BitTools.all;

library TAP;
  use TAP.TAPPkg.all;

entity TbTAPController is
end TbTAPController ;

architecture TestHarness of TbTAPController is

  constant tperiod_CLK      : time := 10 ns ;
  constant tperiod_JTAG_CLK : time := 100 ns;
  constant tpd              : time := 2 ns ;

  constant WIDTH            : integer := 32;

  signal clk            : std_logic := '0' ;
  signal jtag_clk       : std_logic := '0';
  signal reset_n        : std_logic ;

  component TestCtrl
    generic (
      tperiod_CLK           : time;
      DATA_WIDTH            : integer
      ) ;
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

      ) ;
  end component ;

    -- JTAG Interface
  signal tdi, tdo, tms, tck : std_logic;
  signal force_reset, under_flow, over_flow : std_logic;
  signal dr_ir, we, wack, end_of_scan : std_logic;
  signal dout_valid, dout_ack, scan_done : std_logic;
  signal din, dout : std_logic_vector(WIDTH-1 downto 0);
  signal bits_in, bits_out : std_logic_vector(Log2(WIDTH)-1 downto 0);

  signal DevRec : JtagDevRecType;

begin
  -- System Clock
  Osvvm.TbUtilPkg.CreateClock (
    Clk        => clk,
    Period     => tperiod_CLK
    );

  -- JTAG bit clock
  Osvvm.TbUtilPkg.CreateClock (
    Clk        => jtag_clk,
    Period     => tperiod_JTAG_CLK
    );

  Osvvm.TbUtilPkg.CreateReset (
    Reset       => reset_n,
    ResetActive => '0',
    Clk         => CLK,
    Period      => 3 * tperiod_CLK,
    tpd         => tpd
  ) ;


  -------------------------------------------
  -- UUT
  -------------------------------------------

  --  Instantiate the TAPController with the interface
  --   to the FIFO IO and the JTAG DUT
  UUT : TAPController
    generic map (
      DATA_WIDTH => WIDTH
    )
    port map (
      CLK => clk,
      RESET_n => reset_n,
      JTAG_CLK => jtag_clk,
      -- JTAG
      TDI => tdi,
      TDO => tdo,
      TMS => tms,
      TCK => tck,
      -- User Interface
      FORCE_RESET => force_reset,
      DR_IR => dr_ir,
      DIN => din,
      BITS_IN => bits_in,
      END_OF_SCAN => end_of_scan,
      WE => we,
      WACK => wack,
      UNDER_FLOW => under_flow,
      SCAN_DONE => scan_done,
      DOUT => dout,
      BITS_OUT => bits_out,
      DOUT_VALID => dout_valid,
      DOUT_ACK => dout_ack,
      OVER_FLOW => over_flow
    );


  DevVC : JtagDevVC
    generic map (
      MODEL_ID_NAME => "DevVC"
    )
    port map (
      TransRec => DevRec,
      CLK => clk,
      RESET_n => reset_n,
      TDI => tdi,
      TDO => tdo,
      TMS => tms,
      TCK => tck
    );


  TestDriver : TestCtrl
  generic map (
    tperiod_Clk         => tperiod_Clk,
    DATA_WIDTH => WIDTH
  )
  port map (

    -- Rec
    DevRec             => DevRec,

    CLK                 => clk,
    RESET_n             => reset_n,
    JTAG_CLK            => jtag_clk,

    -- FIFO interface
    FORCE_RESET => force_reset,
    DR_IR => dr_ir,
    DIN => din,
    BITS_IN => bits_in,
    END_OF_SCAN => end_of_scan,
    WE => we,
    WACK => wack,
    UNDER_FLOW => under_flow,
    SCAN_DONE => scan_done,
    DOUT => dout,
    BITS_OUT => bits_out,
    DOUT_VALID => dout_valid,
    DOUT_ACK => dout_ack,
    OVER_FLOW => over_flow
  );

end TestHarness ;
