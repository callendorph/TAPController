library ieee;
use ieee.std_logic_1164.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

package FifoTbPkg is

  -- This the max width of the fifo. We spec the
  --  records with this width so that we can build
  --  tests that can test any fifo up to the max size.
  --  the VC resizes internally to fit the FIFO.
  constant MAX_FIFO_WIDTH : integer := 1024;

  subtype Fifo_Out_DataType is std_logic_vector(MAX_FIFO_WIDTH-1 downto 0);
  subtype Fifo_In_DataType is std_logic_vector(MAX_FIFO_WIDTH-1 downto 0);

  subtype FifoRecType is StreamRecType (
    DataToModel (Fifo_In_DataType'range),
    DataFromModel (Fifo_Out_DataType'range),
    -- These aren't used but I must declare them with a range
    --   in order for this type to be concrete.
    ParamToModel(7 downto 0),
    ParamFromModel(7 downto 0)
  );

  type FifoOptionType is (
    GET_FIFO_COUNT,
    GET_TX_COUNT,
    GET_RX_COUNT,
    GET_WIDTH,
    GET_DEPTH
  );

  -- Use the Send/Get methods to push data into and out of
  --   the FIFO during the test.

  -- Get the total number values currently in the fifo.
  --  If the queue is empty, this returns 0.
  --  the returned value should never be zero.
  procedure GetCount(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  );

  -- Get the Total number of values pushed into the Fifo
  --  This includes transactions on both the testing interface
  --  (via Send) and the signal interface (DIN/WR_EN/WR_ACK)
  procedure GetTxCount(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  );

  -- Get the total number of values popped out of the Fifo
  --  This includes transactions on both the testing interface
  --  (via Get) and the signal interface (DOUT/RD_EN/VALID).
  procedure GetRxCount(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  );

  procedure GetFifoWidth(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  );

  procedure GetFifoDepth(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  );


  component FifoVC is
    generic (
      MODEL_ID_NAME : string := "";
      -- Number of words that can fit in the
      --  fifo.
      DEPTH : integer := 8;
      -- Width of the fifo in bits.
      WIDTH : integer := 36
      );
    port (
      TransRec : inout FifoRecType ;

      -- Common clock for read and write -
      --   Synchronous to our other logic.
      CLK : in std_logic;
      RESET_n : in std_logic;

      -- Read Interface
      --  This uses a First Word Fall Through (FWFT) style
      --  interface
      DOUT : out std_logic_vector(WIDTH-1 downto 0);
      VALID : out std_logic;
      RD_EN : in std_logic;

      -- Write Interface
      DIN : in std_logic_vector(WIDTH-1 downto 0);
      WR_EN : in std_logic;
      WR_ACK : out std_logic
      );
  end component FifoVC;

----------------------------
-- TestCtrl Methods
----------------------------

  procedure FifoWriteHandshake(
    signal WR_EN : out std_logic;
    signal WR_ACK : in std_logic
  );

  procedure FifoReadHandshake(
    signal DOUT : in std_logic_vector;
    signal VALID : in std_logic;
    signal RD_EN : out std_logic;
    variable VAL : out std_logic_vector;
    clk_period : in time
  );

  procedure FifoTestSetup(name : string);

  procedure CheckFifoCounts(
    signal trans : inout FifoRecType;
    variable ID : AlertLogIDType;
    expCount : integer;
    expTx : integer;
    expRx : integer
    );

end FifoTbPkg;

package body FifoTbPkg is

  procedure GetCount(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  ) is
    variable state : integer;
  begin
    GetModelOptions(TransRec, FifoOptionType'pos(GET_FIFO_COUNT), state);
    value := state;
  end procedure GetCount;

  procedure GetTxCount(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  ) is
    variable state : integer;
  begin
    GetModelOptions(TransRec, FifoOptionType'pos(GET_TX_COUNT), state);
    value := state;
  end procedure GetTxCount;

  procedure GetRxCount(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  ) is
    variable state : integer;
  begin
    GetModelOptions(TransRec, FifoOptionType'pos(GET_RX_COUNT), state);
    value := state;
  end procedure GetRxCount;


  procedure GetFifoWidth(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  ) is
    variable state : integer;
  begin
    GetModelOptions(TransRec, FifoOptionType'pos(GET_WIDTH), state);
    value := state;
  end procedure GetFifoWidth;

  procedure GetFifoDepth(
    signal TransRec : inout FifoRecType;
    variable value : out integer
  ) is
    variable state : integer;
  begin
    GetModelOptions(TransRec, FifoOptionType'pos(GET_DEPTH), state);
    value := state;
  end procedure GetFifoDepth;

----------------------------
-- TestCtrl Methods
----------------------------

  procedure FifoWriteHandshake(
    signal WR_EN : out std_logic;
    signal WR_ACK : in std_logic
  ) is
  begin
    WR_EN <= '1';
    wait until WR_ACK='1';
    WR_EN <= '0';
  end FifoWriteHandshake;

  procedure FifoReadHandshake(
    signal DOUT : in std_logic_vector;
    signal VALID : in std_logic;
    signal RD_EN : out std_logic;
    variable VAL : out std_logic_vector;
    clk_period : in time
  ) is
  begin
    if VALID /= '1' then
      wait until VALID = '1';
    end if;
    VAL := DOUT;
    RD_EN <= '1';
    wait for clk_period * 1;
    RD_EN <= '0';
  end FifoReadHandshake;

  procedure FifoTestSetup(name : string) is
  begin
      SetTestName(name);
      SetLogEnable(PASSED, TRUE);

      wait for 0 ns;
      -- These options are used to format the log output.
      --   they don't affect the simulation in any way.
      SetAlertLogOptions(WriteTimeLast => FALSE);
      SetAlertLogOptions(TimeJustifyAmount => 16);
      SetAlertLogJustify;

      TranscriptOpen(name & ".txt");
      -- Write to both the console and file.
      SetTranscriptMirror(TRUE);
  end FifoTestSetup;

  procedure CheckFifoCounts(
    signal trans : inout FifoRecType;
    variable ID : AlertLogIDType;
    expCount : integer;
    expTx : integer;
    expRx : integer
    ) is
    variable obs : integer;
  begin
    GetCount(trans, obs);
    AffirmIfEqual(ID, obs, expCount, "Fifo Count");

    GetTxCount(trans, obs);
    AffirmIfEqual(ID, obs, expTx, "Transmit Count");

    GetRxCount(trans, obs);
    AffirmIfEqual(ID, obs, expRx, "Read Count");

  end CheckFifoCounts;

end FifoTbPkg;
