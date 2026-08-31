// RV32_TEST_KIND: memory
#include "rv32_test.h"

// No initializer -> .bss, zeroed by crt0.S's own zero loop before
// main() runs. Checked against Spike (the RISC-V Foundation reference
// model) at compile time, not a hand-computed literal — see
// docs/creating-a-c-test.md.
volatile unsigned int results[1];

int main(void) {
    RV32_PASS();
}
