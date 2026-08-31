// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Writes a small pattern into RAM. Unlike a unit test, reaching
// RV32_PASS() only proves the program didn't crash — the golden JSON
// at tests/c/real/golden/example_integration_mem.json is what
// actually checks the values landed in memory correctly.
//
// Address 0x00010010, not 0x10: RAM starts at 0x00010000 now (Harvard
// modificado) — 0x10 alone would land in ROM, which this core can
// never write to (see docs/DATA_HARVARD_BUG.md), silently dropping
// every write below instead of faulting. +0x10, not +0x00: (volatile
// unsigned int *)RAM_BASE is still adjacent to how GCC treats a
// literal null pointer close enough to trip the same "unreachable UB"
// assumption in some codegen paths — confirmed via objdump that a
// nonzero low offset avoids it.
static volatile unsigned int *const BUF = (volatile unsigned int *)0x00010010;

int main(void) {
    for (int i = 0; i < 4; i++) {
        BUF[i] = i + 1;
    }
    RV32_PASS();
    return 0;
}
