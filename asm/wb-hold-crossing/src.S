// RV32_EXT: M
// RV32_TEST_KIND: memory
//
// The datum of a load held in WB while an M operation stalls the pipeline (the multiplier and the divider take
// more than thirty cycles) must stay the datum of that load, also when the loads cross a word and so take two steps
// in MEM. Seven sequences mix aligned and crossing loads with multiplications, divisions and remainders, and every
// result is stored and compared with the golden. The accesses go to the RAM of the platform.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    addi x14, x5, 0x100           # x14 = the four-word buffer
    li   x6, 0x44F6A577
    sw   x6, 0(x14)
    li   x6, 0x00112233
    sw   x6, 4(x14)
    li   x6, 0x8899AABB
    sw   x6, 8(x14)
    li   x6, 0xCCDDEEFF
    sw   x6, 12(x14)
    li   x15, 0x12345678
    li   x16, 0x9ABCDEF1
    li   x17, 7

    # one stall behind two aligned loads (the case of the original defect)
    lw   x10, 0(x14)
    lw   x11, 4(x14)
    mul  x12, x15, x16
    sw   x10, 0(x5)
    sw   x11, 4(x5)
    sw   x12, 8(x5)

    # two loads that cross a word, then a multiplication
    lw   x10, 1(x14)
    lw   x11, 5(x14)
    mul  x12, x15, x16
    sw   x10, 12(x5)
    sw   x11, 16(x5)
    sw   x12, 20(x5)

    # an aligned load and a crossing load, then a division
    lw   x10, 4(x14)
    lw   x11, 3(x14)
    div  x12, x15, x17
    sw   x10, 24(x5)
    sw   x11, 28(x5)
    sw   x12, 32(x5)

    # a crossing load, a multiplication, a crossing load and a remainder
    lw   x10, 2(x14)
    mulh x12, x15, x16
    lw   x11, 6(x14)
    rem  x13, x15, x17
    sw   x10, 36(x5)
    sw   x12, 40(x5)
    sw   x11, 44(x5)
    sw   x13, 48(x5)

    # a crossing load in WB while three M operations stall one after the other
    lw   x10, 1(x14)
    mul  x12, x15, x16
    mul  x13, x12, x16
    divu x18, x15, x17
    sw   x10, 52(x5)
    sw   x12, 56(x5)
    sw   x13, 60(x5)
    sw   x18, 64(x5)

    # halfword loads that cross a word, then mulhu and remu
    lh   x10, 3(x14)
    lhu  x11, 7(x14)
    mulhu x12, x15, x16
    remu x13, x16, x17
    sw   x10, 68(x5)
    sw   x11, 72(x5)
    sw   x12, 76(x5)
    sw   x13, 80(x5)

    # a crossing load whose result the M operation uses
    lw   x10, 3(x14)
    mul  x12, x10, x16
    sw   x10, 84(x5)
    sw   x12, 88(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
