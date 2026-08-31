// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 1
// ("Aritmética básica: ADD, ADDI, SUB") — one of 11 sections that
// file tested as a single sequential log with no PASS/FAIL of its
// own (see full.json, its golden RAM snapshot). Split into one
// self-contained, self-verifying test per section so a failure
// points at exactly which instruction broke instead of "somewhere in
// 82 words of results". Instructions and expected values are
// unchanged from the original; only the write pointer restarts at 0
// (RESULTS_BASE here, same as full.S) since each split test is its
// own program, and the ending now signals PASS via the mailbox
// instead of full.S's own infinite `end: jal x0, end` loop.

    .section .text
    .globl main

main:
    li   x5, 0x00010000        # x5 = RESULTS_BASE (write pointer, RAM starts at 0x10000)

    # ADDI: x11 = 5
    addi x11, x0, 5
    # ADDI: x12 = 7
    addi x12, x0, 7

    # ADD: x13 = 5 + 7 = 12
    add  x13, x11, x12
    sw   x13, 0(x5)
    addi x5, x5, 4

    # SUB: x14 = 7 - 5 = 2
    sub  x14, x12, x11
    sw   x14, 0(x5)
    addi x5, x5, 4

    # ADDI com negativo: x15 = -1
    addi x15, x0, -1
    sw   x15, 0(x5)
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x0001FFFC).
    lui  x15, 0x20
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
