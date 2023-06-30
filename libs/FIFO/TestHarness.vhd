-- Package for defining the Test Controller.

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

  use std.textio.all;

library osvvm;
  context osvvm.OsvvmContext;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

use work.FifoTbPkg.all;

entity TbFifoVC is
end TbFifoVC;

architecture TestHarness of TbFifoVC is

  constant tperiod_CLK  : time := 10 ns;
  constant WIDTH        : integer := 36;
  constant DEPTH        : integer := 8;

  signal clk            : std_logic := '0';
  signal reset_n        : std_logic;

  -- Fifo Connections
  signal dout, din : std_logic_vector(WIDTH-1 downto 0);
  signal valid, rd_en, wr_en, wr_ack : std_logic;

  component TestCtrl
    generic (
      tperiod_Clk    : time;
      WIDTH : integer;
      DEPTH : integer
      );
    port (
      FifoRec        : inout FifoRecType;
      CLK            : in    std_logic;
      RESET_n        : in    std_logic;

      -- Fifo Signal Interface

      -- Read Interface
      DOUT           : in    std_logic_vector(FIFO_WIDTH-1 downto 0);
      VALID          : in    std_logic;
      RD_EN          : out   std_logic;
      -- Write Interface
      DIN            : out   std_logic_vector(FIFO_WIDTH-1 downto 0);
      WR_EN          : out   std_logic;
      WR_ACK         : in    std_logic
      );
  end component;

  signal control     : FifoRecType;


begin

  Osvvm.TbUtilPkg.CreateClock (
    Clk        => clk,
    Period     => tperiod_CLK
  );

  Osvvm.TbUtilPkg.CreateReset (
    Reset       => reset_n,
    ResetActive => '0',
    Clk         => clk,
    Period      => 3 * tperiod_CLK
  );

  Fifo_UUT : FifoVC
    generic map (
      MODEL_ID_NAME => "UUT",
      WIDTH => WIDTH,
      DEPTH => DEPTH
      )
    port map (
      TransRec => control,
      CLK => clk,
      RESET_n => reset_n,
      -- Read
      DOUT => dout,
      VALID => valid,
      RD_EN => rd_en,
      -- Write
      DIN => din,
      WR_EN => wr_en,
      WR_ACK => wr_ack
    );

  TestDriver : TestCtrl
    generic map (
      tperiod_CLK => tperiod_CLK,
      WIDTH => WIDTH,
      DEPTH => DEPTH
      )
    port map (
      FifoRec => control,
      CLK => clk,
      RESET_n => reset_n,
      -- Read
      DOUT => dout,
      VALID => valid,
      RD_EN => rd_en,
      -- Write
      DIN => din,
      WR_EN => wr_en,
      WR_ACK => wr_ack
      );

end TestHarness;
