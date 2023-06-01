library ieee;
use ieee.std_logic_1164.all;

package JTAG is

  type JTAG_STATE_t is (
    S_TLR,
    S_IDLE,
    S_SEL_DR,
    S_SEL_IR,
    S_CAP_DR,
    S_SH_DR,
    S_EX1_DR,
    S_PAUSE_DR,
    S_EX2_DR,
    S_UP_DR,
    S_CAP_IR,
    S_SH_IR,
    S_EX1_IR,
    S_PAUSE_IR,
    S_EX2_IR,
    S_UP_IR
  );

  type JTAG_STATE_ARRAY_t is array(natural range<>) of JTAG_STATE_t;

  procedure JTAG_state_transitions(
    signal curr_state : in JTAG_STATE_t;
    signal TMS : in std_logic;
    signal next_state : out JTAG_STATE_t
  );

end package;

package body JTAG is

  procedure JTAG_state_transitions(
    signal curr_state : in JTAG_STATE_t;
    signal TMS : in std_logic;
    signal next_state : out JTAG_STATE_t
    ) is
  begin

      case curr_state is
        when S_TLR =>
          if TMS = '1' then
            next_state <= S_TLR;
          else
            next_state <= S_IDLE;
          end if;
        when S_IDLE =>
          if TMS = '1' then
            next_state <= S_SEL_DR;
          else
            next_state <= S_IDLE;
          end if;
        when S_SEL_DR =>
          if TMS = '1' then
            next_state <= S_SEL_IR;
          else
            next_state <= S_CAP_DR;
          end if;
        when S_SEL_IR =>
          if TMS = '1' then
            next_state <= S_TLR;
          else
            next_state <= S_CAP_IR;
          end if;

        -- Data Sequence
        when S_CAP_DR =>
          if TMS = '1' then
            next_state <= S_EX1_DR;
          else
            next_state <= S_SH_DR;
          end if;
        when S_SH_DR =>
          if TMS = '1' then
            next_state <= S_EX1_DR;
          else
            next_state <= S_SH_DR;
          end if;
        when S_EX1_DR =>
          if TMS = '1' then
            next_state <= S_UP_DR;
          else
            next_state <= S_PAUSE_DR;
          end if;
        when S_PAUSE_DR =>
          if TMS = '1' then
            next_state <= S_EX2_DR;
          else
            next_state <= S_PAUSE_DR;
          end if;
        when S_EX2_DR =>
          if TMS = '1' then
            next_state <= S_UP_DR;
          else
            next_state <= S_SH_DR;
          end if;
        when S_UP_DR =>
          if TMS = '1' then
            next_state <= S_SEL_DR;
          else
            next_state <= S_IDLE;
          end if;

        -- Instruction Sequence
        when S_CAP_IR =>
          if TMS = '1' then
            next_state <= S_EX1_IR;
          else
            next_state <= S_SH_IR;
          end if;
        when S_SH_IR =>
          if TMS = '1' then
            next_state <= S_EX1_IR;
          else
            next_state <= S_SH_IR;
          end if;
        when S_EX1_IR =>
          if TMS = '1' then
            next_state <= S_UP_IR;
          else
            next_state <= S_PAUSE_IR;
          end if;
        when S_PAUSE_IR =>
          if TMS = '1' then
            next_state <= S_EX2_IR;
          else
            next_state <= S_PAUSE_IR;
          end if;
        when S_EX2_IR =>
          if TMS = '1' then
            next_state <= S_UP_IR;
          else
            next_state <= S_SH_IR;
          end if;
        when S_UP_IR =>
          if TMS = '1' then
            next_state <= S_SEL_IR;
          else
            next_state <= S_IDLE;
          end if;
        when others =>
          next_state <= S_IDLE;
      end case;
  end JTAG_state_transitions;


end JTAG;
