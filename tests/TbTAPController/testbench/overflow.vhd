
architecture overflow of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin

  ControlProc : process
    begin
      TapTestSetup(overflow'SIMPLE_NAME);

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

  -- Tickle the signals
  stim : process
    variable testID : AlertLogIDType;
    variable state : JTAG_STATE_t;

    variable obs : JtagTb_Out_DataType;
    variable ir : InstructionReg;
    variable bs : BoundaryScanReg;

    variable ID_val : integer := 16#55AA1122#;
    variable ID : IdCodeReg := to_slv(ID_val, ID_WIDTH);
  begin

    GetAlertLogID(DevRec, testID);
    SetLogEnable(testID, INFO, TRUE);

    force_reset <= '0';
    dr_ir <= '0';
    end_of_scan <= '0';
    we <= '0';
    din <= (others => '0');
    bits_in <= (others => '0');
    dout_ack <= '0';

    wait until RESET_n = '1';

    WaitForClock(DevRec, 1);

    force_reset <= '1';

    WaitForClock(DevRec, 10);

    force_reset <= '0';

    SetIdCode(DevRec, ID_val);

    GetJTAGState(DevRec, state);

    AffirmIf(testID, state = S_TLR, "Check Reset State");

    wait for tperiod_CLK*2;

    din <= to_slv(16#02#, DATA_WIDTH);
    bits_in <= to_slv(4, BWIDTH);
    dr_ir <= '1';
    end_of_scan <= '1';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    -- Value should be locked in now - so we can
    --  remove the inputs.
    din <= (others => '0');
    bits_in <= (others => '0');

    -- There is a race condition here where if we don't at least
    --   let it get out of idle - then we will never wait for
    --   the state machine to return to idle.
    Wait_For_State(testID, DevRec, S_SEL_DR, 10);
    Wait_For_State(testID, DevRec, S_IDLE, 100);

    -- Read the response value from the output
    assert dout_valid = '1' report "Invalid DOUT_VALID";
    assert dout = X"20000000" report "Invalid DOUT";
    assert bits_out = to_slv(4, BWIDTH) report "Invalid BITS_OUT";

    -- We DO NOT trigger a read transaction here
    --   because we want to trigger an overflow on the
    --   next transaction.
    -- Read_Handshake(dout_valid, dout_ack, clk);

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, ir, IDCODE, "Check IR - IDCODE");

    -- IDCODE means we should be getting the ID register from
    --   the device.

    din <= to_slv(16#0#, DATA_WIDTH);
    bits_in <= to_slv(32, BWIDTH);

    dr_ir <= '0'; -- Write through the data register seq
    end_of_scan <= '1';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    Wait_For_State(testID, DevRec, S_SEL_DR, 10);
    Wait_For_State(testID, DevRec, S_IDLE, 100);

    -- Read the response value from the output
    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, ID, "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(32, BWIDTH), "Check Bits OUT");

    wait for tperiod_CLK*5;

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '1', "Expected Overflow");


    -- Generate the Read Ack
    Read_Handshake(dout_valid, dout_ack, clk);

    wait for tperiod_CLK;

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "Overflow Clear on Read");


    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process;

end overflow;

configuration overflow of TbTAPController is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(overflow);
    end for;
  end for;
end overflow;
