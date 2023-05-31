library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.BitTools.all;
use work.JTAG.all;

entity TAPController is
  generic (
    DATA_WIDTH : in integer := 32
    );
  port (
    --------------------------
    -- Synchronous Interface
    --------------------------
    CLK : in std_logic;
    RESET_n : in std_logic;

    -- This clock must be slower than CLK (at least 5x)
    --   This clock is the bit rate which we will drive
    --   the JTAG output. We will derive the 'TCK' signal
    --   from this clock rate.

    JTAG_CLK : in std_logic;

    --------------------------
    -- JTAG Interface
    --------------------------
    TDI : buffer std_logic;
    TDO : in std_logic;
    TMS : buffer std_logic;
    TCK : buffer std_logic;

    --------------------------
    -- User Interface
    --------------------------
    --   Force Reset is used to drive clock cycles into the
    --    JTAG chain with TMS held high. This causes all of the devices
    --    on the chain to enter and stay in Test Logic Reset state
    --    until the master is ready to proceed.
    FORCE_RESET : in std_logic;


    -- Instructs the tap controller to write either to
    --  1. LOW => Data Register Sequence
    --  2. HIGH => Instruction Register Sequence
    --  This signal must remain the same level through a complete
    --  scan sequence. If this value changes before end of scan
    --  occurs, unpredictable results may occur.
    DR_IR : in std_logic;
    -- Data Input - bits of data to shift on the bus. The
    --  number of valid bits is indicated by `BITS_IN`. The
    --  bits in DIN should be right adjusted - meaning that
    --  bit 0 to BITS_IN-1 are valid and bit 0 is the first
    --  bit to be output on the TDI signal.
    --
    --  This value gets buffered internally so once `WACK`
    --  has asserted, these values can change and the user
    --  can setup for the next transaction.
    DIN : in std_logic_vector(DATA_WIDTH-1 downto 0);
    BITS_IN : in std_logic_vector(Log2(DATA_WIDTH)-1 downto 0);

    -- This bit indicates whether or not this is the
    --   last chunk of data of this scan sequence or if
    --   there is more data to come. THis bit gets latched
    --   with the DIN/BITS_IN values
    --
    -- If the user asserts END_OF_SCAN with a valid
    --   DIN/BITS_IN combination then it means that the
    --   TAP controller will generate a scan sequence for these
    --   active bits only and then exit the DR/IR sequence and
    --   go back to idle.
    --
    -- If the user de-asserts END_OF_SCAN with a valid DIN/BITS_IN
    --   cominbation then it means that the TAP controller should
    --   expect more data as part of this scan sequence and not
    --   exit the DR/IR sequence. If more data is not provided
    --   before the DR/IR sequence ends - then the `UNDER_FLOW` signal
    --   will assert.
    END_OF_SCAN : in std_logic;
    -- Write Enable - Indicates that DIN, BITS_IN, and END_OF_SCAN
    --   are valid and ready to be consumed.
    WE : in std_logic;
    -- Write Acknowledge indicates that the values written by
    --  DIN/BITS_IN have been received and buffered internally.
    --  They will be clocked out over the next scan sequence.
    WACK : buffer std_logic;

    -- Output flag that indicates the TAP controller has run out
    --  of bits to push on the JTAG serial interface and must
    --  enter the 'PAUSE' state for this transaction. This
    --  is an indication that the user is not feeding data to
    --  the TAP controller fast enough.
    UNDER_FLOW : buffer std_logic;
    -- This output asserts when the TAP controller enters the
    --   UPDATE-DR or UPDATE-IR  states.
    SCAN_DONE : out std_logic;

    -- Captured data from the TDO line based on the scan sequence
    --   generated from the DIN/BITS_IN interface.
    --   DOUT contains up to `BITS_OUT` number of valid bits from
    --   DOUT[BITS_OUT-1:0]
    DOUT : out std_logic_vector(DATA_WIDTH-1 downto 0);
    BITS_OUT : out std_logic_vector(Log2(DATA_WIDTH)-1 downto 0);

    -- Indicates that the values in DOUT/BITS_OUT are valid and
    --   can be read. This will stay high until DOUT_ACK asserts
    --   then it will fall on the next CLK.
    DOUT_VALID : buffer std_logic;
    -- Handshake to indicate that the DOUT value has been read.
    DOUT_ACK : in std_logic;
    -- Output flag that indicates that the TAP controller has
    --   overwritten the last read DOUT buffer data with
    --   new data coming in. This flag is cleared when
    --   the user reads the DOUT register with a VALID/ACK
    --   handshake.
    OVER_FLOW : buffer std_logic

    );
end TAPController;

architecture rtl of TAPController is

constant BLEN : integer := BITS_IN'length;

signal curr_state, next_state : JTAG_STATE_t;

-- TCK Rise/Fall signals
signal tck_rise_en, tck_fall_en : std_logic;
signal tck_d1 : std_logic;

-- Shift Register Signals
signal din_hold, dout_hold : std_logic_vector(DATA_WIDTH-1 downto 0);
signal din_cnt, dout_cnt : unsigned(BLEN-1 downto 0);
signal EOS_hold : std_logic;
-- Observers of the input state
signal din_empty, din_last_bit, is_shifting : std_logic;
-- Command Bits for the shift operations
signal shift_din, shift_dout, enters_pause : std_logic;
signal dout_has_data, dout_is_full : std_logic;

-- @NOTE - this assumes that DATA_WIDTH is a power of 2
--   if this is not the case - then we may see errors.
constant dout_full : unsigned(BLEN-1 downto 0) := (others => '1');

-- JTAG signals
signal pre_TMS : std_logic;

begin

  -- TCK Rise and Fall Detectors
  tck_edges : process(CLK)
  begin
    if rising_edge(CLK) then
      -- Don't check RESET here because it will only cause
      --   aberrant pulses. We always want to reset to whatever
      --   the last state of TCK was.
      tck_d1 <= JTAG_CLK;
    else
      tck_d1 <= tck_d1;
    end if;
  end process tck_edges;

  tck_rise_en <= (not tck_d1) and JTAG_CLK;
  tck_fall_en <= tck_d1 and (not JTAG_CLK);

  -- JTAG bus State
  state_regs : process(CLK)
  begin
    if (rising_edge(CLK)) then
      if (RESET_n = '0') then
        curr_state <= S_IDLE;
      else
        if ( tck_rise_en = '1' ) then
          curr_state <= next_state;
        else
          curr_state <= curr_state;
        end if;
      end if;
    end if;
  end process state_regs;

  -- JTAG Bus Transitions
  jtag_transitions : process(curr_state, TMS)
  begin
    JTAG_state_transitions(curr_state, TMS, next_state);
  end process jtag_transitions;

  -----------------------------
  -- DUT Write Shift Register
  -----------------------------
  shift_regs : process(CLK)
  begin
    if rising_edge(CLK) then
      if (RESET_n = '0') then
        din_hold <= (others => '0');
        din_cnt <= (others => '0');
        EOS_hold <= '0';
        WACK <= '0';
      else
        if (shift_din = '1') then
          -- din_hold(0) is what get presented as TDI
          --  We shift values from the left to right
          din_hold <= '0' & din_hold(DATA_WIDTH-1 downto 1);
          if din_empty = '0' then
            din_cnt <= din_cnt - 1;
          else
            -- This is an underflow condition
            --  the TMS control sequence manages
            --  the transition to PAUSE to wait for
            --  the host to insert more data as needed.
            din_cnt <= din_cnt;
          end if;
          EOS_hold <= EOS_hold;
          WACK <= '0';
        else
          if (din_empty = '1' and TCK = '0' and WE = '1' ) then
            -- The user is attempting to load a new value
            --   into the din_hold register for shifting out to
            --   the DUT.
            din_hold <= DIN;
            din_cnt <= unsigned(BITS_IN);
            EOS_hold <= END_OF_SCAN;
            -- Handshake to acknowledge the new data.
            WACK <= '1';
          else
            din_hold <= din_hold;
            din_cnt <= din_cnt;
            EOS_hold <= EOS_hold;
            WACK <= '0';
          end if;
        end if;
      end if;
    end if;
  end process shift_regs;

  din_empty <= to_std_logic( din_cnt = to_unsigned(0, BLEN) );
  din_last_bit <= to_std_logic( din_cnt = to_unsigned(1, BLEN) );

  shift_din <= tck_fall_en and is_shifting and (not din_empty);

  utils : process(curr_state, pre_TMS)
  begin
    case curr_state is
      when S_SH_DR | S_SH_IR =>
        is_shifting <= '1';
        SCAN_DONE <= '0';
        enters_pause <= '0';
      when S_UP_DR | S_UP_IR =>
        is_shifting <= '0';
        SCAN_DONE <= '1';
        enters_pause <= '0';
      when S_EX1_DR | S_EX1_IR =>
        enters_pause <= not pre_TMS;
        is_shifting <= '0';
        SCAN_DONE <= '0';
      when others =>
        is_shifting <= '0';
        SCAN_DONE <= '0';
        enters_pause <= '0';
    end case;
  end process utils;

  underflow_reg : process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET_n = '0' then
        UNDER_FLOW <= '0';
      else
        if enters_pause = '1' then
          UNDER_FLOW <= '1';
        elsif WACK = '1' then
          -- Reset the Underflow bit
          --  when a write of new data is
          --  acknowledged.
          UNDER_FLOW <= '0';
        else
          UNDER_FLOW <= UNDER_FLOW;
        end if;

      end if;
    end if;
  end process underflow_reg;

  ------------------------
  -- Read Back Interface
  ------------------------
  DOUT <= dout_hold;
  BITS_OUT <= std_logic_vector(dout_cnt);

  dout_has_data <= to_std_logic( dout_cnt > to_unsigned(0, BLEN));
  dout_is_full <= to_std_logic( dout_cnt = dout_full );
  shift_dout <= tck_rise_en and is_shifting and (not dout_is_full);

  read_back : process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET_n = '0' then
        DOUT_VALID <= '0';
        dout_hold <= (others => '0');
        dout_cnt <= (others => '0');
        OVER_FLOW <= '0';
      elsif DOUT_ACK = '1' then
        -- User is attempting to read the state of the
        --   DOUT - we complete the handshake.
        DOUT_VALID <= '0';
        OVER_FLOW <= '0';
        dout_hold <= dout_hold;
        dout_cnt <= dout_cnt;
      elsif (shift_dout = '1') then
        if (tck_rise_en = '1') then
          dout_hold <= TDO & dout_hold(DATA_WIDTH-1 downto 1);
          dout_cnt <= dout_cnt + 1;
        end if;
        -- Scans can be longer than DATA_WIDTH - so we need
        --   to detect when we are full and alert the user
        --   that the buffer needs to be read.
        if dout_is_full = '1' then
          DOUT_VALID <= '1';
        else
          DOUT_VALID <= '0';
        end if;
      else
        case curr_state is
          when S_CAP_DR | S_CAP_IR =>
            -- Reset dout buffer and count
            --  if DOUT_VALID is still asserted this means there has
            --  been a buffer overflow.
            dout_hold <= (others => '0');
            dout_cnt <= (others => '0');
            if DOUT_VALID = '1' then
              OVER_FLOW <= '1';
            end if;
            DOUT_VALID <= '0';
          -- when S_SH_DR | S_SH_IR =>
          --   if (tck_rise_en = '1') then
          --     report "Shifting Data" severity error;
          --     dout_hold <= TDO & dout_hold(DATA_WIDTH-1 downto 1);
          --     dout_cnt <= dout_cnt + 1;
          --   else
          --     dout_hold <= dout_hold;
          --     dout_cnt <= dout_cnt;
          --   end if;
          --   -- Scans can be longer than DATA_WIDTH - so we need
          --   --   to detect when we are full and alert the user
          --   --   that the buffer needs to be read.
          --   if dout_cnt = dout_full then
          --     DOUT_VALID <= '1';
          --   else
          --     DOUT_VALID <= '0';
          --   end if;
          when S_UP_DR | S_UP_IR =>
            -- @NOTE - this only works for the end of scan state.
            --   it doesn't handle the case where
            --   we transfer out more than DATA_WIDTH number
            --   of bits.
            DOUT_VALID <= dout_has_data;
            dout_hold <= dout_hold;
            dout_cnt <= dout_cnt;
          when others =>
            DOUT_VALID <= DOUT_VALID;
            dout_hold <= dout_hold;
            dout_cnt <= dout_cnt;
            OVER_FLOW <= OVER_FLOW;
        end case;
      end if;
    end if;
  end process read_back;

  ------------------------
  -- TMS Control
  ------------------------


  tms_control : process(
    curr_state, FORCE_RESET, din_empty, din_last_bit, DR_IR, EOS_hold
    )
  begin
    case curr_state is
      when S_TLR =>
        -- Force transition to IDLE
        pre_TMS <= '0';
      when S_IDLE =>
        pre_TMS <= not din_empty;
      when S_SEL_DR =>
        pre_TMS <= DR_IR;
      when S_SEL_IR =>
        -- Force Transition to Capture IR
        pre_TMS <= '0';
      when S_CAP_DR | S_CAP_IR =>
        -- Force Transition to Shift State
        pre_TMS <= '0';
      when S_SH_DR | S_SH_IR =>
        -- We need to assert TMS on the last
        --   bit of the entire scan sequence.
        --   Note that we do this based on the din counter
        --   END_OF_SCAN doesn't matter here but it will
        --   matter in 'EX1' where decide whether to go to
        --   pause or update.
        pre_TMS <= din_last_bit;
      when S_EX1_DR | S_EX1_IR =>
        -- If this is the last word of the scan
        -- then we want to exit the sequence via UPDATE
        -- but if not - then it is an indication that we
        -- must head to the pause state and wait for more
        -- data.
        pre_TMS <= EOS_hold;
      when S_PAUSE_DR | S_PAUSE_IR =>
        pre_TMS <= not din_empty;
      when S_EX2_DR | S_EX2_IR =>
        pre_TMS <= din_empty;
      when S_UP_DR | S_UP_IR =>
        -- This means that the hold has written a new
        --   start of scan between EX1 and UPDATE - so we
        --   can go back to the start of the scan and skip
        --  the transition to idle.
        -- @NOTE - this assumes this next transaction is a
        --   multi-word transaction - which may not be a
        --   good assumption
        -- @TODO - we may need to be more careful here.
        pre_TMS <= (not din_empty) and (not EOS_hold);
      when others =>
        pre_TMS <= '1';
    end case;
  end process tms_control;

  tms_reg : process(CLK)
  begin
    if rising_edge(CLK) then
      if (RESET_n = '0') then
        TMS <= '0';
        TDI <= '1';
      elsif (TCK_FALL_EN = '1') then
        -- To force a reset we drive the TMS high
        --   for at least 5 TCK clock cycles.
        TMS <= FORCE_RESET or pre_TMS;
        TDI <= din_hold(0);
      else
        TMS <= TMS;
        TDI <= TDI;
      end if;
    end if;
  end process tms_reg;

  TCK <= JTAG_CLK;

end rtl;
