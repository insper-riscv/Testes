// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile unsigned short results[1];

int main(void) {
    results[0] = 0xFEDCu;
    RV32_PASS();
}
