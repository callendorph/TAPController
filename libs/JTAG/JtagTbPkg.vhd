library ieee;
use ieee.std_logic_1164.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library TAP;
  use TAP.JTAG.all;

package JtagTbPkg is

  constant BYPASS_WIDTH : integer := 1;
  constant SCAN_WIDTH : integer := 64;
  subtype BoundaryScanReg is std_logic_vector(SCAN_WIDTH-1 downto 0);
  constant ID_WIDTH : integer := 32;
  subtype IdCodeReg is std_logic_vector(ID_WIDTH-1 downto 0);
  constant IR_WIDTH : integer := 4;
  subtype InstructionReg is std_logic_vector(IR_WIDTH-1 downto 0);

  -- Example IR registers
  --  See:
  --   NXP App Node AN2074
  --   https://www.nxp.com/docs/en/application-note/AN2074.pdf
  constant IDCODE : InstructionReg := "0010";
  constant EXTEST : InstructionReg := "0000";
  constant SAMPLE : InstructionReg := "0001";
  constant HIGHZ : InstructionReg  := "0100";
  constant BYPASS : InstructionReg := "1111";

  -- JTAG Data Out:
  --   IR State Write
  --   Output Boundary Scan Register Write
  --
  -- JTAG Params Out:
  --   None
  --
  -- JTAG Data In:
  --   Input Boundary Scan Values
  --
  -- JTAG Params Out
  --   None
  --
  -- Options:
  --  Get Current JTAG State of DUT.
  --  Set the IDCode value.
  --

  -- The Data Output consists of the
  --  Instruction register and the Boundary Scan Register
  --  concatentated together.
  --  IR is in the top 4 bits
  --  BS is in the bottom 64 bits.
  subtype JtagTb_Out_DataType is std_logic_vector((IR_WIDTH+SCAN_WIDTH)-1 downto 0);

  procedure ExtractRegs(
    variable obs : in JtagTb_Out_DataType;
    variable obs_IR : out InstructionReg;
    variable obs_BS : out BoundaryScanReg
  );



  -- Data into the model that shows the state of the
  --   boundary scan inputs.
  subtype JtagTb_BS_Input_DataType is std_logic_vector(SCAN_WIDTH-1 downto 0);

  subtype JtagDevRecType is StreamRecType (
    DataToModel (JtagTb_BS_Input_DataType'range),
    DataFromModel (JtagTb_Out_DataType'range),
    -- These aren't used but I must declare them with a range
    --   in order for this type to be concrete.
    ParamToModel(7 downto 0),
    ParamFromModel(7 downto 0)
  );

  type JtagOptionType is (SET_ID_CODE, SET_JTAG_STATE, GET_JTAG_STATE);

  -- These methods are primarily for use by the Test Controller
  --   to drive the simulation.
  procedure SetIdCode(
    signal TransRec : inout JtagDevRecType;
    constant value : integer
    );

  procedure SetJTAGState(
    signal TransRec : inout JtagDevRecType;
    constant value : JTAG_STATE_t
  );

  procedure GetJTAGState(
    signal TransRec : inout JtagDevRecType;
    variable value : out JTAG_STATE_t
  );

  -- This function is for checking the incoming
  --   new JTAG state argument to make sure it
  --   is valid.
  impure function CheckJTAGState (
    constant AlertLogID : in AlertLogIDType ;
    constant JtagState : in JTAG_STATE_t;
    constant StatusMsgOn : in boolean := FALSE
  ) return JTAG_STATE_t;


  component JtagDevVC is
    generic (
      MODEL_ID_NAME : string;
      DEFAULT_IDCODE : integer := 16#00112233#;
      DEFAULT_STATE : JTAG_STATE_t := S_IDLE
      );
    port (
      TransRec : inout JtagDevRecType ;
      CLK : in std_logic;
      RESET_n : in std_logic;
      --------------------------
      -- JTAG Interface
      --------------------------
      TDI : in std_logic;
      TDO : buffer std_logic;
      TMS : in std_logic;
      TCK : in std_logic
      );
  end component JtagDevVC;

  ----------------------
  -- Tools for Testing the JtagDevVC
  --   These functions drive the JTAG signal interface
  --   and create transactions similar to the way a
  --   JTAG master would.

  -- Update the instruction register of the
  --   device by driving the JTAG state machine
  --   with the signals.
  procedure UpdateInstruction(
    signal TMS : out std_logic;
    signal TDI : out std_logic;
    signal TCK : in std_logic;
    constant NewIR : in InstructionReg
    );

  -- Transaction that both writes and
  --  reads the data register from the JTAG
  --  device.
  procedure UpdateDataSequence(
    signal TMS : out std_logic;
    signal TDI : out std_logic;
    signal TCK : in std_logic;
    signal TDO : in std_logic;
    variable InReg : in std_logic_vector;
    variable OutReg : out std_logic_vector;
    constant NumBits : in integer
    );


end JtagTbPkg;

package body JtagTbPkg is

  procedure ExtractRegs(
    variable obs : in JtagTb_Out_DataType;
    variable obs_IR : out InstructionReg;
    variable obs_BS : out BoundaryScanReg
  ) is
    begin
      obs_BS := obs(SCAN_WIDTH-1 downto 0);
      obs_IR := obs(obs'length-1 downto SCAN_WIDTH);
    end procedure ExtractRegs;


  procedure SetIdCode(
    signal TransRec : inout JtagDevRecType;
    constant value : integer
    ) is
  begin
    SetModelOptions(TransRec, JtagOptionType'pos(SET_ID_CODE), value);
  end procedure SetIdCode;

  procedure SetJTAGState(
    signal TransRec : inout JtagDevRecType;
    constant value : JTAG_STATE_t
  ) is
    variable state : integer;
  begin
    state := JTAG_STATE_t'pos(value);
    SetModelOptions(TransRec, JtagOptionType'pos(SET_JTAG_STATE), state);
  end procedure SetJTAGState;

  procedure GetJTAGState(
    signal TransRec : inout JtagDevRecType;
    variable value : out JTAG_STATE_t
  ) is
    variable state : integer;
  begin
    GetModelOptions(TransRec, JtagOptionType'pos(GET_JTAG_STATE), state);
    value := JTAG_STATE_t'val(state);
  end procedure GetJTAGState;

  impure function CheckJTAGState (
    constant AlertLogID : in AlertLogIDType ;
    constant JtagState : in JTAG_STATE_t;
    constant StatusMsgOn : in boolean := FALSE
  ) return JTAG_STATE_t is
    variable ret : JTAG_STATE_t;
  begin
    ret := JtagState;
    case JtagState is
      when S_TLR | S_IDLE | S_SEL_DR |
        S_SEL_IR | S_CAP_DR | S_SH_DR |
        S_EX1_DR | S_PAUSE_DR | S_EX2_DR |
        S_UP_DR | S_CAP_IR | S_SH_IR | S_EX1_IR |
        S_PAUSE_IR | S_EX2_IR | S_UP_IR =>
        log(AlertLogID, "JTAG Stat Set To" & JTAG_STATE_t'image(ret), INFO, StatusMsgOn);
      when others =>
        Alert(AlertLogID, "Unsupported JTAG State - Using Idle", ERROR);
        ret := S_IDLE;
    end case;
    return ret;
  end function CheckJTAGState;


  procedure UpdateInstruction(
    signal TMS : out std_logic;
    signal TDI : out std_logic;
    signal TCK : in std_logic;
    constant NewIR : in InstructionReg
  ) is
  begin

    wait until TCK = '0';
    TMS <= '1';
    wait until rising_edge(TCK); -- Select DR
    wait until falling_edge(TCK);
    TMS <= '1';
    wait until rising_edge(TCK); -- Select IR
    wait until falling_edge(TCK);
    TMS <= '0';
    wait until rising_edge(TCK); -- Capture IR
    wait until falling_edge(TCK);
    TMS <= '0';
    wait until rising_edge(TCK); -- Shift IR state

    for i in 0 to NewIR'length-1 loop
      wait until falling_edge(TCK);
      TDI <= NewIR(i);
      if i = NewIR'length-1 then
        TMS <= '1'; -- Exit to Exit1 IR state.
      else
        TMS <= '0'; -- stay in Shift IR state
      end if;
      wait until rising_edge(TCK);
    end loop;

    wait until falling_edge(TCK);
    TMS <= '1';
    wait until rising_edge(TCK); -- Update IR
    wait until falling_edge(TCK);
    TMS <= '0';
    wait until rising_edge(TCK); -- Idle State

  end procedure UpdateInstruction;

  procedure UpdateDataSequence(
    signal TMS : out std_logic;
    signal TDI : out std_logic;
    signal TCK : in std_logic;
    signal TDO : in std_logic;
    variable InReg : in std_logic_vector;
    variable OutReg : out std_logic_vector;
    constant NumBits : in integer
    )

  is
    variable reg : std_logic_vector(NumBits-1 downto 0) := (others => '0');
  begin

    wait until TCK = '0';
    TMS <= '1';
    wait until rising_edge(TCK); -- Select DR
    wait until falling_edge(TCK);
    TMS <= '0';
    wait until rising_edge(TCK); -- Capture-DR
    wait until falling_edge(TCK);
    TMS <= '0';
    wait until rising_edge(TCK); -- Shift-DR

    for i in 0 to NumBits-1 loop
      wait until falling_edge(TCK);
      TDI <= InReg(i);
      if i = NumBits-1 then
        TMS <= '1'; -- Exit to Exit1 IR state.
      else
        TMS <= '0'; -- stay in Shift IR state
      end if;
      wait until rising_edge(TCK); -- Shift IR state
      reg := TDO & reg(NumBits-1 downto 1);
    end loop;

    wait until falling_edge(TCK);
    TMS <= '1';
    wait until rising_edge(TCK); -- Update DR
    wait until falling_edge(TCK);
    TMS <= '0';
    wait until rising_edge(TCK); -- Idle State

    OutReg := reg;

  end procedure UpdateDataSequence;



end JtagTbPkg;
