
HDL=ghdl
FLAGS=
SIM_FLAGS=
# @NOTE - This is useful for when we want to batch
#   run the tests (for example, in CI).
#SIM_FLAGS=--assert-level=error

TEST_DIR=./tests
# Tests should be files at the path "tests/{entity}.vhd"
#   Where '{entity}' is the top level entity in the test.
#   Entity names must be unique for all tests to run.
TESTS = $(basename $(notdir $(wildcard $(TEST_DIR)/*.vhd)))

SRC_DIR=./src
# @NOTE - Order here matters because of the way
#   that dependencies and libraries are evaluated
#   in ghdl.
SRCS= \
	$(SRC_DIR)/JTAG.vhd \
	$(SRC_DIR)/BitTools.vhd \
	$(SRC_DIR)/CompDefs.vhd \
	$(SRC_DIR)/TestTools.vhd \
	$(SRC_DIR)/JTAG_DUT.vhd \
	$(SRC_DIR)/TAPController.vhd


WAVES_DIR=./waves

all: make_waves $(TESTS)

%: $(TEST_DIR)/%.vhd $(SRCS)
	$(HDL) -a $(FLAGS) $(SRCS) $<
	$(HDL) -e $(FLAGS) $@
	$(HDL) -r $(FLAGS) $@ \
		$(SIM_FLAGS) \
		--wave=$(WAVES_DIR)/$@.ghw

make_waves:
	@mkdir -p $(WAVES_DIR)

.PHONY: make_waves
