# TAP Controller

This project contains a VHDL-based JTAG TAP Master controller. This controller can be synthesized and implemented in an FPGA and generate the necessary signals to interrogate a Microcontroller or other FPGA via its JTAG signals.

The goal is to provide an AXI compatible interface that would allow easy integration with a host, for example in a Zynq-7000.

This project uses [OSVVM](https://github.com/OSVVM/OsvvmLibraries) as a verification framework.

## Setup

Install `ghdl >= 3.0.0`:

```
$> sudo snap install ghdl
```

Install dependencies for OSVVM:

```
$> sudo apt install tcl tcllib rlwrap
```

Setup submodules

```
$> git submodule update --init
```

## Run Test Benches

```
$> ./run_tests.tclsh
```

This should run to completion and generate several files in the root directory:

1.  `TAPController_RunTest.html` - This is the main browser viewable report.
	1.  There will also be an `*.xml` and `*.yml` variant.
2.  `reports` - More test suite specific HTMl reports.
3.  `results` - Simulation run logs.
4.  `logs` - Build logs
3.  `VHDL_LIBS` - directory where the GHDL compiled libraries are kept.


## Synthesis

@TODO - Xilinx Demo Project


@TODO - Xilinx Synthesis Report & Resource Utilization.
