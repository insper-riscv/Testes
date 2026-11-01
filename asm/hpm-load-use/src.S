// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// Event 8 (load-use stall) on mhpmcounter3, one pulse per stalled cycle. Five loads, each followed
// by an instruction that uses the loaded register, stall the pipeline (d1 > 0); with one
// instruction between the load and its use the stall is no longer (d2 <= d1); with two instructions
// between them there is no stall at all (d3 = 0). The exact counts depend on the wait states of the
// data memory (10, 5 and 0 on the platform with the RAM inside the core), so the program stores
// three flags instead of the counts.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x6, 8
    csrw 0x323, x6                # mhpmevent3 = 8 (load-use)
    addi x20, x5, 64              # a word of data below RESULTS
    sw   x0, 0(x20)

    csrr x10, 0xB03
    lw   x21, 0(x20)
    add  x22, x21, x21
    lw   x21, 0(x20)
    add  x22, x21, x21
    lw   x21, 0(x20)
    add  x22, x21, x21
    lw   x21, 0(x20)
    add  x22, x21, x21
    lw   x21, 0(x20)
    add  x22, x21, x21
    csrr x11, 0xB03
    sub  x12, x11, x10            # d1

    csrr x13, 0xB03
    lw   x21, 0(x20)
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    add  x22, x21, x21
    csrr x14, 0xB03
    sub  x15, x14, x13            # d2

    csrr x16, 0xB03
    lw   x21, 0(x20)
    nop
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    nop
    add  x22, x21, x21
    lw   x21, 0(x20)
    nop
    nop
    add  x22, x21, x21
    csrr x17, 0xB03
    sub  x18, x17, x16            # d3
    sltu x6, x0, x12              # d1 > 0
    sltiu x7, x18, 1              # d3 = 0
    sltu x8, x12, x15
    xori x8, x8, 1                # d2 <= d1
    sw   x6, 0(x5)
    sw   x7, 4(x5)
    sw   x8, 8(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
