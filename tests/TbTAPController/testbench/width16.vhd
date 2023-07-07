----------------------------------------------
-- This file contains a very basic testbench
-- for the TAP Controller. The idea is to just
-- show that read/write from the IR and DR
-- are working. This doesn't test many of the corner
-- conditions - it is only meant to be a starting
-- point for further testing.
----------------------------------------------

architecture width16 of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin

  ControlProc : process
    begin
      TapTestSetup(width16'SIMPLE_NAME);

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
    AffirmIfEqual(testID, dout, X"2000", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(4, BWIDTH), "Check Bits OUT");

    -- Generate the Read Ack - this way the overflow
    --   flag does not trigger
    Read_Handshake(dout_valid, dout_ack, clk);

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, ir, BYPASS, "Check IR - BYPASS");

    -- Device is in BYPASS mode now - so we should be able to send a
    --   request through and see the same message echo'd back
    --   one bit delayed.

    din <= to_slv(16#A55#, DATA_WIDTH);
    bits_in <= to_slv(12 + 1, BWIDTH);

    dr_ir <= '0'; -- Write through the data register seq
    end_of_scan <= '1';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    Wait_For_State(testID, DevRec, S_SEL_DR, 10);
    Wait_For_State(testID, DevRec, S_IDLE, 100);

    -- Read the response value from the output
    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"A550", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(12 + 1, BWIDTH), "Check Bits OUT");

    assert DOUT_VALID = '1' report "Invalid DOUT_VALID";
    assert DOUT = X"A550" report "Invalid DOUT";
    assert BITS_OUT = to_slv(12 + 1, BWIDTH) report "Invalid BITS_OUT";

    -- Generate the Read Ack
    Read_Handshake(dout_valid, dout_ack, clk);

    wait for tperiod_CLK*5;

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process;

end width16;

configuration width16 of TbTAPController is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(width16);
    end for;
  end for;
end width16;
