
HDL=ghdl
FLAGS= --std=08
# This option is useful for silencing certain
#  warnings that come from numeric-std at T=0
SIM_FLAGS=--ieee-asserts=disable-at-0
# @NOTE - This is useful for when we want to batch
#   run the tests (for example, in CI) and we want
#   to indicate that the tests have not passed.
ifeq ($(ASSERT_ERR), 1)
	SIM_FLAGS += --assert-level=error
endif

TEST_DIR=./tests
# Tests should be files at the path "tests/{entity}.vhd"
#   Where '{entity}' is the top level entity in the test.
#   Entity names must be unique for all tests to run.
TEST_FILES = $(wildcard $(TEST_DIR)/*.vhd)
TESTS = $(basename $(notdir $(TEST_FILES)))

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

build-all: $(TEST_FILES) $(SRCS)
	$(HDL) -a $(FLAGS) $(SRCS) $(TEST_FILES)

%: $(TEST_DIR)/%.vhd $(SRCS) build-all
	$(HDL) -e $(FLAGS) $@
	$(HDL) -r $(FLAGS) $@ $(SIM_FLAGS) \
		--wave=$(WAVES_DIR)/$@.ghw

make_waves:
	@mkdir -p $(WAVES_DIR)

.PHONY: make_waves
