library ieee;
use ieee.std_logic_1164.all;

library work;
use work.JTAG.all;

package TestTools is

  procedure Cycle_Clock(
    signal CLK : out std_logic;
    signal END_CYCLE : in std_logic;
    clk_period : in time
    );

  procedure Write_Handshake(
    signal write_en : out std_logic;
    signal write_ack : in std_logic;
    clk_period : in time;
    max_cycles : in integer
    );

  procedure Wait_For_State(
    signal DUT_state : in JTAG_STATE_t;
    exp_state : in JTAG_STATE_t;
    clk_period : in time;
    max_cycles : in integer
    );

end package;

package body TestTools is

  procedure Cycle_Clock(
    signal CLK : out std_logic;
    signal END_CYCLE : in std_logic;
    clk_period : in time
    ) is
  begin
    if (END_CYCLE = '0') then
      CLK <= '0';
      wait for clk_period/2;
      CLK <= '1';
      wait for clk_period/2;
    else
      wait;
    end if;
  end Cycle_Clock;

  procedure Write_Handshake(
    signal write_en : out std_logic;
    signal write_ack : in std_logic;
    clk_period : in time;
    max_cycles : in integer
    ) is
    variable i : integer;
  begin
    i := 0;
    write_en <= '1';
    while write_ack = '0' loop
      wait for clk_period * 1;

      i := i+1;
      assert i < max_cycles report "Timeout Waiting for ACK in Write Handshake" severity failure;
    end loop;
    write_en <= '0';
  end Write_Handshake;

  procedure Wait_For_State(
    signal DUT_state : in JTAG_STATE_t;
    exp_state : in JTAG_STATE_t;
    clk_period : in time;
    max_cycles : in integer
    ) is
    variable i : integer;
  begin
    i := 0;
    while not ( DUT_state = exp_state ) loop
      wait for clk_period * 1;
      i := i + 1;
      assert i < max_cycles report "Timeout Waiting for JTAG State" severity failure;
    end loop;

  end Wait_For_State;



end TestTools;
