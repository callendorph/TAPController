# JTAG Verification Component

This directory contains modules for verifying the performance of the JTAG controllers. The content in this directory is not intended to be synthesized. It is intended to provide simulation facilities for testing the code that will be synthesized.

## Using this Component

The JTAG Verification Component (JtagVC) is defined in `JtagVC.vhd`. This is the main component you, the dev, would use in a unit test. The file `JtagTbPkg.vhd` contains the definitions and VHDL `component` definition to make using this VC more palatable.


## Running the Tests

See the top level script `run_tests.tclsh` for more info about running the unit tests for this VC.
