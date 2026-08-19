// RV32_TEST_KIND: integration
#include "rv32_test.h"

// Writes a small pattern to the start of RAM. Unlike a unit test,
// reaching RV32_PASS() only proves the program didn't crash — the
// golden JSON at tests/c/real/golden/example_integration_mem.json is
// what actually checks the values landed in memory correctly.
static volatile unsigned int *const BUF = (volatile unsigned int *)0x00000000;

int main(void) {
    for (int i = 0; i < 4; i++) {
        BUF[i] = 0x11111111u * (unsigned int)(i + 1);
    }
    RV32_PASS();
    return 0;
}
