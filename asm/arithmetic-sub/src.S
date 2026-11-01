// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 1
// (Aritmética básica) — the SUB sub-case, split out from the combined
// asm/arithmetic-basic/ test (which bundled ADD/SUB/ADDI into one
// pass/fail) so a failure points at exactly which one broke — same
// reasoning as arithmetic-basic's own split from full.S, one level
// deeper.
#include "rv32_platform.h"


    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE (RAM now starts at 0x8000)

    # ADDI: x11 = 5
    addi x11, x0, 5
    # ADDI: x12 = 7
    addi x12, x0, 7

    # SUB: x14 = 7 - 5 = 2
    sub  x14, x12, x11
    sw   x14, 0(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
