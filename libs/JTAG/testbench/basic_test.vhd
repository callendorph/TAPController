-- Basic Unit test for the Jtag Device Verification Component

architecture basic_test of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin
  ControlProc : process
    constant name : string := basic_test'SIMPLE_NAME;
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

    TCK <= JTAG_CLK;


    StimProc : process
      variable testID : AlertLogIDType;
      variable state : JTAG_STATE_t;
      variable obs : JtagTb_Out_DataType;
      variable ir : InstructionReg;
      variable expBs, bs : BoundaryScanReg;
      variable wrBs : BoundaryScanReg;
      variable idIn, idOut : IdCodeReg;
      variable numTrans : integer;
    begin

    GetAlertLogID(DevRec, testID);
    SetLogEnable(testID, INFO, TRUE);

    TDI <= '0';
    TMS <= '0';

    wait until RESET_n = '1';

    TMS <= '1';

    WaitForClock(DevRec, 1);

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_SEL_DR, "Entry to Select DR");

    WaitForClock(DevRec, 1);

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_SEL_IR, "Entry to Select IR");

    WaitForClock(DevRec, 1);

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_TLR, "Entry to TestLogicReset");

    WaitForClock(DevRec, 1);

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_TLR, "Stay in TLR");

    WaitForClock(DevRec, 1);
    TMS <= '0';
    WaitForClock(DevRec, 1);

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_IDLE, "Entry to IDLE");


    -- Test out some accessors to the Device VC

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, ir, IDCODE, "Check IR - IDCODE");

    -- Write a new Boundary scan register value
    --   that gets loaded on capture.
    expBs := X"AAAAAAAA_55555555";
    Send(DevRec, expBs);

    -- Run the JTAG statemachine through to update the
    --  IR to SAMPLE
    Log(testID,
        "Starting IR Update Sequence",
        INFO
        );

    UpdateInstruction(TMS, TDI, TCK, SAMPLE);

    -- Run the data sequence to capture and clock
    --   out the boundary scan register

    wrBs := X"11111111_00000000";
    UpdateDataSequence(
      TMS, TDI, TCK, TDO, wrBs, bs, bs'length
    );

    AffirmIfEqual(testID, bs, expBs, "Check BS Read");

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, ir, SAMPLE, "Check IR - SAMPLE");
    AffirmIfEqual(testID, bs, wrBs, "Check BS Write");

    -- Update back to IDCODE and then
    --   read out the IDCODE

    Log(testID, "Reseting IR to IDCode", INFO);

    UpdateInstruction(TMS, TDI, TCK, IDCODE);

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, ir, IDCODE, "Check IR - IDCODE");

    idIn := (others => '0');
    UpdateDataSequence(
      TMS, TDI, TCK, TDO, idIn, idOut, idOut'length
    );

    AffirmIfEqual(testID, idOut, X"00112233", "Check Default IDCode");

    -- Use a command to set the ID code
    SetIdCode(DevRec, 16#55443322#);

    Log(testID, "Reading Custom IDCode", INFO);

    idIn := (others => '0');
    UpdateDataSequence(
      TMS, TDI, TCK, TDO, idIn, idOut, idOut'length
    );

    AffirmIfEqual(testID, idOut, X"55443322", "Check Set IDCode");

    GetTransactionCount(DevRec, numTrans);
    AffirmIfEqual(testID, numTrans, 5, "Check Num Transactions");

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

    end process StimProc;

end basic_test;

configuration basic_test of TbJtagDevVC is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(basic_test);
    end for;
  end for;
end basic_test;
