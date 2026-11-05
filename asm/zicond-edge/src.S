// RV32_EXT: Zicond
// RV32_TEST_KIND: memory
//
// czero.eqz and czero.nez of the Zicond extension (chapter 10 of the unprivileged manual) on the
// edge cases: rs2 zero and nonzero (including only the top bit and only the bottom bit), rs1 and
// rd in the same register, rd = x0, rs1 = x0, rs1 and rs2 in the same register, and the forwarding
// of rs2 and of the result into the next instruction. Each result goes to a word of the RAM.
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
    li   x1, 0xDEADBEEF           # rs1 value
    li   x2, 0                    # rs2 zero
    li   x3, 1                    # rs2 nonzero, only the bottom bit
    li   x4, 0x80000000           # rs2 nonzero, only the top bit

    CZERO_EQZ x10, x1, x2         # rs2 = 0   -> 0
    CZERO_EQZ x11, x1, x3         # rs2 != 0  -> rs1
    CZERO_EQZ x12, x1, x4         # rs2 != 0  -> rs1
    CZERO_NEZ x13, x1, x2         # rs2 = 0   -> rs1
    CZERO_NEZ x14, x1, x3         # rs2 != 0  -> 0
    CZERO_NEZ x15, x1, x4         # rs2 != 0  -> 0
    sw   x10, 0(x5)
    sw   x11, 4(x5)
    sw   x12, 8(x5)
    sw   x13, 12(x5)
    sw   x14, 16(x5)
    sw   x15, 20(x5)

    # rs1 and rs2 in the same register: the value is nonzero, so eqz passes it and nez zeroes it.
    CZERO_EQZ x16, x1, x1
    CZERO_NEZ x17, x1, x1
    sw   x16, 24(x5)
    sw   x17, 28(x5)

    # rs1 = x0: the result is zero in every case.
    CZERO_EQZ x18, x0, x3
    CZERO_NEZ x19, x0, x2
    CZERO_EQZ x20, x0, x2
    CZERO_NEZ x21, x0, x3
    sw   x18, 32(x5)
    sw   x19, 36(x5)
    sw   x20, 40(x5)
    sw   x21, 44(x5)

    # rd = rs1: the old value is read before the write.
    mv   x22, x1
    mv   x23, x1
    CZERO_EQZ x22, x22, x2        # zero
    CZERO_NEZ x23, x23, x2        # unchanged
    sw   x22, 48(x5)
    sw   x23, 52(x5)

    # rd = x0: the write is discarded.
    CZERO_NEZ x0, x1, x2
    CZERO_EQZ x0, x1, x3
    sw   x0, 56(x5)

    # rs2 produced by the previous instruction (forwarding of the operand).
    li   x24, 0
    CZERO_NEZ x25, x1, x24        # rs2 = 0 -> rs1
    li   x24, 3
    CZERO_NEZ x26, x1, x24        # rs2 != 0 -> 0
    sw   x25, 60(x5)
    sw   x26, 64(x5)

    # The result is used by the next instruction (forwarding of the result).
    CZERO_EQZ x27, x1, x3
    add  x28, x27, x27            # 2 * rs1
    CZERO_EQZ x29, x1, x2
    add  x30, x29, x3             # 0 + 1
    sw   x28, 68(x5)
    sw   x30, 72(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
