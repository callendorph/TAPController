
TestSuite FifoVC_Tests
library TbFifoVC

# This causes the build to stop if any
#  errors are encountered during analysis
set ::osvvm::AnalyzeErrorStopCount 1

#SetDebugMode true
#SetLogSignals true
SetSaveWaves true

include TestHarness.pro
include testbench/testbench.pro
