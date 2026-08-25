// RV32_EXT: M
// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 11
// ("Dependências de dados / Hazards": forwarding, load-use stall) —
// see asm/arithmetic-basic/src.S for why this is split out from the
// original single full.S file. 11.3 needs a RAM base pointer (x8),
// carried over from full.S's own TEST_DATA_BASE — it writes its own
// fresh value there rather than reading pre-seeded data, so (unlike
// asm/loads-stores/src.S) no data-init preamble is needed, just the
// base pointer itself.

    .section .text
    .globl main

    .equ RESULTS_BASE,    0x00000000
    .equ TEST_DATA_BASE,  0x00000200

main:
    addi x5, x0, RESULTS_BASE
    addi x8, x0, TEST_DATA_BASE

# ---------------------------------------------------------
# 11.1 Forwarding RAW EX/MEM: instrução usa resultado da anterior
# ---------------------------------------------------------
    # ADD x13 depende de ADDI x11 e ADDI x12 (forwarding EX/MEM e MEM/WB)
    addi x11, x0, 5
    addi x12, x0, 3
    add  x13, x11, x12          # x13 = 8 (forwarding)
    sw   x13, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 11.2 Forwarding em cadeia: 3 instruções consecutivas dependentes
# ---------------------------------------------------------
    addi x11, x0, 1
    addi x11, x11, 1            # x11 = 2 (forwarding EX/MEM)
    addi x11, x11, 1            # x11 = 3 (forwarding EX/MEM)
    sw   x11, 0(x5)             # esperado: 3
    addi x5, x5, 4

# ---------------------------------------------------------
# 11.3 Load-use hazard: LW seguido imediatamente de instrução dependente
# ---------------------------------------------------------
    addi x10, x0, 42
    sw   x10, 0x7C(x8)          # RAM[0x27C] = 42 (area de teste, longe dos resultados)
    lw   x11, 0x7C(x8)          # x11 = 42
    add  x12, x11, x0           # x12 = x11 (load-use hazard: stall de 1 ciclo)
    sw   x12, 0(x5)             # esperado: 42
    addi x5, x5, 4

# ---------------------------------------------------------
# 11.4 Forwarding após MUL (resultado de instrução M usado imediatamente)
# ---------------------------------------------------------
    addi x10, x0, 6
    addi x11, x0, 7
    mul  x12, x10, x11          # x12 = 42 (stall multdiv)
    add  x13, x12, x0           # x13 = 42 (forwarding do resultado M)
    sw   x13, 0(x5)             # esperado: 42
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x00003FFC).
    lui  x15, 0x4
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
