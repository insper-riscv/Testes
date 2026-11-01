// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 11.1
// ("Forwarding RAW EX/MEM: instrução usa resultado da anterior") —
// split out from the combined asm/hazards/ test (which bundled all
// four 11.x hazard sub-cases into one pass/fail) so a failure points
// at exactly which hazard type broke instead of "one of 4 words in
// hazards didn't match" — see asm/arithmetic-basic/src.S for the same
// reasoning applied to the original full.S sections.
#include "rv32_platform.h"


    .section .text
    .globl main

    # RAM starts at 0x00008000 now (Harvard modificado).
    .equ RESULTS_BASE, RV32_RAM_BASE

main:
    li   x5, RESULTS_BASE

    # ADD x13 depende de ADDI x11 e ADDI x12 (forwarding EX/MEM e MEM/WB)
    addi x11, x0, 5
    addi x12, x0, 3
    add  x13, x11, x12          # x13 = 8 (forwarding)
    sw   x13, 0(x5)             # esperado: 8

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
