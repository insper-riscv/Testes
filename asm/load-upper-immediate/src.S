// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 2
// ("LUI e AUIPC") — the LUI sub-case, split out from the combined
// asm/lui-auipc/ test (which bundled LUI and AUIPC into one pass/fail)
// so a failure points at exactly which one broke — see
// asm/arithmetic-basic/src.S for the same reasoning applied to the
// original full.S sections.
#include "rv32_platform.h"


    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE (RAM now starts at 0x8000)

    # LUI: x16 = 0x12345000
    lui  x16, 0x12345
    sw   x16, 0(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
