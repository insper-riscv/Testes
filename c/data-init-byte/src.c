// RV32_TEST_KIND: memory
#include "rv32_test.h"

/* Diagnoses initialization of a one-byte .data object. Checked
 * against Spike (the RISC-V Foundation reference model) at compile
 * time, not a hand-computed literal — see docs/creating-a-c-test.md. */
volatile unsigned char results[1] = {0xA5u};

int main(void) {
    RV32_PASS();
}
