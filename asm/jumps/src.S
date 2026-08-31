// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 8
// ("Jumps: JAL e JALR") — see asm/arithmetic-basic/src.S for why
// this is split out from the original single full.S file.

    .section .text
    .globl main

main:
    li   x5, 0x00010000        # x5 = RESULTS_BASE (RAM now starts at 0x10000)

    # --- JAL: testa salto + fluxo de controle ---
    # x13 vai acumular um padrão conhecido se passar
    addi x13, x0, 0

    jal  x1, jal_helper          # salta para jal_helper
after_jal:
    addi x13, x13, 1             # +1 se voltou do helper
    sw   x13, 0(x5)              # valor esperado = 3 (2 no helper + 1 aqui)
    addi x5, x5, 4

    jal  x0, jal_done            # segue para teste de JALR

jal_helper:
    addi x13, x13, 2             # +2 ao entrar
    jal  x0, after_jal

jal_done:

    # --- JALR: usa ra de um JAL como retorno ---
    # x14 conta quantas vezes passou pelos pontos certos
    addi x14, x0, 0

    # Faz um JAL para obter ra em x1
    jal  x1, jalr_helper_entry
after_jal_for_jalr:
    addi x14, x14, 2             # +2 se voltou corretamente via JALR
    sw   x14, 0(x5)              # valor esperado = 3 (1 no helper + 2 aqui)
    addi x5, x5, 4

    jal  x0, jalr_done

jalr_helper_entry:
    addi x14, x14, 1             # +1 ao entrar
    # usa JALR com x1 (ra) como destino pra voltar pra after_jal_for_jalr
    jalr x0, x1, 0

jalr_done:

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x0001FFFC).
    lui  x15, 0x20
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
