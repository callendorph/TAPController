
architecture long_chain of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

begin

  ControlProc : process
    begin
      TapTestSetup(long_chain'SIMPLE_NAME);

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
    variable avoid_states : JTAG_STATE_ARRAY_t(1 downto 0) := (
      S_PAUSE_DR, S_TLR
      );

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

    FORCE_RESET <= '1';

    WaitForClock(DevRec, 10);

    FORCE_RESET <= '0';

    GetJTAGState(DevRec, state);
    AffirmIf(testID, state = S_TLR, "Check Reset State");

    -- Set the Boundary Scan Register Value via the
    --  Jtag Device Verification component
    Send(DevRec, X"00112233_44556677");

    wait for tperiod_CLK*2;

    din <= to_slv(16#00#, DATA_WIDTH);
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

    AffirmIfEqual(testID, ir, EXTEST, "Check IR - EXTEST");

    -- Device is in EXTEST mode now - so we should be able to
    --   sample and read back the BSR

    din <= to_slv(16#0#, DATA_WIDTH);
    bits_in <= to_slv(32, BWIDTH);

    dr_ir <= '0'; -- Write through the data register seq
    -- Two transactions for all 64 bits.
    end_of_scan <= '0';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    WaitForClock(DevRec, 2);

    -- Write through the second 32-bits of the transaction.
    end_of_scan <= '1';
    Write_Handshake(we, wack, clk);

    -- Wait for the DOUT_VALID to assert on the first 32-bits
    -- and then do a read.
    wait until DOUT_VALID = '1';

    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"44556677", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(32, BWIDTH), "Check Bits OUT");

    -- Generate the Read Ack
    Read_Handshake(dout_valid, dout_ack, clk);

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    -- Now wait for the completion of the chain - we expect
    --  this sequence to avoid the PAUSE state.
    Wait_For_State_With_Avoids(testID, DevRec, S_IDLE, avoid_states, 400);

    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"00112233", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(32, BWIDTH), "Check Bits OUT");


    -- Generate the Read Ack
    Read_Handshake(dout_valid, dout_ack, clk);

    wait for tperiod_CLK*5;

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, bs, X"00000000_00000000", "Check Written BSR");
    ----------------------------------------
    -- Repeat this test but instead of
    --  two 32-bit transactions, we're going to
    --  do 4 variable length transactions.
    ----------------------------------------

    din <= to_slv(16#60AA1#, DATA_WIDTH);
    bits_in <= to_slv(20, BWIDTH);

    dr_ir <= '0'; -- Write through the data register seq
    -- 4 transactions.
    end_of_scan <= '0';

    wait for tperiod_CLK*1;

    Write_Handshake(we, wack, clk);

    WaitForClock(DevRec, 2);

    din <= to_slv(16#05502#, DATA_WIDTH);
    bits_in <= to_slv(20, BWIDTH);
    end_of_scan <= '0';

    Write_Handshake(we, wack, clk);

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    -- We need to read the dout register to avoid
    --  an overflow
    --
    wait until DOUT_VALID = '1';

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"44556677", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(32, BWIDTH), "Check Bits OUT");

    -- Generate the Read Ack
    Read_Handshake(dout_valid, dout_ack, clk);

    -- Finish out the remaining two transactions

    din <= to_slv(16#0302#, DATA_WIDTH);
    bits_in <= to_slv(10, BWIDTH);
    end_of_scan <= '0';

    Write_Handshake(we, wack, clk);

    WaitForClock(DevRec, 2);

    din <= to_slv(16#3444#, DATA_WIDTH);
    bits_in <= to_slv(14, BWIDTH);
    end_of_scan <= '1';

    Write_Handshake(we, wack, clk);

    Wait_For_State_With_Avoids(testID, DevRec, S_IDLE, avoid_states, 400);

    AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
    AffirmIfEqual(testID, dout, X"00112233", "Check DOUT");
    AffirmIfEqual(testID, bits_out, to_slv(32, BWIDTH), "Check Bits OUT");

    -- Generate the Read Ack
    Read_Handshake(dout_valid, dout_ack, clk);

    -- Check that the BSR register got updated by what we
    --  wrote to the device.
    Get(DevRec, obs);
    ExtractRegs(obs, ir, bs);

    AffirmIfEqual(testID, bs, X"D1130205_50260AA1", "Check Written BSR");

    AffirmIfEqual(testID, under_flow, '0', "No Underflow");
    AffirmIfEqual(testID, over_flow, '0', "No Overflow");

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process;

end long_chain;

configuration long_chain of TbTAPController is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(long_chain);
    end for;
  end for;
end long_chain;
