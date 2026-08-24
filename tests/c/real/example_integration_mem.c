// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Writes a small pattern into RAM. Unlike a unit test, reaching
// RV32_PASS() only proves the program didn't crash — the golden JSON
// at tests/c/real/golden/example_integration_mem.json is what
// actually checks the values landed in memory correctly.
//
// Address 0x10, not 0x00: (volatile unsigned int *)0x0 is still the
// null pointer as far as the C standard is concerned, volatile or
// not — GCC is allowed to (and does, confirmed via objdump) assume
// writing through it is unreachable UB and optimize the whole
// function away, down to a single `sw zero,0(zero)` + `ebreak`.
static volatile unsigned int *const BUF = (volatile unsigned int *)0x00000010;

int main(void) {
    for (int i = 0; i < 4; i++) {
        BUF[i] = 0x11111111u * (unsigned int)(i + 1);
    }
    RV32_PASS();
    return 0;
}
