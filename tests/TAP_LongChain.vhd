library ieee;
use ieee.std_logic_1164.all;

library work;
use work.JTAG.all;
use work.BitTools.all;
use work.CompDefs.all;
use work.TestTools.all;


entity TAP_LongChain is
end TAP_LongChain;

architecture sim of TAP_LongChain is

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
    variable i : integer;
    variable avoid_states : JTAG_STATE_ARRAY_t(1 downto 0) := (S_PAUSE_DR,S_TLR);
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

    DIN <= to_slv(16#00#, WIDTH);
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

    assert IR_view = "0000" report "Failed to set IR to Bypass";

    -- Device is in EXTEST mode now - so we should be able to
    --   sample and read back the BSR

    DIN <= to_slv(16#0#, WIDTH);
    BITS_in <= to_slv(32, BWIDTH);

    DR_IR <= '0'; -- Write through the data register seq
    -- Two transactions for all 64 bits.
    END_OF_SCAN <= '0';

    wait for clk_period*1;

    Write_Handshake(WE, WACK, clk_period, 100);

    wait for tck_period *2;

    -- Write through the second 32-bits of the transaction.
    END_OF_SCAN <= '1';
    Write_Handshake(WE, WACK, clk_period, 400);

    -- Wait_For_State(DUT_state, S_SEL_DR, tck_period, 10);

    -- Wait for the DOUT_VALID to assert on the first 32-bits
    -- and then do a read.
    Wait_On(DOUT_VALID, clk_period, 400);

    assert DOUT_VALID = '1' report "Invalid DOUT_VALID";
    assert DOUT = X"44556677" report "Invalid DOUT";
    assert BITS_OUT = to_slv(32, BWIDTH) report "Invalid BITS_OUT";

    -- Generate the Read Ack
    Read_Handshake(DOUT_VALID, DOUT_ACK, clk_period);

    assert UNDER_FLOW = '0';
    assert OVER_FLOW = '0';

    -- Now wait for the completion of the chain - we expect
    --  this sequence to avoid the PAUSE state.
    Wait_For_State_With_Avoids(DUT_state, S_IDLE, avoid_states, tck_period, 400);

    -- Read the response value from the output
    assert DOUT_VALID = '1' report "Invalid DOUT_VALID";
    assert DOUT = X"00112233" report "Invalid DOUT";
    assert BITS_OUT = to_slv(32, BWIDTH) report "Invalid BITS_OUT";

    -- Generate the Read Ack
    Read_Handshake(DOUT_VALID, DOUT_ACK, clk_period);

    wait for clk_period*5;

    assert UNDER_FLOW = '0';
    assert OVER_FLOW = '0';


    END_SIM <= '1';
    wait;

  end process;

end sim;
