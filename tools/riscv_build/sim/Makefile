# GHDL + cocotb testbench driver for the "sim" test suite.
#
# <<< ADJUST: TOPLEVEL and VHDL_SOURCES are placeholders — this folder
# ships an example only, with no real core wired in. Point them at
# your actual top-level entity and its VHDL sources (in dependency
# order) before running this for real. See README.md.

SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
TOPLEVEL := rv32_core_top
MODULE := test_c_program

VHDL_SOURCES := \
    $(PWD)/../../../src/example_core.vhd

export ROM_HEX
export TEST_NAME

include $(shell cocotb-config --makefiles)/Makefile.sim
