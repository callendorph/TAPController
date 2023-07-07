-- This testbench attempts to do a stress test on
-- two transaction chain sequences.
--

architecture stress_2tx of TestCtrl is

  signal testActive  : boolean := TRUE;
  signal testDone    : integer_barrier := 1;

  type MSG_BITS_t is array(natural range<>) of integer;

  -- Total bits over two transactions
  --  Values must be even and less than or equal to 30
  -- Note these values take about 45 seconds to run
  --   and 300MB of disk.
  -- constant MSG_BIT_LENGTHS : MSG_BITS_t(3 downto 0) := (
  --   0 => 6, 1 => 14, 2 => 22, 3 => 30
  -- );

  constant MSG_BIT_LENGTHS : MSG_BITS_t(1 downto 0) := (
    0 => 6, 1 => 14
  );

begin

  ControlProc : process
    begin
      TapTestSetup(stress_2tx'SIMPLE_NAME);

      -- Wait for Design Reset
      wait until RESET_n = '1';
      ClearAlerts;

      -- Wait for test to finish
      WaitForBarrier(TestDone, 100 ms);
      AlertIf(now >= 100 ms, "Test finished due to timeout");
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

    variable avoid_states : JTAG_STATE_ARRAY_t(1 downto 0) := (S_PAUSE_DR,S_TLR);
    variable msg_len, trans_len : integer;
    variable max_val: integer;
    variable msg_mask, exp_val : std_logic_vector(DATA_WIDTH-1 downto 0);
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

    -- Device is in BYPASS mode now - so we should be able to send a
    --   request through and see the same message echo'd back
    --   one bit delayed.

    for k in 0 to MSG_BIT_LENGTHS'LENGTH-1 loop
      msg_len := MSG_BIT_LENGTHS(k);
      assert msg_len mod 2 = 0 report "Invalid Message Len";
      trans_len := msg_len / 2;
      max_val := 2**trans_len;
      msg_mask := make_left_mask(msg_len, DATA_WIDTH);

      for j in 0 to max_val-1 loop

        din <= to_slv(j, DATA_WIDTH);
        bits_in <= to_slv(trans_len, BWIDTH);
        dr_ir <= '0'; -- Write through the data register seq
        end_of_scan <= '0';

        wait for tperiod_CLK*1;

        Write_Handshake(we, wack, clk);

        wait for tperiod_CLK*1;

        -- Note - I've got to stuff the extra bit
        -- because the bypass register
        din <= to_slv(j, DATA_WIDTH);
        bits_in <= to_slv(trans_len+1, BWIDTH);
        dr_ir <= '0'; -- Write through the data register seq
        end_of_scan <= '1';

        Write_Handshake(we, wack, clk);

        Wait_For_State_With_Avoids(testID, DevRec, S_IDLE, avoid_states, 400);

        -- Read the response value from the output

        AffirmIfEqual(testID, dout_valid, '1', "Check DOUT_VALID");
        exp_val := to_slv(j, trans_len) &
                   to_slv(j,trans_len) &
                   to_slv(0, DATA_WIDTH-msg_len);
        AffirmIfEqual(
          testID,
          (DOUT and msg_mask),
          exp_val,
          "DOUT Check: MSG_LEN=" & integer'image(msg_len)
          & " OBS=" & to_hxstring(DOUT and msg_mask)
          & " EXP=" & to_hxstring(exp_val)
          );
        AffirmIfEqual(testID, bits_out, to_slv(msg_len + 1, BWIDTH), "Check Bits OUT");


        -- Generate the Read Ack
        Read_Handshake(dout_valid, dout_ack, clk);

        wait for tperiod_CLK*5;

        AffirmIfEqual(testID, under_flow, '0', "No Underflow");
        AffirmIfEqual(testID, over_flow, '0', "No Overflow");

      end loop;

    end loop;

    testActive <= FALSE;

    WaitForBarrier(testDone);
    wait;

  end process;

end stress_2tx;

configuration stress_2tx of TbTAPController is
  for TestHarness
    for TestDriver : TestCtrl
      use entity work.TestCtrl(stress_2tx);
    end for;
  end for;
end stress_2tx;
