-- JTAG Device Verification Component
--  This verification component simulates a device that
-- is receiving instructions and data from a JTAG master.
-- For example, a microcontroller device that has a JTAG
-- interface for programming.
--

library ieee;
  use ieee.std_logic_1164.all;

library OSVVM;
  context OSVVM.OsvvmContext;
  use osvvm.ScoreboardPkg_slv.NewID;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library TAP;
  use TAP.JTAG.all;

library tools;
  use tools.BitTools.to_slv;

library work;
  use work.JtagTbPkg.all;

entity JtagDevVC is
  generic (
    MODEL_ID_NAME : string;
    DEFAULT_IDCODE : integer := 16#00112233#;
    DEFAULT_STATE : JTAG_STATE_t := S_IDLE
  );
  port (
    TransRec : inout JtagDevRecType;

    CLK :  in std_logic;
    RESET_n : in std_logic;

    --------------------------
    -- JTAG Interface
    --------------------------
    TDI : in std_logic;
    TDO : buffer std_logic;
    TMS : in std_logic;
    TCK : in std_logic
    );
end JtagDevVC;

architecture model of JtagDevVC is

  signal modelID  : AlertLogIDType;

  -- Number of JTAG Transactions received.
  --   This value is updated on entry to the
  --   DR_UPDATE or IR_UPDATE states.
  signal rxCount : integer := 0;
  -- Number of times the boundar scan register
  --   has been set
  signal bsUpdateCount : integer := 0;

  signal curr_state : JTAG_STATE_t := DEFAULT_STATE;
  signal next_state : JTAG_STATE_t := DEFAULT_STATE;
  signal bypass_reg : std_logic := '0';

  -- Holding variable for the IDCODE when set by the
  -- user
  signal id_v : IdCodeReg := to_slv(DEFAULT_IDCODE, IDCodeReg'length);
  signal id_reg : IdCodeReg := (others => '0');
  -- Holding variable for input boundary scan when
  -- sent by the user through the model interface.
  signal bs_v : BoundaryScanReg := (others => '0');
  signal bs_reg : BoundaryScanReg := (others => '0');
  signal bs_out : BoundaryScanReg := (others => '0');

  -- Instruction register is only written through the
  --  JTAG interface.
  signal ir : InstructionReg := IDCODE;
begin

  ------------------------------------------------------------
  --  Initialize alerts
  ------------------------------------------------------------
  InitializeAlerts : process
    variable id : AlertLogIDType;
  begin
    id            := NewID(MODEL_ID_NAME);
    modelID       <= id;
    wait;
  end process InitializeAlerts;

  ------------------------------------------------------------
  --  Transaction Dispatcher
  --    Dispatches transactions to
  ------------------------------------------------------------
  TransactionDispatcher : process
    alias op : StreamOperationType is TransRec.Operation;
    variable waitCycles : integer;
    variable obsStim, expStim : JtagTb_Out_DataType;
    variable newBS : JtagTb_BS_Input_DataType;
  begin
    wait for 0 ns ; -- Let modelID get set
    -- Initialize defaults

    TransactionDispatcherLoop : loop
      WaitForTransaction(
         Clk      => CLK,
         Rdy      => TransRec.Rdy,
         Ack      => TransRec.Ack
      );

      case op is
        when GET | TRY_GET | CHECK | TRY_CHECK =>
          TransRec.BoolFromModel <= IsTry(op);
          if not IsTry(op) then
            obsStim := ir & bs_reg;
            TransRec.DataFromModel <= SafeResize(obsStim, obsStim'length);
            if IsCheck(op) then
              expStim := SafeResize(TransRec.DataToModel, expStim'length);
              if obsStim = expStim then
                AffirmPassed(modelID,
                  "Received: " & to_hxstring(obsStim) &
                  ".  Operation # " & to_string(rxCount),
                  TransRec.BoolToModel or IsLogEnabled(modelID, INFO));
              else
                AffirmError(modelID,
                  "Received: " & to_hxstring(obsStim) &
                  ".  Expected: " & to_hxstring(expStim) &
                  ".  Operation # " & to_string(rxCount));
              end if;
            else
              Log(modelID,
                "Received: " & to_hxstring(obsStim) &
                ".  Operation # " & to_string(rxCount),
                INFO, Enable => TransRec.BoolToModel
              );
            end if;
          end if;
        when SEND | SEND_ASYNC =>
          newBS := SafeResize(TransRec.DataToModel, newBS'length);
          Log(modelID,
            "SEND new BoundaryScan: " & to_hxstring(newBS) &
            "  Operation # " & to_string(bsUpdateCount + 1),
            INFO, Enable => TransRec.BoolToModel
          );
          bs_v <= newBS;
          Increment(bsUpdateCount);
          wait for 0 ns ;
          -- I don't think there is anything to block on
          --  the boundary scan register will get updated
          --  when the the device captures via the DR_CAP state.
        when WAIT_FOR_TRANSACTION =>
          -- Wait for another JTAG chain transaction
          -- to complete
          WaitForToggle(rxCount);

        when WAIT_FOR_CLOCK =>
          waitCycles := TransRec.IntToModel;
          -- Log(modelID,
          --   "WaitForClock:  WaitCycles = " & to_string(waitCycles),
          --   INFO
          -- ) ;
          -- This is going to wait for `TCK` cycles
          for i in 0 to waitCycles-1 loop
            wait until rising_edge(TCK);
          end loop;

        when GET_ALERTLOG_ID =>
          TransRec.IntFromModel <= modelID;

        when GET_TRANSACTION_COUNT =>
          TransRec.IntFromModel <= rxCount;

        when SET_MODEL_OPTIONS =>
          case TransRec.Options is
            when JtagOptionType'pos(SET_ID_CODE) =>
              -- Set the IDCode value for the DUT.
              id_v <= to_slv(TransRec.IntToModel, ID_WIDTH);
            when JtagOptionType'pos(SET_JTAG_STATE) =>
              -- Set the current state of the DUT.
              --   this is intended to allow for testing the
              --   force reset condition.
              Alert(modelID, "Set Jtag State Non Implemented Yet", FAILURE);
            when others =>
              Alert(modelID, "SetOptions, Unimplemented Option: " & to_string(JtagOptionType'val(TransRec.Options)), FAILURE);
          end case ;
        when GET_MODEL_OPTIONS =>
          case TransRec.Options is
            when JtagOptionType'pos(GET_JTAG_STATE) =>
              TransRec.IntFromModel <= JTAG_STATE_t'pos(curr_state);
            when others =>
              Alert(modelID, "GetOptions, Unimplemented Option: " &
                    to_string(JtagOptionType'val(TransRec.Options)),
                    FAILURE);
          end case;
        when MULTIPLE_DRIVER_DETECT =>
          Alert(modelID, "Multiple Drivers on Transaction Record." &
                "  Transaction # " & to_string(TransRec.Rdy),
                FAILURE);

        when others =>
          Alert(modelID, "Unimplemented Transaction: " &
                to_string(op), FAILURE);

      end case ;
    end loop TransactionDispatcherLoop;
  end process TransactionDispatcher;

  -- The TCK is what drives the state machine.
  --
  state_regs : process(TCK)
  begin
    if RESET_n = '1' then
      if rising_edge(TCK) then
        curr_state <= next_state;
      else
        curr_state <= curr_state;
      end if;
    else
      curr_state <= DEFAULT_STATE;
    end if;
  end process state_regs;

  jtag_transitions : process(curr_state, TMS)
  begin
    JTAG_state_transitions(curr_state, TMS, next_state);
  end process jtag_transitions;

  shift_regs : process(TCK)
  begin
    if rising_edge(TCK) then
      case curr_state is
        when S_SH_IR =>
          ir <= TDI & ir(IR_WIDTH-1 downto 1);
        when S_SH_DR =>
          case ir is
            when IDCODE =>
              id_reg <= TDI & id_reg(ID_WIDTH-1 downto 1);
            when EXTEST | SAMPLE =>
              bs_reg <= TDI & bs_reg(SCAN_WIDTH-1 downto 1);
            when BYPASS | HIGHZ =>
              bypass_reg <= TDI;
            when others =>
              bypass_reg <= TDI;
          end case;
        when others => null;
      end case;
    elsif falling_edge(TCK) then
      case curr_state is
        when S_CAP_DR =>
          case ir is
            when IDCODE =>
              id_reg <= id_v;
            when EXTEST | SAMPLE =>
              bs_reg <= bs_v;
            when others => null;
          end case;
        when S_SH_IR =>
          TDO <= IR(0);
        when S_SH_DR =>
          case ir is
            when IDCODE =>
              TDO <= id_reg(0);
            when EXTEST | SAMPLE =>
              TDO <= bs_reg(0);
            when BYPASS | HIGHZ =>
              TDO <= bypass_reg;
            when others =>
              TDO <= bypass_reg;
          end case;
        when S_UP_IR =>
          Increment(rxCount);
        when S_UP_DR =>
          Increment(rxCount);
          bs_out <= bs_reg;
        when others => null;
      end case;

    end if;
  end process shift_regs;

end model;
