// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile int results[1];

int main(void) {
    volatile int negative = -3;
    volatile int positive = 7;
    results[0] = (negative < positive) ? 1 : 0;
    RV32_PASS();
}
