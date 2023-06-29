-- Blocking Fifo Unit test for the Fifo verification component.
--   The goal is to show that the transmits functions will block
--   waiting for the FIFO if it is full.
architecture tx_blocking of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;
  constant DEPTH : integer := 8;
  constant WIDTH : integer := 36;

  type test_vector_array is array (natural range <>) of std_logic_vector;
  constant test_vecs : test_vector_array(0 to DEPTH+2)(WIDTH-1 downto 0) := (
    X"1_10001000",
    X"2_10002000",
    X"3_10003000",
    X"4_F000A000",
    X"5_0A000500",
    X"6_00A00050",
    X"7_000A0005",
    X"8_0000A002",
    X"9_0F001001",
    X"A_0F002002",
    X"B_0F003003"
    );

begin
  ControlProc : process
    begin
      FifoTestSetup(tx_blocking'SIMPLE_NAME, OSVVM_RESULTS_DIR);

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

  TxProc : process
    variable fifoID : AlertLogIDType;
    variable cnt : integer;
  begin

    GetAlertLogID(FifoRec, fifoID);
    SetLogEnable(fifoID, INFO, TRUE);

    WR_EN <= '0';
    DIN <= (others => '0');

    wait until RESET_n = '1';

    WaitForClock(FifoRec, 2);

    CheckFifoCounts(FifoRec, FifoID, 0, 0, 0);

    -- Fill the queue
    for i in 0 to DEPTH-1 loop
      Send(FifoRec, test_vecs(i));
      WaitForClock(FifoRec, 1);
    end loop;

    CheckFifoCounts(FifoRec, FifoID, 8, 8, 0);

    -- Attempt to write to the queue again but these
    --  next two requests should block until the
    --  receiving process catches up.
    for i in DEPTH to DEPTH+2 loop
      Send(FifoRec, test_vecs(i));
      WaitForClock(FifoRec, 2);
    end loop;

    -- Wait until the FIFO is empty and
    --  check that we sent and received the right quantities.
    while TRUE loop

      GetCount(FifoRec, cnt);
      if cnt = 0 then
        exit;
      end if;

      WaitForClock(FifoRec, 2);

    end loop;

    CheckFifoCounts(FifoRec, FifoID, 0, DEPTH+2+1, DEPTH+2+1);

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process TxProc;

  RxProc : process
    variable ID : AlertLogIDType;
    variable obs : Fifo_Out_DataType;
  begin

    RD_EN <= '0';
    ID := NewId("Rx Proc");

    wait until RESET_n = '1';

    -- The goal here is to make it so that
    --  the transmit process definitely had to block
    --  when attempting to send one of the last transactions.
    wait for tperiod_CLK * 30;

    for i in 0 to DEPTH+2 loop
      wait for tperiod_CLK * 2;
      FifoReadHandshake(DOUT, VALID, RD_EN, obs, tperiod_CLK);
      AffirmIfEqual(ID, obs, test_vecs(i), "Rx Value");
    end loop;

    WaitForBarrier(testDone);
    wait;

  end process RxProc;

end tx_blocking;

configuration tx_blocking of TbFifoVC is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(tx_blocking);
    end for;
  end for;
end tx_blocking;
