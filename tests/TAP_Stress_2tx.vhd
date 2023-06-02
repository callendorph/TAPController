-- This testbench attempts to do a stress test on
-- two transaction chain sequences.
--
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.JTAG.all;
use work.BitTools.all;
use work.CompDefs.all;
use work.TestTools.all;


entity TAP_Stress_2tx is
end TAP_Stress_2tx;

architecture sim of TAP_Stress_2tx is

  constant clk_period : time := 10.0 ns;
  constant tck_period : time := 100.0 ns;

  constant WIDTH : integer := 32;
  constant BWIDTH : integer := Log2(WIDTH);

  signal CLK, RESET_n, JTAG_CLK : std_logic;

  signal TDI, TDO, TMS, TCK : std_logic;
  signal FORCE_RESET, DR_IR, END_OF_SCAN, WE, WACK : std_logic;
  signal DIN : std_logic_vector(WIDTH-1 downto 0);
  signal BITS_IN : std_logic_vector(BWIDTH-1 downto 0);
  signal DOUT : std_logic_vector(WIDTH-1 downto 0);
  signal BITS_OUT : std_logic_vector(BWIDTH-1 downto 0);
  signal UNDER_FLOW, SCAN_DONE, OVER_FLOW : std_logic;
  signal DOUT_VALID, DOUT_ACK : std_logic;

  signal IR_view : std_logic_vector(3 downto 0);
  signal BSR_view : std_logic_vector(63 downto 0);
  signal BS : std_logic_vector(63 downto 0);
  signal ID : std_logic_vector(31 downto 0);

  signal DUT_state : JTAG_STATE_t;

  signal END_SIM : std_logic := '0';

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

  UUT : TAPController
    generic map (
      DATA_WIDTH => WIDTH
    )
    port map (
      CLK => CLK,
      RESET_n => RESET_n,
      JTAG_CLK => JTAG_CLK,
      -- JTAG
      TDI => TDI,
      TDO => TDO,
      TMS => TMS,
      TCK => TCK,
      -- User Interface
      FORCE_RESET => FORCE_RESET,
      DR_IR => DR_IR,
      DIN => DIN,
      BITS_IN => BITS_IN,
      END_OF_SCAN => END_OF_SCAN,
      WE => WE,
      WACK => WACK,
      UNDER_FLOW => UNDER_FLOW,
      SCAN_DONE => SCAN_DONE,
      DOUT => DOUT,
      BITS_OUT => BITS_OUT,
      DOUT_VALID => DOUT_VALID,
      DOUT_ACK => DOUT_ACK,
      OVER_FLOW => OVER_FLOW
      );

  DUT : JTAG_DUT
    port map (
      CLK => CLK,
      RESET_n => RESET_n,

      TDI => TDI,
      TDO => TDO,
      TMS => TMS,
      TCK => TCK,

      IR => IR_view,
      BS => BS,
      BSR => BSR_view,
      ID => ID,
      curr_state => DUT_state
    );

  -- Setup the clocks for the simulation
  sys_clk : process
  begin
    Cycle_Clock(CLK, END_SIM, clk_period);
  end process;

  tck_clk : process
  begin
    Cycle_Clock(JTAG_CLK, END_SIM, tck_period);
  end process;

  -- Tickle the signals
  stim : process
    variable avoid_states : JTAG_STATE_ARRAY_t(1 downto 0) := (S_PAUSE_DR,S_TLR);
    variable msg_len, trans_len : integer;
    variable max_val: integer;
    variable msg_mask, exp_val : std_logic_vector(WIDTH-1 downto 0);
  begin
    ID <= X"55AA1122";
    BS <= X"0011223344556677";

    RESET_n <= '0';
    FORCE_RESET <= '0';
    DR_IR <= '0';
    END_OF_SCAN <= '0';
    WE <= '0';
    DIN <= (others => '0');
    BITS_IN <= (others => '0');
    DOUT_ACK <= '0';

    wait for clk_period*2;

    RESET_n <= '1';

    wait for clk_period*10;

    FORCE_RESET <= '1';
    -- Reset Chain
    wait for tck_period * 6;

    FORCE_RESET <= '0';

    assert DUT_state = S_TLR report "Invalid DUT State";

    wait for clk_period*2;

    DIN <= to_slv(16#0F#, WIDTH);
    BITS_IN <= to_slv(4, BWIDTH);
    DR_IR <= '1';
    END_OF_SCAN <= '1';

    wait for clk_period*1;

    Write_Handshake(WE, WACK, clk_period, 100);

    -- Value should be locked in now - so we can
    --  remove the inputs.
    DIN <= (others => '0');
    BITS_IN <= (others => '0');

    -- There is a race condition here where if we don't at least
    --   let it get out of idle - then we will never wait for
    --   the state machine to return to idle.
    Wait_For_State(DUT_state, S_SEL_DR, tck_period, 10);
    Wait_For_State(DUT_state, S_IDLE, tck_period, 100);

    -- Read the response value from the output
    assert DOUT_VALID = '1' report "Invalid DOUT_VALID";
    assert DOUT = X"20000000" report "Invalid DOUT";
    assert BITS_OUT = to_slv(4, BWIDTH) report "Invalid BITS_OUT";

    -- Generate the Read Ack - this way the overflow
    --   flag does not trigger
    Read_Handshake(DOUT_VALID, DOUT_ACK, clk_period);

    assert UNDER_FLOW = '0';
    assert OVER_FLOW = '0';

    assert IR_view = "1111" report "Failed to set IR to Bypass";

    -- Device is in BYPASS mode now - so we should be able to send a
    --   request through and see the same message echo'd back
    --   one bit delayed.

    for k in 0 to MSG_BIT_LENGTHS'LENGTH-1 loop
      msg_len := MSG_BIT_LENGTHS(k);
      assert msg_len mod 2 = 0 report "Invalid Message Len";
      trans_len := msg_len / 2;
      max_val := 2**trans_len;
      msg_mask := make_left_mask(msg_len, WIDTH);

      for j in 0 to max_val-1 loop

        DIN <= to_slv(j, WIDTH);
        BITS_in <= to_slv(trans_len, BWIDTH);
        DR_IR <= '0'; -- Write through the data register seq
        END_OF_SCAN <= '0';

        wait for clk_period*1;

        Write_Handshake(WE, WACK, clk_period, 100);

        wait for clk_period*1;

        -- Note - I've got to stuff the extra bit
        -- because the bypass register
        DIN <= to_slv(j, WIDTH);
        BITS_in <= to_slv(trans_len+1, BWIDTH);
        DR_IR <= '0'; -- Write through the data register seq
        END_OF_SCAN <= '1';

        Write_Handshake(WE, WACK, clk_period, trans_len * 75);

        Wait_For_State_With_Avoids(DUT_state, S_IDLE, avoid_states, tck_period, 400);

        -- Read the response value from the output
        assert DOUT_VALID = '1' report "Invalid DOUT_VALID";
        exp_val := to_slv(j, trans_len) & to_slv(j,trans_len) & to_slv(0, WIDTH-msg_len);
        assert (DOUT and msg_mask) = exp_val
          report "Failed DOUT Check: MSG_LEN=" & integer'image(msg_len)
          & " OBS=" & to_string(DOUT and msg_mask)
          & " EXP=" & to_string(exp_val);
        assert BITS_OUT = to_slv(msg_len + 1, BWIDTH) report "Invalid BITS_OUT";

        -- Generate the Read Ack
        Read_Handshake(DOUT_VALID, DOUT_ACK, clk_period);

        wait for clk_period*5;

        assert UNDER_FLOW = '0';
        assert OVER_FLOW = '0';

      end loop;

    end loop;


    END_SIM <= '1';
    wait;

  end process;

end sim;