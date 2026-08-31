// RV32_TEST_KIND: memory
#include "rv32_test.h"

/* Diagnoses iteration across multiple words in the .data copy loop.
 * Checked against Spike (the RISC-V Foundation reference model) at
 * compile time, not hand-computed literals — see
 * docs/creating-a-c-test.md. */
volatile unsigned int results[4] = {
    0x11223344u,
    0x55667788u,
    0x99AABBCCu,
    0xDDEEFF00u,
};

int main(void) {
    RV32_PASS();
}
