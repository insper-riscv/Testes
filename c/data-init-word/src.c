// RV32_TEST_KIND: memory
#include "rv32_test.h"

/* Diagnoses initialization of one naturally aligned .data word.
 * Checked against Spike (the RISC-V Foundation reference model) at
 * compile time, not a hand-computed literal — see
 * docs/creating-a-c-test.md. */
volatile unsigned int results[1] = {0xCAFEBABEu};

int main(void) {
    RV32_PASS();
}
