// RV32_TEST_KIND: unit
#include "rv32_test.h"

/* Diagnoses initialization of one naturally aligned .data word. */
static volatile unsigned int value = 0xCAFEBABEu;

int main(void) {
    if (value != 0xCAFEBABEu) RV32_FAIL();
    RV32_PASS();
}
