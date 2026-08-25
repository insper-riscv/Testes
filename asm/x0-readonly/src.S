// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 9
// ("Teste de x0 — não pode ser modificado") — see
// asm/arithmetic-basic/src.S for why this is split out from the
// original single full.S file.

    .section .text
    .globl main

main:
    addi x5, x0, 0                # x5 = RESULTS_BASE

    addi x0, x0, 5                # deve ser ignorado
    sw   x0, 0(x5)                # grava 0
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x00003FFC).
    lui  x15, 0x4
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
