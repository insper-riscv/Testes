// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 2
// ("LUI e AUIPC") — see asm/arithmetic-basic/src.S for why this is
// split out from the original single full.S file.

    .section .text
    .globl main

main:
    addi x5, x0, 0                # x5 = RESULTS_BASE

    # LUI: x16 = 0x12345000
    lui  x16, 0x12345
    sw   x16, 0(x5)
    addi x5, x5, 4

    # AUIPC: diferença entre dois AUIPC com mesmo imediato — deve ser
    # uma constante (a distância entre as duas instruções, 4 bytes),
    # independente de onde o programa foi carregado.
auipc_test_1:
    auipc x17, 0x1                # x17 = PC1 + 0x1000
auipc_test_2:
    auipc x18, 0x1                # x18 = PC2 + 0x1000
    sub   x19, x18, x17           # = PC2 - PC1 (constante)
    sw    x19, 0(x5)
    addi  x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x00003FFC).
    lui  x15, 0x4
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
