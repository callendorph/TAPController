library ieee;
use ieee.std_logic_1164.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library TAP;
  use TAP.JTAG.all;
  use TAP.TAPPkg.all;

library TbJtagVC;
  use TbJtagVC.JtagTbPkg.all;

package TapCtlTbPkg is

  procedure TapTestSetup(name : string);

  procedure Write_Handshake(
    signal write_en : out std_logic;
    signal write_ack : in std_logic;
    signal clk : in std_logic
    );

  procedure Wait_For_State_With_Avoids(
    constant logID : in AlertLogIDType ;
    signal DevRec : inout JtagDevRecType;
    exp_state : in JTAG_STATE_t;
    avoid_states : in JTAG_STATE_ARRAY_t;
    max_cycles : in integer
    );

  procedure Wait_For_State(
    constant logID : in AlertLogIDType ;
    signal DevRec : inout JtagDevRecType;
    exp_state : in JTAG_STATE_t;
    max_cycles : in integer
    );

  procedure Read_Handshake(
    signal valid : in std_logic;
    signal ack : out std_logic;
    signal clk : in std_logic
    );


end TapCtlTbPkg;

package body TapCtlTbPkg is

  procedure TapTestSetup(
    name : string
    ) is
  begin

    SetTestName(name);
    SetLogEnable(PASSED, TRUE);

    wait for 0 ns;
    -- These options are used to format the log output.
    --   they don't affect the simulation in any way.
    SetAlertLogOptions(WriteTimeLast => FALSE);
    SetAlertLogOptions(TimeJustifyAmount => 16);
    SetAlertLogJustify;

    TranscriptOpen(name & ".txt");
    -- Write to both the console and file.
    SetTranscriptMirror(TRUE);

  end procedure TapTestSetup;


  procedure Write_Handshake(
    signal write_en : out std_logic;
    signal write_ack : in std_logic;
    signal clk : in std_logic
  ) is
  begin
    wait until falling_edge(clk);
    write_en <= '1';
    wait until write_ack = '1';
    wait until falling_edge(clk);
    write_en <= '0';
  end Write_Handshake;

  procedure Wait_For_State_With_Avoids(
    constant logID : in AlertLogIDType ;
    signal DevRec : inout JtagDevRecType;
    exp_state : in JTAG_STATE_t;
    avoid_states : in JTAG_STATE_ARRAY_t;
    max_cycles : in integer
  ) is
    variable i : integer := 0;
    variable currState : JTAG_STATE_t;
  begin

    check_state : while TRUE loop

      GetJTAGState(DevRec, currState);
      if currState = exp_state then
        AffirmPassed(
          logID,
          "Reached JTAG STATE: " & JTAG_STATE_t'image(exp_state)
          );
        exit;
      end if;

      WaitForClock(DevRec, 1);
      i := i + 1;
      if i > max_cycles then
        AffirmError(
          logID,
          "Timeout Waiting of JTAG STATE: " & JTAG_STATE_t'image(exp_state)
          );
        exit;
      end if;

      -- Check if we have entered an invalid state.
      if avoid_states'LENGTH = 0 then
        next check_state;
      end if;

      for j in 0 to avoid_states'LENGTH-1 loop
        if currState = avoid_states(j) then
          AffirmError(
            logID,
            "JTAG FSM Entered Invalid State: " & JTAG_STATE_t'image(currState)
          );
        end if;
      end loop;
    end loop;

  end Wait_For_State_With_Avoids;


  procedure Wait_For_State(
    constant logID : in AlertLogIDType ;
    signal DevRec : inout JtagDevRecType;
    exp_state : in JTAG_STATE_t;
    max_cycles : in integer
    ) is
    -- @NOTE - the syntax here is a little strange - but
    --   the idea is that '0 downto 1' is an invalid range
    --   so this will produce an empty array. We then just initialize
    --   with the 'others' and a random value. That random value
    --   does not get used.
    constant empty_set : JTAG_STATE_ARRAY_t(0 downto 1) := (others => S_TLR);

  begin
    Wait_For_State_With_Avoids(logID, DevRec, exp_state, empty_set, max_cycles);
  end Wait_For_State;


  procedure Read_Handshake(
    signal valid : in std_logic;
    signal ack : out std_logic;
    signal clk : in std_logic
    ) is
  begin
    assert valid = '1' report "No Valid Data Available to Read";
    wait until falling_edge(clk);
    ack <= '1';
    wait until falling_edge(valid);
    wait until falling_edge(clk);
    ack <= '0';
  end Read_Handshake;


end TapCtlTbPkg;
