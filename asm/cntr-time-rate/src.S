// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// time advances by one tick every RV32_TICK_CYCLES cycles (the platform's interrupts.clock_hz over
// mtime_hz; 50 when the platform header does not say): the cycles between two ticks, read from
// cycle, are close to it (5 below to 5 above) and time never goes backwards. The measure runs twice and the
// second one counts, so the instruction fetches of the first fill the caches and a slow FLASH
// does not add a miss to the cycles between two ticks.
#include "rv32_platform.h"

#ifndef RV32_TICK_CYCLES
#define RV32_TICK_CYCLES 50
#endif

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x16, 2
0:  csrr x6, 0xC01
1:  csrr x7, 0xC01
    beq  x7, x6, 1b               # wait for a tick edge
    csrr x8, 0xC00                # cycle at the edge
    mv   x6, x7
2:  csrr x7, 0xC01
    beq  x7, x6, 2b               # wait for the next tick
    csrr x9, 0xC00
    sub  x10, x9, x8              # cycles between two ticks
    addi x16, x16, -1
    bnez x16, 0b                  # measure again with the caches warm
    li   x11, RV32_TICK_CYCLES - 5
    sltu x12, x10, x11
    xori x12, x12, 1              # x12 = 1: at least 45
    li   x13, RV32_TICK_CYCLES + 6
    sltu x14, x10, x13            # x14 = 1: below 56
    sub  x15, x7, x6              # time moved by exactly 1
    sw   x12, 0(x5)
    sw   x14, 4(x5)
    sw   x15, 8(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
