// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 4
// ("Comparações: SLT, SLTU, SLTI, SLTIU") — see
// asm/arithmetic-basic/src.S for why this is split out from the
// original single full.S file.

    .section .text
    .globl main

main:
    li   x5, 0x00010000        # x5 = RESULTS_BASE (RAM now starts at 0x10000)

    # x28 = -5, x29 = 3
    addi x28, x0, -5
    addi x29, x0, 3

    # SLT signed: -5 < 3 → 1
    slt  x30, x28, x29
    sw   x30, 0(x5)
    addi x5, x5, 4

    # SLTU unsigned: 0xFFFFFFFB < 3 → 0
    sltu x31, x28, x29
    sw   x31, 0(x5)
    addi x5, x5, 4

    # SLTI: 3 < 10 → 1
    addi x10, x0, 3
    slti x10, x10, 10
    sw   x10, 0(x5)
    addi x5, x5, 4

    # SLTIU: 3 < 1 unsigned → 0
    addi x11, x0, 3
    sltiu x11, x11, 1
    sw   x11, 0(x5)
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x0001FFFC).
    lui  x15, 0x20
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
