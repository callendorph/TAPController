-- Blocking Fifo Unit test for the Fifo verification component.
--   The goal is to show that the receive functions will block
--   waiting for data if the FIFO is empty.
architecture rx_blocking of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

  type test_vector_array is array (natural range <>) of std_logic_vector;

  constant VEC_LEN : integer := DEPTH+2;

  constant test_vecs : test_vector_array(0 to VEC_LEN-1)(WIDTH-1 downto 0) := (
    X"1_10001000",
    X"2_10002000",
    X"3_10003000",
    X"4_F000A000",
    X"5_0A000500",
    X"6_00A00050",
    X"7_000A0005",
    X"8_0000A002",
    X"9_0F001001",
    X"A_0F002002"
    );

begin
  ControlProc : process
    begin
      FifoTestSetup(rx_blocking'SIMPLE_NAME, OSVVM_RESULTS_DIR);

      -- Wait for Design Reset
      wait until RESET_n = '1';
      ClearAlerts;

      -- Wait for test to finish
      WaitForBarrier(TestDone, 10 ms);
      AlertIf(now >= 10 ms, "Test finished due to timeout");
      AlertIf(GetAffirmCount < 1, "Test is not Self-Checking");

      TranscriptClose;
      EndOfTestReports;
      std.env.stop ;
      wait;
    end process ControlProc;

  RxProc : process
    variable fifoID : AlertLogIDType;
    variable obs : std_logic_vector(WIDTH-1 downto 0);
  begin

    RD_EN <= '0';

    GetAlertLogID(FifoRec, fifoID);
    SetLogEnable(fifoID, INFO, TRUE);

    wait until RESET_n = '1';

    -- Check that the signal interface blocks as expected.
    for i in 0 to (VEC_LEN/2)-1 loop
      FifoReadHandshake(DOUT, VALID, RD_EN, obs, tperiod_CLK);
      AffirmIfEqual(fifoID, obs, test_vecs(i), "Rx Value");
      wait for tperiod_CLK * 2;
    end loop;

    -- Check that the VC interface blocks as expected.
    for i in VEC_LEN/2 to VEC_LEN-1 loop
      Get(FifoRec, obs);
      AffirmIfEqual(fifoID, obs, test_vecs(i), "Rx Value");
    end loop;

    CheckFifoCounts(FifoRec, fifoID, 0, VEC_LEN, VEC_LEN);

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process RxProc;


  TxProc : process
    variable ID : AlertLogIDType;
    variable cnt : integer;
  begin

    ID := NewId("Tx Proc");
    SetLogEnable(ID, INFO, TRUE);

    WR_EN <= '0';
    DIN <= (others => '0');

    wait until RESET_n = '1';


    wait for tperiod_CLK * 10;

    -- Fill the queue
    for i in 0 to VEC_LEN-1 loop
      DIN <= test_vecs(i);
      FifoWriteHandshake(WR_EN, WR_ACK);
      wait until WR_ACK = '0';

      wait for tperiod_CLK * 10;

    end loop;

    WaitForBarrier(testDone);
    wait;

  end process TxProc;


end rx_blocking;

configuration rx_blocking of TbFifoVC is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(rx_blocking);
    end for;
  end for;
end rx_blocking;
