
include ../tools/tools.pro
include ../../src/TAP.pro

library TbJtagVC

analyze JtagTbPkg.vhd
analyze JtagDevVC.vhd
analyze TestCtrl.vhd
analyze TestHarness.vhd
