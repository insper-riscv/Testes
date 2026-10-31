// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// Event 1 (multiply/divide stall) on mhpmcounter3: a division holds the pipeline for the cycles of
// the divider, so the counter moves by the same number of cycles that the division adds to mcycle
// over the instruction count (at least 32), and a run of simple instructions leaves it alone.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x6, 1
    csrw 0x323, x6                # mhpmevent3 = 1 (muldiv stall)
    li   x11, 1000
    li   x12, 7

    csrr x10, 0xB03
    addi x20, x0, 1
    addi x21, x0, 2
    addi x22, x0, 3
    csrr x13, 0xB03
    sub  x14, x13, x10            # 0 with simple instructions

    csrr x10, 0xB03
    div  x15, x11, x12            # 142
    csrr x13, 0xB03
    sub  x16, x13, x10            # divider cycles
    li   x17, 32
    sltu x18, x16, x17
    xori x18, x18, 1              # x18 = 1: at least 32
    sw   x14, 0(x5)
    sw   x18, 4(x5)
    sw   x15, 8(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
