// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Writes a small pattern into RAM. Unlike a unit test, reaching
// RV32_PASS() only proves the program didn't crash — golden.json
// (generated fresh from Spike at compile time — see
// docs/creating-a-c-test.md) is what actually checks the values
// landed in memory correctly.
volatile unsigned int results[4];

int main(void) {
    for (int i = 0; i < 4; i++) {
        results[i] = i + 1;
    }
    RV32_PASS();
    return 0;
}
