// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile int results[1];

int main(void) {
    volatile int value = -16;
    volatile unsigned int amount = 4u;
    results[0] = value >> amount;
    RV32_PASS();
}
