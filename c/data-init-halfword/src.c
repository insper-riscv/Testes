// RV32_TEST_KIND: memory
#include "rv32_test.h"

/* Diagnoses initialization of a two-byte .data object. Checked
 * against Spike (the RISC-V Foundation reference model) at compile
 * time, not a hand-computed literal — see docs/creating-a-c-test.md. */
volatile unsigned short results[1] = {0xBEEFu};

int main(void) {
    RV32_PASS();
}
