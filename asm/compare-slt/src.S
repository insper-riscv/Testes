// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 4
// (Comparações) — the SLT sub-case, split out from the combined
// asm/comparisons/ test (which bundled 4 different compare opcodes
// into one pass/fail) so a failure points at exactly which one broke
// — see asm/arithmetic-basic/src.S for the same reasoning applied to
// the original full.S sections.
#include "rv32_platform.h"


    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE (RAM now starts at 0x8000)

    # x28 = -5, x29 = 3
    addi x28, x0, -5
    addi x29, x0, 3

    # SLT signed: -5 < 3 → 1
    slt  x30, x28, x29
    sw   x30, 0(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
