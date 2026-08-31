// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile unsigned int results[1];

int main(void) {
    volatile unsigned int high = 0xFFFFFFFDu;
    volatile unsigned int low = 7u;
    results[0] = (high > low) ? 1u : 0u;
    RV32_PASS();
}
