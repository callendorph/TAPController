
include ../../libs/tools/tools.pro
include ../../src/TAP.pro
include ../../libs/JTAG/TestHarness.pro


library TbTAPController

analyze TapCtlTbPkg.vhd
analyze TestCtrl.vhd
analyze TestHarness.vhd
