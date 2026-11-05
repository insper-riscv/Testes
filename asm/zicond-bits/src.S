// RV32_EXT: Zicond
// RV32_TEST_KIND: memory
//
// Every bit of rs2 decides the condition of czero.eqz and czero.nez, and every bit of rs1 reaches
// rd. For each bit position i from 0 to 31 the loop uses rs2 = 1 << i and rs1 = 0xFFFFFFFF, so
// czero.eqz must give rs1 and czero.nez must give 0; it counts the positions where that holds.
// A second loop uses rs1 = 1 << i with rs2 = 1 for czero.eqz and rs2 = 0 for czero.nez, so both
// must give rs1, and counts the positions where it holds. Both counts must be 32.
#include "rv32_platform.h"

    .section .text
    .globl main

    # czero.eqz rd, rs1, rs2: funct7 = 0000111, funct3 = 101, opcode = OP.
    .macro CZERO_EQZ rd, rs1, rs2
    .insn r 0x33, 5, 0x07, \rd, \rs1, \rs2
    .endm

    # czero.nez rd, rs1, rs2: funct7 = 0000111, funct3 = 111, opcode = OP.
    .macro CZERO_NEZ rd, rs1, rs2
    .insn r 0x33, 7, 0x07, \rd, \rs1, \rs2
    .endm

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x6, -1                   # rs1 = all ones
    li   x7, 1                    # rs2 = 1 << i
    li   x8, 0                    # positions where the rs2 loop gave the right answer
    li   x9, 32                   # number of positions
    li   x10, 0                   # i

rs2_loop:
    CZERO_EQZ x11, x6, x7         # rs2 != 0 -> rs1 = all ones
    CZERO_NEZ x12, x6, x7         # rs2 != 0 -> 0
    li   x13, -1
    bne  x11, x13, rs2_next
    bne  x12, x0, rs2_next
    addi x8, x8, 1
rs2_next:
    slli x7, x7, 1
    addi x10, x10, 1
    bne  x10, x9, rs2_loop

    li   x7, 1                    # rs1 = 1 << i
    li   x14, 0                   # positions where the rs1 loop gave the right answer
    li   x10, 0                   # i
    li   x15, 1                   # rs2 that passes eqz

rs1_loop:
    CZERO_EQZ x11, x7, x15        # rs2 = 1 -> rs1
    CZERO_NEZ x12, x7, x0         # rs2 = 0 -> rs1
    bne  x11, x7, rs1_next
    bne  x12, x7, rs1_next
    addi x14, x14, 1
rs1_next:
    slli x7, x7, 1
    addi x10, x10, 1
    bne  x10, x9, rs1_loop

    sw   x8, 0(x5)                # 32
    sw   x14, 4(x5)               # 32

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
