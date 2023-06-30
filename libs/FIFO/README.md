# FIFO Verification Component

This component is modeled on the Xilinx FIFO module with fallthrough enabled. It is intended to provide a tool for testing VHDL-based designs.

## Using this Component

The Fifo Verification Component (FifoVC) is defined in `FifoVC.vhd`. This is the main component you, the dev, would use in a unit test. The file `FifoTbPkg.vhd` contains the definitions and VHDL `component` definition to make using this VC more palatable.


## Running the Tests

See the top level script `run_tests.tclsh` for more info about running the unit tests for this VC.
