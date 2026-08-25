// RV32_EXT: M
// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 10
// ("Extensão M – Conjunto Completo": MUL, MULH, MULHSU, MULHU, DIV,
// DIVU, REM, REMU) — see asm/arithmetic-basic/src.S for why this is
// split out from the original single full.S file.

    .section .text
    .globl main

main:
    addi x5, x0, 0                # x5 = RESULTS_BASE

# ---------------------------------------------------------
# 10.1 MUL (32 bits baixos do produto)
# ---------------------------------------------------------

    # MUL: 6 * 7 = 42
    addi x10, x0, 6
    addi x11, x0, 7
    mul  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MUL: -3 * 5 = -15
    addi x10, x0, -3
    addi x11, x0, 5
    mul  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MUL: -6 * -7 = 42
    addi x10, x0, -6
    addi x11, x0, -7
    mul  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MUL: 0 * 12345 = 0
    addi x10, x0, 0
    lui  x11, 0x03              # x11 = 0x3000 (qualquer valor grande)
    addi x11, x0, 123           # simplificamos para 123
    mul  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MUL: 1 * -1 = -1 (0xFFFFFFFF)
    addi x10, x0, 1
    addi x11, x0, -1
    mul  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MUL: 0x10000 * 0x10000 = 0x100000000 → lower 32 bits = 0
    lui  x10, 0x10              # x10 = 0x10000
    lui  x11, 0x10              # x11 = 0x10000
    mul  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.2 MULH (signed × signed → 32 bits altos)
# ---------------------------------------------------------

    # MULH: 6 * 7 → high = 0
    addi x10, x0, 6
    addi x11, x0, 7
    mulh x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULH: -1 * -1 → produto = +1, high = 0
    addi x10, x0, -1
    addi x11, x0, -1
    mulh x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULH: 0x7FFFFFFF * 2 → produto = 0xFFFFFFFE, high = 0
    lui  x10, 0x80000           # 0x80000000
    addi x10, x10, -1           # 0x7FFFFFFF
    addi x11, x0, 2
    mulh x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULH: -1 * 1 → produto = -1, high = 0xFFFFFFFF
    addi x10, x0, -1
    addi x11, x0, 1
    mulh x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULH: 0x40000000 * 4 → produto = 0x100000000, high = 1
    lui  x10, 0x40000           # 0x40000000
    addi x11, x0, 4
    mulh x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULH: 0x80000000 * 0x80000000 → ambos = -2^31
    #   produto signed = (-2^31)*(-2^31) = 2^62
    #   high = 0x40000000
    lui  x10, 0x80000           # 0x80000000
    lui  x11, 0x80000           # 0x80000000
    mulh x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.3 MULHU (unsigned × unsigned → 32 bits altos)
# ---------------------------------------------------------

    # MULHU: 6 * 7 → high = 0
    addi x10, x0, 6
    addi x11, x0, 7
    mulhu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULHU: 0xFFFFFFFF * 0xFFFFFFFF → high = 0xFFFFFFFE
    addi x10, x0, -1            # 0xFFFFFFFF
    addi x11, x0, -1            # 0xFFFFFFFF
    mulhu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULHU: 0x80000000 * 2 → produto unsigned = 0x100000000, high = 1
    lui  x10, 0x80000           # 0x80000000
    addi x11, x0, 2
    mulhu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULHU: 0x10000 * 0x10000 → high = 1
    lui  x10, 0x10              # 0x10000
    lui  x11, 0x10              # 0x10000
    mulhu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.4 MULHSU (signed × unsigned → 32 bits altos)
# ---------------------------------------------------------

    # MULHSU: 6 * 7 → high = 0
    addi x10, x0, 6
    addi x11, x0, 7
    mulhsu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULHSU: -1 * 1 → signed(-1)*unsigned(1) = -1, high = 0xFFFFFFFF
    addi x10, x0, -1
    addi x11, x0, 1
    mulhsu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULHSU: -1 * 0xFFFFFFFF → signed(-1)*unsigned(0xFFFFFFFF)
    #   = -0xFFFFFFFF = -4294967295, high bits = 0xFFFFFFFF
    addi x10, x0, -1            # signed -1
    addi x11, x0, -1            # unsigned 0xFFFFFFFF
    mulhsu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # MULHSU: 1 * 0xFFFFFFFF → signed(1)*unsigned(0xFFFFFFFF)
    #   = 0xFFFFFFFF, high = 0
    addi x10, x0, 1
    addi x11, x0, -1            # unsigned 0xFFFFFFFF
    mulhsu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.5 DIV (divisão com sinal, trunca em direção a zero)
# ---------------------------------------------------------

    # DIV: 20 / 4 = 5
    addi x10, x0, 20
    addi x11, x0, 4
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIV: -21 / 3 = -7
    addi x10, x0, -21
    addi x11, x0, 3
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIV: 7 / 2 = 3 (trunca)
    addi x10, x0, 7
    addi x11, x0, 2
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIV: -7 / 2 = -3 (trunca em direção a zero)
    addi x10, x0, -7
    addi x11, x0, 2
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIV: 3 / 5 = 0
    addi x10, x0, 3
    addi x11, x0, 5
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIV: 10 / 0 → divisão por zero = 0xFFFFFFFF (-1)
    addi x10, x0, 10
    addi x11, x0, 0
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIV: 0x80000000 / -1 → overflow = 0x80000000
    lui  x10, 0x80000           # x10 = 0x80000000 (-2147483648)
    addi x11, x0, -1
    div  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.6 DIVU (divisão sem sinal)
# ---------------------------------------------------------

    # DIVU: 20 / 4 = 5
    addi x10, x0, 20
    addi x11, x0, 4
    divu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIVU: 0xFFFFFFFF / 2 = 0x7FFFFFFF
    addi x10, x0, -1            # 0xFFFFFFFF
    addi x11, x0, 2
    divu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIVU: 7 / 2 = 3
    addi x10, x0, 7
    addi x11, x0, 2
    divu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # DIVU: 10 / 0 → divisão por zero = 0xFFFFFFFF
    addi x10, x0, 10
    addi x11, x0, 0
    divu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.7 REM (resto com sinal, sinal segue dividendo)
# ---------------------------------------------------------

    # REM: 20 % 4 = 0
    addi x10, x0, 20
    addi x11, x0, 4
    rem  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REM: 7 % 2 = 1
    addi x10, x0, 7
    addi x11, x0, 2
    rem  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REM: -7 % 2 = -1 (sinal segue o dividendo)
    addi x10, x0, -7
    addi x11, x0, 2
    rem  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REM: 7 % -2 = 1 (sinal segue o dividendo)
    addi x10, x0, 7
    addi x11, x0, -2
    rem  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REM: 10 % 0 → divisão por zero, resto = dividendo = 10
    addi x10, x0, 10
    addi x11, x0, 0
    rem  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REM: 0x80000000 % -1 → overflow, resto = 0
    lui  x10, 0x80000           # 0x80000000
    addi x11, x0, -1
    rem  x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

# ---------------------------------------------------------
# 10.8 REMU (resto sem sinal)
# ---------------------------------------------------------

    # REMU: 20 % 4 = 0
    addi x10, x0, 20
    addi x11, x0, 4
    remu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REMU: 7 % 2 = 1
    addi x10, x0, 7
    addi x11, x0, 2
    remu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REMU: 0xFFFFFFFF % 2 = 1
    addi x10, x0, -1            # 0xFFFFFFFF
    addi x11, x0, 2
    remu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # REMU: 10 % 0 → divisão por zero, resto = dividendo = 10
    addi x10, x0, 10
    addi x11, x0, 0
    remu x12, x10, x11
    sw   x12, 0(x5)
    addi x5, x5, 4

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x00003FFC).
    lui  x15, 0x4
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
