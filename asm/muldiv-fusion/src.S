// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// The recommended pairs run once: MULH followed by MUL, and DIV followed by REM, with the same
// operands. The first operation of a pair holds the pipeline for the whole calculation (more than 32
// cycles) and the second one for a few cycles, because the unit hands back the full result of the
// first. A division of other values right after a division runs in full. The program stores the
// results, the flags of those cycle counts and the number of fused operations that event 9 counted.
// The block runs twice and the second pass counts, so that the instruction fetches of a slow memory
// do not add cache misses to the cycles that are measured.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x6, 9
    csrw 0x323, x6                # mhpmevent3 = 9 (fused operation)
    li   x11, 0x89ABCDEF          # a (negative)
    li   x12, 0x01234567          # b
    li   x13, 1000
    li   x14, 7

    li   x4, 2
0:  csrr x20, 0xB03               # fused count before
    csrr x6, 0xC00
    mulh x15, x11, x12
    csrr x7, 0xC00
    mul  x16, x11, x12
    csrr x8, 0xC00
    sub  x21, x7, x6              # cycles of MULH
    sub  x22, x8, x7              # cycles of MUL

    csrr x6, 0xC00
    div  x17, x13, x14
    csrr x7, 0xC00
    rem  x18, x13, x14
    csrr x8, 0xC00
    sub  x23, x7, x6              # cycles of DIV
    sub  x24, x8, x7              # cycles of REM

    csrr x6, 0xC00
    div  x19, x14, x13            # other values: runs in full
    csrr x7, 0xC00
    sub  x25, x7, x6              # cycles of the lone DIV
    csrr x26, 0xB03
    sub  x26, x26, x20            # operations fused
    addi x4, x4, -1
    bnez x4, 0b                   # measure again with the caches warm

    li   x9, 33
    sltu x27, x21, x9
    xori x27, x27, 1              # MULH takes at least 33 cycles
    li   x9, 10
    sltu x28, x22, x9             # MUL takes less than 10
    sltu x29, x23, x9
    xori x29, x29, 1              # DIV takes at least 10
    sltu x30, x24, x9             # REM takes less than 10
    sltu x31, x25, x9
    xori x31, x31, 1              # the lone DIV takes at least 10
    sw   x15, 0(x5)
    sw   x16, 4(x5)
    sw   x17, 8(x5)
    sw   x18, 12(x5)
    sw   x19, 16(x5)
    sw   x27, 20(x5)
    sw   x28, 24(x5)
    sw   x29, 28(x5)
    sw   x30, 32(x5)
    sw   x31, 36(x5)
    sw   x26, 40(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
