// RV32_TEST_KIND: memory
#include "rv32_test.h"

// Checked against Spike (the RISC-V Foundation reference model) at
// compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile unsigned int results[1];

int main(void) {
    volatile unsigned int a = 0x55AA00FFu;
    volatile unsigned int b = 0x0F0FF0F0u;
    results[0] = a & b;
    RV32_PASS();
}
