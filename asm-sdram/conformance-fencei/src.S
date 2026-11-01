// RV32_EXT: M,Zicsr,Zifencei
// RV32_TEST_KIND: memory
//
// FENCE.I ignores funct12, rs1 and rd (matrix row F2): with any value in them it does not trap, rd keeps its value,
// and the instruction after it runs. Needs the Zifencei extension, so it runs on the SDRAM platforms.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    addi x27, x5, 0x200           # trap log: cause, mepc, mtval per trap
    la   x6, handler
    csrw mtvec, x6
    li   x22, 0x5A5A5A5A          # rd sentinel of FENCE.I
    li   x23, 0
    .word 0x12329B0F            # funct12 = 0x123, rs1 = x5, rd = x22
    addi x23, x23, 1              # runs after the FENCE.I
    .word 0xFFFF9B0F            # funct12 = 0xFFF, rs1 = x31, rd = x22
    addi x23, x23, 1              # runs after the FENCE.I
    .word 0x00029B0F            # funct12 = 0, rs1 = x5, rd = x22
    addi x23, x23, 1              # runs after the FENCE.I
    .word 0x00101B0F            # funct12 = 1, rs1 = x0, rd = x22
    addi x23, x23, 1              # runs after the FENCE.I
    .word 0x0000100F            # funct12 = 0, rs1 = x0, rd = x0 (the canonical encoding)
    addi x23, x23, 1              # runs after the FENCE.I

    sw   x22, 0(x5)               # rd of FENCE.I untouched
    sw   x23, 4(x5)               # the instruction after each FENCE.I ran
    sub  x12, x27, x5
    addi x12, x12, -0x200
    sw   x12, 8(x5)               # bytes of the trap log: no trap

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS

    .balign 4
handler:
    csrr x28, mcause
    csrr x29, mepc
    csrr x30, mtval
    sw   x28, 0(x27)
    sw   x29, 4(x27)
    sw   x30, 8(x27)
    addi x27, x27, 12
    addi x29, x29, 4              # resume after the instruction that trapped
    csrw mepc, x29
    mret
