// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// Event 3 (taken branch) on mhpmcounter3: a loop of 16 iterations closes with a branch that is
// taken 15 times and falls through once, so the counter moves by exactly 15. The event of
// another counter, set to 0, does not move.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x6, 3
    csrw 0x323, x6                # mhpmevent3 = 3 (taken branch)
    csrw 0x324, x0                # mhpmevent4 = 0 (no event)
    csrr x10, 0xB03               # mhpmcounter3 before
    csrr x11, 0xB04
    li   x7, 16
1:  addi x7, x7, -1
    bnez x7, 1b                   # taken 15 times
    csrr x12, 0xB03
    csrr x13, 0xB04
    sub  x14, x12, x10            # 15
    sub  x15, x13, x11            # 0
    csrr x16, 0xB83               # mhpmcounter3h = 0
    sw   x14, 0(x5)
    sw   x15, 4(x5)
    sw   x16, 8(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
