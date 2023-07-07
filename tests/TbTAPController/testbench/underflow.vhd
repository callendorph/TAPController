
architecture underflow of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin

  ControlProc : process
    begin
      TapTestSetup(underflow'SIMPLE_NAME);

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

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_TLR, "Check Reset State");

    wait for tperiod_CLK*2;

    -- Put the device in BYPASS mode
    din <= to_slv(16#0F#, DATA_WIDTH);
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
    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"20000000", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(4, BWIDTH), "Check Bits OUT");

    -- Generate the Read Ack - this way the overflow
    --   flag does not trigger
    Read_Handshake(dout_valid, dout_ack, clk);

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, ir, BYPASS, "Check IR - BYPASS");

    -- We are going to do two writes, but the second write will
    --   be delayed. This will cause the controller to underflow
    --   and transition to the pause state.

    din <= to_slv(16#0A#, DATA_WIDTH);
    bits_in <= to_slv(4, BWIDTH);
    dr_ir <= '0';
    -- We are going to push two writes in a row - but
    --  the second write will be delayed.
    end_of_scan <= '0';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    -- Value should be locked in now - so we can
    --  remove the inputs.
    din <= (others => '0');
    bits_in <= (others => '0');

    Wait_For_State(testID, DevRec, S_SEL_DR, 10);
    Wait_For_State(testID, DevRec, S_PAUSE_DR, 100);

    AffirmIfEqual(testID, under_flow, '1', "Expected Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_PAUSE_DR, "Expect the PAUSE state");

    WaitForClock(DevRec, 10);

    din <= to_slv(16#05#, DATA_WIDTH);
    bits_in <= to_slv(4+1, BWIDTH);
    dr_ir <= '0';
    -- This is the second write - this should complete the write
    end_of_scan <= '1';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    wait for tperiod_CLK*1;

    -- The write transaction clears the underflow
    -- flag here.
    AffirmIfEqual(testID, under_flow, '0', "Expected Underflow to Clear");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    Wait_For_State(testID, DevRec, S_IDLE, 100);

    -- Read the response value from the output
    assert DOUT_VALID = '1' report "Invalid DOUT_VALID";
    assert DOUT = X"5A000000" report "Invalid DOUT";
    assert BITS_OUT = to_slv(9, BWIDTH) report "Invalid BITS_OUT";

    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"5A000000", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(9, BWIDTH), "Check Bits OUT");

    Read_Handshake(dout_valid, dout_ack, clk);


    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process;

end underflow;

configuration underflow of TbTAPController is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(underflow);
    end for;
  end for;
end underflow;
