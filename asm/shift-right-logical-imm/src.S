// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 5
// (Shifts) — the SRLI sub-case, split out from the combined
// asm/shifts/ test (which bundled 6 different shift opcodes into one
// pass/fail) so a failure points at exactly which one broke — see
// asm/arithmetic-basic/src.S for the same reasoning applied to the
// original full.S sections.

    .section .text
    .globl main

main:
    li   x5, 0x00010000        # x5 = RESULTS_BASE (RAM now starts at 0x10000)

    # SRLI: 32 >> 3 = 4
    addi x23, x0, 32
    srli x24, x23, 3
    sw   x24, 0(x5)

    # Signal PASS via the mailbox (see include/rv32_test.h /
    # config.yaml memory.mailbox_addr — 0x0001FFFC).
    lui  x15, 0x20
    addi x14, x0, 1
    sw   x14, -4(x15)          // mailbox = 1

    j rv32_wait_restart
