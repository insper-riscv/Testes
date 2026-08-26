// RV32_TEST_KIND: unit
#include "rv32_test.h"

/* Diagnoses initialization of a one-byte .data object. */
static volatile unsigned char value = 0xA5u;

int main(void) {
    if (value != 0xA5u) RV32_FAIL();
    RV32_PASS();
}
