// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 7
// ("Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU") — writes 1 if the
// branch was taken, 0 if not. See asm/arithmetic-basic/src.S for why
// this is split out from the original single full.S file.

    .section .text
    .globl main

main:
    addi x5, x0, 0                # x5 = RESULTS_BASE

    # BEQ: 5 == 5 → 1
    addi x10, x0, 5
    addi x11, x0, 5
    beq  x10, x11, beq_taken
    addi x12, x0, 0
    sw   x12, 0(x5)
    addi x5, x5, 4
    jal  x0, beq_done
beq_taken:
    addi x12, x0, 1
    sw   x12, 0(x5)
    addi x5, x5, 4
beq_done:

    # BNE: 5 != 6 → 1
    addi x10, x0, 5
    addi x11, x0, 6
    bne  x10, x11, bne_taken
    addi x12, x0, 0
    sw   x12, 0(x5)
    addi x5, x5, 4
    jal  x0, bne_done
bne_taken:
    addi x12, x0, 1
    sw   x12, 0(x5)
    addi x5, x5, 4
bne_done:

    # BLT signed: -1 < 1 → 1
    addi x10, x0, -1
    addi x11, x0, 1
    blt  x10, x11, blt_taken
    addi x12, x0, 0
    sw   x12, 0(x5)
    addi x5, x5, 4
    jal  x0, blt_done
blt_taken:
    addi x12, x0, 1
    sw   x12, 0(x5)
    addi x5, x5, 4
blt_done:

    # BGE signed: 3 >= -2 → 1
    addi x10, x0, 3
    addi x11, x0, -2
    bge  x10, x11, bge_taken
    addi x12, x0, 0
    sw   x12, 0(x5)
    addi x5, x5, 4
    jal  x0, bge_done
bge_taken:
    addi x12, x0, 1
    sw   x12, 0(x5)
    addi x5, x5, 4
bge_done:

    # BLTU unsigned: 1 < 0xFFFFFFFF → 1
    addi x10, x0, 1
    addi x11, x0, -1         # 0xFFFFFFFF
    bltu x10, x11, bltu_taken
    addi x12, x0, 0
    sw   x12, 0(x5)
    addi x5, x5, 4
    jal  x0, bltu_done
bltu_taken:
    addi x12, x0, 1
    sw   x12, 0(x5)
    addi x5, x5, 4
bltu_done:

    # BGEU unsigned: 0xFFFFFFFF >= 1 → 1
    addi x10, x0, -1
    addi x11, x0, 1
    bgeu x10, x11, bgeu_taken
    addi x12, x0, 0
    sw   x12, 0(x5)
    addi x5, x5, 4
    jal  x0, bgeu_done
bgeu_taken:
    addi x12, x0, 1
    sw   x12, 0(x5)
    addi x5, x5, 4
bgeu_done:

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x00003FFC).
    lui  x15, 0x4
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
