# TAP Controller

This project contains a VHDL-based JTAG TAP Master controller. This controller can be synthesized and implemented in an FPGA and generate the necessary signals to interrogate a Microcontroller or other FPGA via its JTAG signals.

The goal is to provide an AXI compatible interface that would allow easy integration with a host, for example in a Zynq-7000.

## Setup

Install `ghdl`:

```
$> sudo apt install ghdl gtkwave
```

## Run Test Benches

```
$> make
```

Alternatively - you can run individual tests:

```
$> make TAP_Basic
```

## Synthesis

@TODO - Xilinx Demo Project
@TODO - Xilinx Synthesis Report & Resource Utilization.
