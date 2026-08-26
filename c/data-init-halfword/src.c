// RV32_TEST_KIND: unit
#include "rv32_test.h"

/* Diagnoses initialization of a two-byte .data object. */
static volatile unsigned short value = 0xBEEFu;

int main(void) {
    if (value != 0xBEEFu) RV32_FAIL();
    RV32_PASS();
}
