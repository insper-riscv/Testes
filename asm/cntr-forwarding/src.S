// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// A counter read followed at once by an instruction that uses it takes the value through the
// normal forwarding: x7 = x6 + x6 holds.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    csrr x6, 0xC00                # cycle
    add  x7, x6, x6               # uses x6 in the next stage
    csrr x8, 0xC02                # instret
    sub  x9, x8, x0               # uses x8 at once
    slli x10, x6, 1
    sub  x11, x7, x10             # 0: forwarding gave the same value
    sub  x12, x9, x8              # 0
    sw   x11, 0(x5)
    sw   x12, 4(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
