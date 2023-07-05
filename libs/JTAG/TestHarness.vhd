library ieee ;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  use std.textio.all;

library osvvm ;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

library work;
  use work.JtagTbPkg.all;
  use work.JTAG.all;

entity TbJtagDevVC is
end TbJtagDevVC;

architecture TestHarness of TbJtagDevVC is

  constant tperiod_CLK      : time := 10 ns ;
  constant tperiod_JTAG_CLK : time := 100 ns;
  constant tpd              : time := 2 ns ;

  signal clk            : std_logic := '0' ;
  signal jtag_clk       : std_logic := '0';
  signal reset_n        : std_logic ;

  -- JTAG Interface
  signal tdi, tdo, tms, tck : std_logic;

  component TestCtrl
    generic (
      tperiod_CLK           : time
      ) ;
    port (
      DevRec             : inout JtagDevRecType;

      CLK                : in    std_logic;
      RESET_n            : in    std_logic;

      JTAG_CLK           : in    std_logic;

      TDI                : out    std_logic;
      TDO                : in     std_logic;
      TMS                : out    std_logic;
      TCK                : out    std_logic
      );
  end component;

  signal devRec : JtagDevRecType;


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
    );


  UUT : JtagDevVC
    generic map (
      MODEL_ID_NAME => "UUT"
    )
    port map (
      TransRec => devRec,
      CLK => clk,
      RESET_n => reset_n,
      TDI => TDI,
      TDO => TDO,
      TMS => TMS,
      TCK => TCK
    );

  TestDriver : TestCtrl
  generic map (
    tperiod_Clk => tperiod_Clk
  )
  port map (
    DevRec => devRec,

    CLK => clk,
    RESET_n => reset_n,
    JTAG_CLK => jtag_clk,

    TDI => TDI,
    TDO => TDO,
    TMS => TMS,
    TCK => TCK

  );

end TestHarness;
