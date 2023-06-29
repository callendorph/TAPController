
TestSuite FifoVC_Tests
library TbFifoVC

include TestHarness.pro

#SetDebugMode true
#SetLogSignals true
SetSaveWaves true

RunTest Fifo_BasicTest.vhd
