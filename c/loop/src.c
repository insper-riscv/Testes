// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile int results[1];

int main(void) {
    volatile int limit = 10;
    int sum = 0;
    for (int i = 1; i <= limit; i++) sum += i;
    results[0] = sum;
    RV32_PASS();
}
