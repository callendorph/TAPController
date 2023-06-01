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

  procedure Wait_On(
    signal enable : in std_logic;
    clk_period : in time;
    max_cycles : in integer
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

  procedure Read_Handshake(
    signal valid : in std_logic;
    signal ack : out std_logic;
    clk_period : in time
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

  procedure Wait_On(
    signal enable : in std_logic;
    clk_period : in time;
    max_cycles : in integer
    ) is
    variable i : integer;
  begin
    i := 0;
    while enable = '0' loop
      wait for clk_period * 1;

      i := i+1;
      assert i < max_cycles report "Timeout Waiting for Signal Assertion" severity failure;
    end loop;
  end Wait_On;

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
    Wait_On(write_ack, clk_period, max_cycles);
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

  procedure Read_Handshake(
    signal valid : in std_logic;
    signal ack : out std_logic;
    clk_period : in time
    ) is
  begin
    assert valid = '1' report "No Valid Data Available to Read";
    ack <= '1';
    wait for clk_period * 1;
    assert valid = '0' report "Read Handshake - Failed to Deassert";
    ack <= '0';
  end Read_Handshake;

end TestTools;
