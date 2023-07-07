
TestSuite TapController_Tests
library TbTAPController

# This causes the build to stop if any
#  errors are encountered during analysis
set ::osvvm::AnalyzeErrorStopCount 1

#SetDebugMode true
#SetLogSignals true
SetSaveWaves true

SetExtendedRunOptions --ieee-asserts=disable-at-0

include ../../libs/JTAG/TestHarness.pro
include TestHarness.pro
include testbench/testbench.pro
