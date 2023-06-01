-- This file contains the implementation of a Device Under Test
--  JTAG interface. The idea is that this module is used in
--  simulation and receives the signals from the TAPController.
--  We use this as a means of determining if the TAPController
--  has sent the correct signal sequence and to inject values
--  to be read by the TAPController.
--
-- @NOTE - This entity is NOT intended to be synthesized.

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.BitTools.all;
use work.JTAG.all;


entity JTAG_DUT is
  generic (
    ID_WIDTH : in integer := 32;
    BYPASS_WIDTH : in integer := 1;
    SCAN_WIDTH : in integer := 64
    );
  port (
    --------------------------
    -- Sync Interface
    --------------------------

    CLK : in std_logic;
    RESET_n : in std_logic;

    --------------------------
    -- JTAG Interface
    --------------------------
    TDI : in std_logic;
    TDO : buffer std_logic;
    TMS : in std_logic;
    TCK : in std_logic;

    --------------------------
    -- User Interface
    --------------------------

    -- Instruction Register State
    IR : buffer std_logic_vector(3 downto 0);
    -- User provides this Boundary Scan input and it
    --  is sampled in the CAPTURE_DR state
    BS : in std_logic_vector(SCAN_WIDTH-1 downto 0);
    -- Holds the current state of the Boundary Scan register
    --  This holds the sample of BS and then gets clocked out
    --  on TDO as the user reads it.
    BSR : buffer std_logic_vector(SCAN_WIDTH-1 downto 0);
    -- Identifier for the chip that is read when
    --  the IDCODE instruction is written to the IR.
    ID : in std_logic_vector(ID_WIDTH-1 downto 0);

    -- Current JTAG state of the device
    --   this is primarily useful for debugging.
    curr_state : buffer JTAG_STATE_t

  );

end JTAG_DUT;


architecture behavioral of JTAG_DUT is
  constant IR_WIDTH : integer := IR'length;
  -- Example IR registers
  --  See:
  --   NXP App Node AN2074
  --   https://www.nxp.com/docs/en/application-note/AN2074.pdf
  constant IDCODE : std_logic_vector(IR_WIDTH-1 downto 0) := "0010";
  constant EXTEST : std_logic_vector(IR_WIDTH-1 downto 0) := "0000";
  constant SAMPLE : std_logic_vector(IR_WIDTH-1 downto 0) := "0001";
  constant HIGHZ : std_logic_vector(IR_WIDTH-1 downto 0) := "0100";
  constant BYPASS : std_logic_vector(IR_WIDTH-1 downto 0) := "1111";


  signal next_state : JTAG_STATE_t;

-- TCK Rise/Fall signals
  signal tck_rise_en, tck_fall_en : std_logic;
  signal tck_d1 : std_logic;

  signal bypass_reg : std_logic;
  signal id_reg : std_logic_vector(ID_WIDTH-1 downto 0);

begin

  -- TCK Rise and Fall Detectors
  tck_edges : process(CLK)
  begin
    if rising_edge(CLK) then
      -- Don't check RESET here because it will only cause
      --   aberrant pulses. We always want to reset to whatever
      --   the last state of TCK was.
      tck_d1 <= TCK;
    else
      tck_d1 <= tck_d1;
    end if;
  end process tck_edges;

  tck_rise_en <= (not tck_d1) and TCK;
  tck_fall_en <= tck_d1 and (not TCK);

  state_regs : process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET_n = '0' then
        curr_state <= S_TLR;
      else
        if tck_rise_en = '1' then
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

  -- Control the shift register used by
  --   the DUT depending on the state of the
  --   instruction register.

  shift_reg : process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET_n = '0' then
        IR <= IDCODE;
        BSR <= (others => '0');
        bypass_reg <= '0';
        TDO <= '0';
      else
        case curr_state is
          when S_CAP_DR =>
            case IR is
              when IDCODE =>
                if tck_fall_en = '1' then
                  id_reg <= ID;
                end if;
              when EXTEST | SAMPLE =>
                if tck_fall_en = '1' then
                  BSR <= BS;
                end if;
              when others => null;
            end case;
          when S_SH_IR =>
            if tck_rise_en = '1' then
              IR <= TDI & IR(IR_WIDTH-1 downto 1);
            elsif tck_fall_en = '1' then
              TDO <= IR(0);
            end if;
          when S_SH_DR =>
            case IR is
              when IDCODE =>
                if tck_rise_en = '1' then
                  id_reg <= TDI & id_reg(ID_WIDTH-1 downto 1);
                elsif tck_fall_en = '1' then
                  TDO <= id_reg(0);
                end if;
              when EXTEST | SAMPLE =>
                if tck_rise_en = '1' then
                  BSR <= TDI & BSR(SCAN_WIDTH-1 downto 1);
                elsif tck_fall_en = '1' then
                  TDO <= BSR(0);
                end if;
              when BYPASS | HIGHZ =>
                if tck_rise_en = '1' then
                  bypass_reg <= TDI;
                elsif tck_fall_en = '1' then
                  TDO <= bypass_reg;
                end if;
              when others =>
                if tck_rise_en = '1' then
                  bypass_reg <= TDI;
                elsif tck_fall_en = '1' then
                  TDO <= bypass_reg;
                end if;
            end case;
          when S_UP_DR =>
            case IR is
              when EXTEST | SAMPLE =>
                if tck_fall_en = '1' then
                  report "BSR Update: " & to_string(BSR);
                end if;
              when others => null;
            end case;
          when others => null;

        end case;
      end if;
    end if;
  end process shift_reg;


end behavioral;
