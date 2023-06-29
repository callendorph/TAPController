
use work.FifoTbPkg.all;

--
-- Basic Fifo Unit test for the Fifo verification component.
--   None of this is intended to be instantiated.
architecture BasicTest of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin
  ControlProc : process
    begin
      SetTestName("Fifo_BasicTest");
      SetLogEnable(PASSED, TRUE);

      wait for 0 ns;
      -- These options are used to format the log output.
      --   they don't affect the simulation in any way.
      SetAlertLogOptions(WriteTimeLast => FALSE);
      SetAlertLogOptions(TimeJustifyAmount => 16);
      SetAlertLogJustify;

      TranscriptOpen(OSVVM_RESULTS_DIR & "Fifo_BasicTest.txt");
      -- Write to both the console and file.
      SetTranscriptMirror(TRUE);

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
    variable txCount, rxCount, obsCount : integer;
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

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 0, "Fifo Count");

    GetTxCount(FifoRec, txCount);
    AffirmIfEqual(FifoID, txCount, 0, "Transmit Count");

    GetRxCount(FifoRec, rxCount);
    AffirmIfEqual(FifoID, rxCount, 0, "Read Count");

    -- Write Values - These are full-handshake writes
    --  with de-assertion of ACK at the end.
    DIN <= X"F_AABBCCDD";
    FifoWriteHandshake(WR_EN, WR_ACK);
    wait until WR_ACK = '0';

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 1, "Fifo Count");

    DIN <= X"F_00112233";
    FifoWriteHandshake(WR_EN, WR_ACK);
    wait until WR_ACK = '0';

    GetTxCount(FifoRec, txCount);
    AffirmIfEqual(FifoID, txCount, 2, "Transmit Count");

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 2, "Fifo Count");

    GetRxCount(FifoRec, rxCount);
    AffirmIfEqual(FifoID, rxCount, 0, "Read Count");

    Get(FifoRec, obs);
    AffirmIfEqual(FifoID, obs, X"F_AABBCCDD", "Rx 1");

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 1, "Fifo Count");

    GetRxCount(FifoRec, rxCount);
    AffirmIfEqual(FifoID, rxCount, 1, "Read Count");

    Get(FifoRec, obs);
    AffirmIfEqual(FifoID, obs, X"F_00112233", "Rx 2");

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 0, "Fifo Count");

    GetRxCount(FifoRec, rxCount);
    AffirmIfEqual(FifoID, rxCount, 2, "Read Count");


    SendAsync(FifoRec, X"A_AABBCCDD");
    WaitForClock(FifoRec, 2);
    SendAsync(FifoRec, X"A_55443322");
    WaitForClock(FifoRec, 2);

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 2, "Fifo Count");

    GetTxCount(FifoRec, txCount);
    AffirmIfEqual(fifoID, txCount, 4, "Transmit Count");

    FifoReadHandshake(DOUT, VALID, RD_EN, obs, tperiod_CLK);
    AffirmIfEqual(FifoID, obs, X"A_AABBCCDD", "Rx 3");

    WaitForClock(FifoRec, 2);

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 1, "Fifo Count");

    GetRxCount(FifoRec, rxCount);
    AffirmIfEqual(FifoID, rxCount, 3, "Read Count");

    GetTxCount(FifoRec, txCount);
    AffirmIfEqual(fifoID, txCount, 4, "Transmit Count");

    FifoReadHandshake(DOUT, VALID, RD_EN, obs, tperiod_CLK);
    AffirmIfEqual(FifoID, obs, X"A_55443322", "Rx 4");

    GetCount(FifoRec, obsCount);
    AffirmIfEqual(FifoID, obsCount, 0, "Fifo Count");

    GetRxCount(FifoRec, rxCount);
    AffirmIfEqual(FifoID, rxCount, 4, "Read Count");

    GetTxCount(FifoRec, txCount);
    AffirmIfEqual(fifoID, txCount, 4, "Transmit Count");

    -- Test the option accesssors.
    GetFifoWidth(FifoRec, widthVal);
    AffirmIfEqual(fifoID, widthVal, 36, "Width Check");
    GetFifoDepth(FifoRec, depthVal);
    AffirmIfEqual(fifoID, depthVal, 8, "Depth Check");

    WaitForClock(FifoRec, 2);

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process TxProc;

end BasicTest;

configuration Fifo_BasicTest of TbFifoVC is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(BasicTest);
    end for;
  end for;
end Fifo_BasicTest;
