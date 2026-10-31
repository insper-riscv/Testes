// RV32_TEST_KIND: memory
//
// Ported from RV32IM's tests/FPGA/core/asm_tests/full.S, section 3
// (Lógicos) — the XOR sub-case, split out from the combined
// asm/logical-ops/ test (which bundled 6 different logical opcodes
// into one pass/fail) so a failure points at exactly which one broke
// — see asm/arithmetic-basic/src.S for the same reasoning applied to
// the original full.S sections.
#include "rv32_platform.h"


    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE (RAM now starts at 0x8000)

    # x20 = 0x000000FF
    addi x20, x0, 0x0F0
    ori  x20, x20, 0x00F          # 0x0FF

    # x21 = 0x000000F0
    addi x21, x0, 0x0F0

    # XOR
    xor  x22, x20, x21
    sw   x22, 0(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
