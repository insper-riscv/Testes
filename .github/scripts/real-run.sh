#!/usr/bin/env bash
# Runs inside Insper/Infra's ci-elf image (see .github/workflows/real.yml): builds the ROM images and
# goldens and runs the suite on the FPGA, with the platform from the Insper-RISC-V submodule. Quartus is the
# host's, mounted read-only at $QUARTUS_ROOT, and the board is reached through the host's jtagd.
set -euo pipefail

quartus_root="${QUARTUS_ROOT:-/opt/altera_lite}"
export PATH="$quartus_root/25.1std/quartus/bin:$PATH"

uv sync

# The board runs the de0-cv platform (the SDRAM is the RAM; the host reaches it through the JTAG
# debug port): the existing programs, then the ones that use the SDRAM.
regression=tools/riscv_build/config.sdram-flash-regression.yaml
sdram=tools/riscv_build/config.sdram-flash.yaml

riscv-tools --config "$regression" generate-header
# compile also generates each C memory test's golden under Spike.
riscv-tools --config "$regression" compile --emit mif
riscv-tools --config "$sdram" compile --emit mif

# The first run compiles the Quartus project and programs the board once; the second reuses it.
mkdir -p build-flash/real build-sdram-flash/real
riscv-tools --config "$regression" run | tee build-flash/real/latest.log
riscv-tools --config "$sdram" run --skip-reconfigure | tee build-sdram-flash/real/latest.log
