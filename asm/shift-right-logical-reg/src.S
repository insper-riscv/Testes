// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 5
// (Shifts) — the SRL sub-case, split out from the combined
// asm/shifts/ test (which bundled 6 different shift opcodes into one
// pass/fail) so a failure points at exactly which one broke — see
// asm/arithmetic-basic/src.S for the same reasoning applied to the
// original full.S sections.
#include "rv32_platform.h"


    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE (RAM now starts at 0x8000)

    # SRL: 16 >> 2 = 4
    addi x15, x0, 16
    addi x16, x0, 2
    srl  x17, x15, x16
    sw   x17, 0(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
