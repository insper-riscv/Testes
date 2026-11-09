// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// Decoding rules the specification leaves to the implementation (matrix rows I8, I10 and I13):
//  1. a load with rd = x0 still raises its exception: lw x0 at an odd address in the BOOT_MEMORY traps with
//     mcause 4 and mtval = the effective address, and x0 stays zero;
//  2. FENCE ignores rs1, rd, pred and succ, and a reserved fm behaves as fm = 0: no trap, rd keeps its value;
//  3. the HINTs of the RV32I table change nothing but pc and the counters: x0 stays zero (also through the
//     forwarding path of the next instruction), nothing traps, and each one retires once, adding 1 to instret.
// The FENCE.I fields (row F2) are checked by conformance-fencei, because FENCE.I needs the Zifencei extension.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    addi x27, x5, 0x200           # trap log: cause, mepc, mtval per trap
    la   x6, handler
    csrw mtvec, x6
    li   x6, 0x0F0F0F0F           # operand of the HINTs
    li   x21, 0xA5A5A5A5          # rd sentinel of FENCE
    li   x25, 0x400               # inside the BOOT_MEMORY: a misaligned load traps

    # 1. lw x0 at an odd address
    la   x20, site_lw
site_lw:
    lw   x0, 1(x25)
    add  x8, x0, x0               # x0 is still zero

    # 2. FENCE with the fields the hardware must ignore
    .word 0x10028A8F            # fm = 1 (reserved), pred = succ = 0, rs1 = x5, rd = x21
    .word 0x20028A8F            # fm = 2 (reserved), pred = succ = 0, rs1 = x5, rd = x21
    .word 0x70028A8F            # fm = 7 (reserved), pred = succ = 0, rs1 = x5, rd = x21
    .word 0x00028A8F            # fm = 0, pred = succ = 0, rs1 = x5, rd = x21
    .word 0x03328A8F            # fm = 0, pred = RW, succ = RW, rs1 = x5, rd = x21
    .word 0xF33F8A8F            # fm = 15 (reserved), pred = RW, succ = RW, rs1 = x31, rd = x21

    # 3. HINTs: x0 as the destination of every computational instruction of the RV32I table
    csrr x9, 0xC02                # instret before
    lui   x0, 0x12345
    auipc x0, 0x00001
    addi  x0, x5, 7
    slti  x0, x5, 9
    sltiu x0, x5, 9
    xori  x0, x5, 0x55
    ori   x0, x5, 0x55
    andi  x0, x5, 0x55
    slli  x0, x5, 3
    srli  x0, x5, 3
    srai  x0, x5, 3
    add   x0, x5, x6
    sub   x0, x5, x6
    sll   x0, x5, x6
    slt   x0, x5, x6
    sltu  x0, x5, x6
    xor   x0, x5, x6
    srl   x0, x5, x6
    sra   x0, x5, x6
    or    x0, x5, x6
    and   x0, x5, x6
    .word 0x0010000F            # fm = 0, pred = 0, succ = W, rs1 = x0, rd = x0
    .word 0x0100000F            # fm = 0, pred = W, succ = 0, rs1 = x0, rd = x0 (PAUSE)
    .word 0x0030000F            # fm = 0, pred = 0, succ = RW, rs1 = x0, rd = x0
    csrr x10, 0xC02               # instret after
    sub  x10, x10, x9             # the HINTs plus the first read

    # x0 read right after each kind of HINT must be zero: the result of the HINT never reaches the operands
    li   x7, 0
    addi  x0, x5, 7
    or    x7, x7, x0
    add   x0, x5, x6
    or    x7, x7, x0
    lui   x0, 0x12345
    or    x7, x7, x0
    slli  x0, x6, 3
    or    x7, x7, x0
    xor   x0, x5, x6
    or    x7, x7, x0

    lw   x12, 512(x5)             # the trap log
    sw   x12, 0(x5)
    lw   x12, 516(x5)
    sub  x12, x12, x20            # mepc - the address of lw x0
    sw   x12, 4(x5)
    lw   x12, 520(x5)
    sub  x12, x12, x25            # mtval - the base register
    sw   x12, 8(x5)
    sw   x8, 12(x5)               # x0 after the trapping load
    sw   x21, 16(x5)              # rd of FENCE untouched
    sw   x10, 20(x5)              # instret difference
    csrr x12, 0xC82
    sw   x12, 24(x5)              # instreth
    sw   x7, 28(x5)               # x0 through the forwarding path
    sub  x12, x27, x5
    addi x12, x12, -0x200
    sw   x12, 32(x5)              # bytes of the trap log: one trap of 12 bytes

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
