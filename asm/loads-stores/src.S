// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 6
// ("Loads/Stores: LB, LH, LW, LBU, LHU, SB, SH, SW") — see
// asm/arithmetic-basic/src.S for why this is split out from the
// original single full.S file. Unlike most of the other split-out
// sections, this one needs full.S's own data-setup preamble too
// (TEST_DATA_BASE's seeded bytes/half/word) since it reads that data
// back — carried over unchanged, just renamed to a local RAM region
// that doesn't collide with RESULTS_BASE.

    .section .text
    .globl main

    .equ RESULTS_BASE,    0x00000000
    .equ TEST_DATA_BASE,  0x00000200
    .equ TEMP_SLOT_BASE,  0x00000300

main:
    addi x5, x0, RESULTS_BASE
    addi x8, x0, TEST_DATA_BASE
    addi x9, x0, TEMP_SLOT_BASE

    # ------------------------------------------------------
    # Seed TEST_DATA_BASE (same values full.S itself seeds)
    # ------------------------------------------------------

    # bytes: [0]=0x11, [1]=0x22, [2]=0xFF, [3]=0x80
    addi x10, x0, 0x11
    sb   x10, 0(x8)

    addi x10, x0, 0x22
    sb   x10, 1(x8)

    addi x10, x0, -1              # 0xFF
    sb   x10, 2(x8)

    addi x10, x0, -128            # 0x80 (signed)
    sb   x10, 3(x8)

    # half em [4..5]: 0x1234
    addi x10, x0, 0x12
    slli x10, x10, 8              # 0x1200
    ori  x10, x10, 0x34           # 0x1234
    sh   x10, 4(x8)

    # word em [8..11]: 0x12345678
    lui  x10, 0x12345             # 0x12345000
    addi x10, x10, 0x678          # 0x12345678
    sw   x10, 8(x8)

    # ------------------------------------------------------
    # 6. Loads/Stores (usando TEST_DATA_BASE e TEMP_SLOT_BASE)
    # ------------------------------------------------------

    # LW de word em TEST_DATA_BASE+8 → 0x12345678
    lw   x10, 8(x8)
    sw   x10, 0(x5)
    addi x5, x5, 4

    # LH signed de half em TEST_DATA_BASE+4 → 0x00001234
    lh   x11, 4(x8)
    sw   x11, 0(x5)
    addi x5, x5, 4

    # LHU de half → 0x00001234
    lhu  x12, 4(x8)
    sw   x12, 0(x5)
    addi x5, x5, 4

    # LB signed de 0xFF → -1
    lb   x13, 2(x8)
    sw   x13, 0(x5)
    addi x5, x5, 4

    # LBU de 0xFF → 0x000000FF
    lbu  x14, 2(x8)
    sw   x14, 0(x5)
    addi x5, x5, 4

    # Teste de SB/LB em TEMP_SLOT_BASE
    addi x15, x0, 0x55
    sb   x15, 0(x9)
    lb   x16, 0(x9)
    sw   x16, 0(x5)
    addi x5, x5, 4

    # SH/LH em TEMP_SLOT_BASE+2
    addi x17, x0, 0x7F
    slli x17, x17, 1          # 0xFE
    sh   x17, 2(x9)
    lh   x18, 2(x9)
    sw   x18, 0(x5)
    addi x5, x5, 4

    # SW/LW em TEMP_SLOT_BASE+4
    lui  x19, 0x7F000         # 0x7F000000
    sw   x19, 4(x9)
    lw   x20, 4(x9)
    sw   x20, 0(x5)
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x00003FFC).
    lui  x21, 0x4
    addi x22, x0, 1
    sw   x22, -4(x21)          // mailbox = 1

    j rv32_wait_restart
