// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile int results[1];

int main(void) {
    volatile int a = 37;
    volatile int b = 12;
    results[0] = a + b;
    RV32_PASS();
}
