
library ieee;
  use ieee.std_logic_1164.all;

library OSVVM;
  context OSVVM.OsvvmContext;
  use osvvm.ScoreboardPkg_slv.NewID;
  use osvvm.ScoreboardPkg_slv.Empty;
  use osvvm.ScoreboardPkg_slv.Push;
  use osvvm.ScoreboardPkg_slv.Pop;
  use osvvm.ScoreboardPkg_slv.Peek;
  use osvvm.ScoreboardPkg_slv.GetFifoCount;
  use osvvm.ScoreboardPkg_slv.GetItemCount;
  use osvvm.ScoreboardPkg_slv.GetPushCount;
  use osvvm.ScoreboardPkg_slv.GetPopCount;
  use osvvm.ScoreboardPkg_slv.Flush;

library osvvm_common;
  context osvvm_common.OsvvmCommonContext;

use work.FifoTbPkg.all;

-- This attempts to mimic the Xilinx FIFO
--  generator for testing. This is a limited model for
--  testing right now and isn't intended to be perfect.
--
-- Note: I'm not trying to mimic the overflow/underflow
--   etc signals because I will generate log messages
--   as needed for those.
--
-- This model is structured such that the user can either
--  connect to the signal inputs/outputs of the FIFO, or
--  push and pop values into the model via transactions.

entity FifoVC is
  generic (
    MODEL_ID_NAME : string := "";
    -- Number of words that can fit in the
    --  fifo.
    DEPTH : integer := 8;
    -- Width of the fifo in bits.
    WIDTH : integer := 36
    );
  port (
    TransRec : inout FifoRecType ;

    -- Common clock for read and write -
    --   Synchronous to our other logic.
    CLK : in std_logic;
    RESET_n : in std_logic;

    -- Read Interface
    --  This uses a First Word Fall Through (FWFT) style
    --  interface
    DOUT : out std_logic_vector(WIDTH-1 downto 0);
    VALID : out std_logic;
    RD_EN : in std_logic;

    -- Write Interface
    DIN : in std_logic_vector(WIDTH-1 downto 0);
    WR_EN : in std_logic;
    WR_ACK : out std_logic
    );
end FifoVC;


architecture model of FifoVC is

  signal ModelID  : AlertLogIDType;
  -- This is the main data structure that contains
  --  the elements of the fifo.
  signal fifo : osvvm.ScoreboardPkg_slv.ScoreboardIDType;

  -- I'm using these signals as flags that indicate when
  --   a transmit or receive operation has been complete.
  --   These help to signal when a blocking read/write can
  --   proceed.
  signal rxSigFlag : std_logic := '0';
  signal rxVirtFlag : std_logic := '0';

  signal txSigFlag : std_logic := '0';
  signal txVirtFlag : std_logic := '0';

  -- The hardware FIFO is of fixed length. This method is a
  --  helper to determine if the fifo is full.
  impure function IsFull(
    constant ID : in osvvm.ScoreboardPkg_slv.ScoreboardIDType
    ) return boolean is
    begin
      return GetFifoCount(ID) >= DEPTH;
    end ;

  subtype fifo_elem is std_logic_vector(WIDTH-1 downto 0);


begin

  ------------------------------------------------------------
  --  Initialize alerts
  ------------------------------------------------------------
  init_alerts : process
    variable ID : AlertLogIDType;
  begin
    ID            := NewID(MODEL_ID_NAME);
    ModelID       <= ID;
    fifo        <= NewID(
      "FIFO_UUT", ID, ReportMode => DISABLED, Search => PRIVATE_NAME
      );
    wait;
  end process init_alerts;


  TransactionDispatcher : process
    alias Operation : StreamOperationType is TransRec.Operation ;
    variable WaitCycles : integer ;
    variable RxStim, ExpectedStim : fifo_elem ;
    variable TxStim : fifo_elem ;
  begin
    wait for 0 ns ; -- Let ModelID get set
    -- Initialize defaults

    TransactionDispatcherLoop : loop
      WaitForTransaction(
         Clk      => CLK,
         Rdy      => TransRec.Rdy,
         Ack      => TransRec.Ack
      );

--**      Operation := TransRec.Operation ;

      case Operation is
        when GET | TRY_GET | CHECK | TRY_CHECK =>
          if Empty(fifo) and IsTry(Operation) then
            -- Return if no data
            TransRec.BoolFromModel <= FALSE ;
          else
            -- Get data
            TransRec.BoolFromModel <= TRUE ;
            if Empty(fifo) then
              -- Wait for data
              wait until txVirtFlag'event or txSigFlag'event;
            else
              -- Settling for when not Empty at current time
              wait for 0 ns ;
            end if ;
            -- Put Data and Parameters into record
            RxStim := Pop(fifo) ;
            TransRec.DataFromModel <= SafeResize(RxStim,  TransRec.DataFromModel'length) ;
            Toggle(rxVirtFlag);
            if IsCheck(Operation) then
              ExpectedStim := SafeResize(TransRec.DataToModel, ExpectedStim'length);
              if RxStim = ExpectedStim then -- Match
                AffirmPassed(ModelID,
                  "Received: " & to_string(RxStim) &
                  ".  Operation # " & to_string(GetPopCount(fifo)),
                  TransRec.BoolToModel or IsLogEnabled(ModelID, INFO) ) ;
              else
                AffirmError(ModelID,
                  "Received: " & to_string(RxStim) &
                  ".  Expected: " & to_string(ExpectedStim) &
                  ".  Operation # " & to_string(GetPopCount(fifo)) ) ;
              end if ;
            else
              Log(ModelID,
                "Received: " & to_string(RxStim) &
                ".  Operation # " & to_string(GetPopCount(fifo)),
                INFO, Enable => TransRec.BoolToModel
              ) ;
            end if ;
          end if ;
        when SEND =>
          -- Enqueue data into the TxFifo
          TxStim := SafeResize(TransRec.DataToModel, TxStim'length);
          if IsFull(fifo) then
            -- I'm interpretting this as a blocking write to
            -- the queue - so if the queue is FULL I'm going to
            -- wait until there is space
            -- Note that I can't use `IsFull` in the wait here
            --   so I'm using these flags to indicate a change
            --   in the receive state
            wait until rxVirtFlag'event or rxSigFlag'event;
          end if;
          Push(fifo, TxStim);
          Toggle(txVirtFlag);
          Log(ModelID,
              "SEND Queueing Transaction: " & to_string(TxStim) &
              "  TxOp # " & to_string(GetPushCount(fifo)),
              INFO, Enable => TransRec.BoolToModel
              );
          wait for 0 ns ;
        when SEND_ASYNC =>
          TxStim := SafeResize(TransRec.DataToModel, TxStim'length);
          if IsFull(fifo) then
            AffirmError(
              ModelID,
              "Transmit: " & to_string(TxStim) &
              ".  Overflow! "  &
              "  Operation # " & to_string(GetPushCount(fifo) + 1)
              );
          end if;
          Push(fifo, TxStim);
          Toggle(txVirtFlag);
          Log(ModelID,
              "SEND_ASYNC Queueing Transaction: " & to_string(TxStim) &
              "  TxOp # " & to_string(GetPushCount(fifo)),
              INFO, Enable => TransRec.BoolToModel
              );

          wait for 0 ns ;

        when WAIT_FOR_TRANSACTION =>
          -- Transactions are complete on read.
          if Empty(fifo) then
            wait until not Empty(fifo);
          end if ;

        when WAIT_FOR_CLOCK =>
          WaitCycles := TransRec.IntToModel ;
          -- Log(ModelID,
          --   "WaitForClock:  WaitCycles = " & to_string(WaitCycles),
          --   INFO
          -- ) ;
          for i in 0 to WaitCycles loop
            wait until rising_edge(CLK);
          end loop;

        when GET_ALERTLOG_ID =>
          TransRec.IntFromModel <= ModelID ;

        when GET_TRANSACTION_COUNT =>
          -- I'm counting a completed transaction as a value that
          --  has been pushed into the fifo and then read out of
          --  of the fifo
          TransRec.IntFromModel <= GetPopCount(fifo);

        -- Currently there are no model
        --   options that can be set.
        -- when SET_MODEL_OPTIONS =>
        when GET_MODEL_OPTIONS =>
          case TransRec.Options is
            when FifoOptionType'pos(GET_FIFO_COUNT) =>
              TransRec.IntFromModel <= GetFifoCount(fifo);
            when FifoOptionType'pos(GET_TX_COUNT) =>
              TransRec.IntFromModel <= GetPushCount(fifo);
            when FifoOptionType'pos(GET_RX_COUNT) =>
              TransRec.IntFromModel <= GetPopCount(fifo);
            when FifoOptionType'pos(GET_WIDTH) =>
              TransRec.IntFromModel <= WIDTH;
            when FifoOptionType'pos(GET_DEPTH) =>
              TransRec.IntFromModel <= DEPTH;
            when others =>
              Alert(ModelID, "GetOptions, Unimplemented Option: " &
                    to_string(FifoOptionType'val(TransRec.Options)),
                    FAILURE) ;
          end case;
        when MULTIPLE_DRIVER_DETECT =>
          Alert(ModelID, "Multiple Drivers on Transaction Record." &
                         "  Transaction # " & to_string(TransRec.Rdy), WARNING);

        when others =>
          Alert(ModelID, "Unimplemented Transaction: " & to_string(Operation), FAILURE);

      end case ;
    end loop TransactionDispatcherLoop ;
  end process TransactionDispatcher ;


  FifoWrite : process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET_n = '1' then
        if WR_EN = '1' then
          if IsFull(fifo) then
            WR_ACK <= '0';
            -- This is an indication of an overflow
            -- This isn't really an error.
            -- @TODO overflow flag.
            Log(ModelID, "Write Overflow", INFO);
          else
            WR_ACK <= '1';
            Push(fifo, DIN);
            Toggle(txSigFlag);
          end if;
        else
          WR_ACK <= '0';
        end if;
      else
        WR_ACK <= '0';
      end if;
    end if;
  end process FifoWrite;

  FifoRead : process(CLK)
    variable readOut, popOut : fifo_elem;
  begin
    if rising_edge(CLK) then
      if RESET_n = '1' then
        if RD_EN = '1' then
          if not Empty(fifo) then
            popOut := Pop(fifo);
            Toggle(rxSigFlag);
          else
            -- Underflow condition
            Alert(ModelID, "Read Underflow", FAILURE);
          end if;
        end if;

        if Empty(fifo) then
          VALID <= '0';
          readOut := (others => 'X');
        else
          VALID <= '1';
          readOut := Peek(fifo);
        end if;

        DOUT <= readOut;
      else
        VALID <= '0';
        DOUT <= (others => '0');
        -- Reset the FIFO to clear it out.
        Flush(fifo, GetItemCount(fifo));
      end if;
    end if;
  end process FifoRead;

end model;
