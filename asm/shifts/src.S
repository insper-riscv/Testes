// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 5
// ("Shifts: SLL, SRL, SRA, SLLI, SRLI, SRAI") — see
// asm/arithmetic-basic/src.S for why this is split out from the
// original single full.S file.

    .section .text
    .globl main

main:
    li   x5, 0x00010000        # x5 = RESULTS_BASE (RAM now starts at 0x10000)

    # SLL: 1 << 4 = 16
    addi x12, x0, 1
    addi x13, x0, 4
    sll  x14, x12, x13
    sw   x14, 0(x5)
    addi x5, x5, 4

    # SRL: 16 >> 2 = 4
    addi x15, x0, 16
    addi x16, x0, 2
    srl  x17, x15, x16
    sw   x17, 0(x5)
    addi x5, x5, 4

    # SRA: -16 >> 2 = -4
    addi x18, x0, -16
    addi x19, x0, 2
    sra  x20, x18, x19
    sw   x20, 0(x5)
    addi x5, x5, 4

    # SLLI: 1 << 3 = 8
    addi x21, x0, 1
    slli x22, x21, 3
    sw   x22, 0(x5)
    addi x5, x5, 4

    # SRLI: 32 >> 3 = 4
    addi x23, x0, 32
    srli x24, x23, 3
    sw   x24, 0(x5)
    addi x5, x5, 4

    # SRAI: -32 >> 3 = -4
    addi x25, x0, -32
    srai x26, x25, 3
    sw   x26, 0(x5)
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x0001FFFC).
    lui  x15, 0x20
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
