// RV32_EXT: M
// RV32_TEST_KIND: memory
//
// Two divisions in a row, with nothing between them: what a compiler emits
// for `n / 10` and `n % 10` (GCC puts the div and the rem next to each
// other), and so what printf's integer conversion runs. The other
// div/rem tests run one division at a time, with other instructions after
// it, and do not reach this case.
#include "rv32_platform.h"


    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x10, 42
    li   x11, 10

    # div then rem: 42 / 10 = 4, 42 % 10 = 2
    div  x12, x10, x11
    rem  x13, x10, x11
    sw   x12, 0(x5)
    sw   x13, 4(x5)

    # rem then div: the same, in the other order
    rem  x13, x10, x11
    div  x12, x10, x11
    sw   x13, 8(x5)
    sw   x12, 12(x5)

    # divu then remu
    divu x12, x10, x11
    remu x13, x10, x11
    sw   x12, 16(x5)
    sw   x13, 20(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS
