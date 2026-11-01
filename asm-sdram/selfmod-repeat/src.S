// RV32_EXT: Zifencei
// RV32_TEST_KIND: unit
//
// Code in the SDRAM rewritten again and again while its line is in both caches. The routine returns
// a constant that is the immediate of its first instruction. The program calls it, patches the
// immediate, runs FENCE.I and calls it again, eight times: every call must return the value of the
// last patch, which holds only if the store reached the SDRAM, the data cache kept no stale copy of the
// word, and FENCE.I dropped the line of the instruction cache.
#include "rv32_platform.h"

    .section .text
    .globl main

#define CODE_AT 0x40200000          /* the routine in the SDRAM, away from data and stack */

main:
    # copy the routine (two words) from the FLASH to the SDRAM
    la   x6, payload_begin
    li   x8, CODE_AT
    lw   x9, 0(x6)
    sw   x9, 0(x8)
    lw   x9, 4(x6)
    sw   x9, 4(x8)
    fence.i

    li   x20, 8                     # patches left
    li   x21, 100                   # the constant the routine returns now
    li   x22, 0                     # the number of the patch
1:  li   x8, CODE_AT
    jalr x1, 0(x8)
    bne  x10, x21, fail
    # patch `addi x10, x0, imm`: the immediate is bits 31:20
    addi x21, x21, 7
    slli x14, x21, 20
    li   x15, 0x00000513            # addi x10, x0, 0
    or   x14, x14, x15
    li   x8, CODE_AT
    sw   x14, 0(x8)
    lw   x16, 0(x8)                 # the data cache holds the new word too
    bne  x16, x14, fail_load
    fence.i
    addi x22, x22, 1
    addi x20, x20, -1
    bnez x20, 1b

    RVMODEL_HALT_PASS

fail:
    RVMODEL_HALT_FAIL(1)
fail_load:
    RVMODEL_HALT_FAIL(2)

    .balign 4
payload_begin:
    addi x10, x0, 100
    ret
