
use work.FifoTbPkg.all;

--
-- Basic Fifo Unit test for the Fifo verification component.
--   None of this is intended to be instantiated.
architecture basic_test of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin
  ControlProc : process
    begin
      FifoTestSetup(basic_test'SIMPLE_NAME, OSVVM_RESULTS_DIR);

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
    variable widthVal, depthVal : integer;
    variable obs : Fifo_Out_DataType;
  begin

    GetAlertLogID(FifoRec, fifoID);
    SetLogEnable(fifoID, INFO, TRUE);

    WR_EN <= '0';
    DIN <= (others => '0');
    RD_EN <= '0';

    wait until RESET_n = '1';

    WaitForClock(FifoRec, 2);

    CheckFifoCounts(FifoRec, FifoID, 0, 0, 0);

    -- Write Values - These are full-handshake writes
    --  with de-assertion of ACK at the end.
    DIN <= X"F_AABBCCDD";
    FifoWriteHandshake(WR_EN, WR_ACK);
    wait until WR_ACK = '0';

    CheckFifoCounts(FifoRec, FifoID, 1, 1, 0);

    DIN <= X"F_00112233";
    FifoWriteHandshake(WR_EN, WR_ACK);
    wait until WR_ACK = '0';

    CheckFifoCounts(FifoRec, FifoID, 2, 2, 0);

    Get(FifoRec, obs);
    AffirmIfEqual(FifoID, obs, X"F_AABBCCDD", "Rx 1");

    CheckFifoCounts(FifoRec, FifoID, 1, 2, 1);

    Get(FifoRec, obs);
    AffirmIfEqual(FifoID, obs, X"F_00112233", "Rx 2");

    CheckFifoCounts(FifoRec, FifoID, 0, 2, 2);

    SendAsync(FifoRec, X"A_AABBCCDD");
    WaitForClock(FifoRec, 2);
    SendAsync(FifoRec, X"A_55443322");
    WaitForClock(FifoRec, 2);

    CheckFifoCounts(FifoRec, FifoID, 2, 4, 2);

    FifoReadHandshake(DOUT, VALID, RD_EN, obs, tperiod_CLK);
    AffirmIfEqual(FifoID, obs, X"A_AABBCCDD", "Rx 3");

    WaitForClock(FifoRec, 2);

    CheckFifoCounts(FifoRec, FifoID, 1, 4, 3);

    FifoReadHandshake(DOUT, VALID, RD_EN, obs, tperiod_CLK);
    AffirmIfEqual(FifoID, obs, X"A_55443322", "Rx 4");

    CheckFifoCounts(FifoRec, FifoID, 0, 4, 4);

    -- Test the option accessors.
    GetFifoWidth(FifoRec, widthVal);
    AffirmIfEqual(fifoID, widthVal, 36, "Width Check");
    GetFifoDepth(FifoRec, depthVal);
    AffirmIfEqual(fifoID, depthVal, 8, "Depth Check");

    WaitForClock(FifoRec, 2);

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process TxProc;

end basic_test;

configuration Fifo_BasicTest of TbFifoVC is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(basic_test);
    end for;
  end for;
end Fifo_BasicTest;
