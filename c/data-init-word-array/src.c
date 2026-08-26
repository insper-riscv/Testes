// RV32_TEST_KIND: unit
#include "rv32_test.h"

/* Diagnoses iteration across multiple words in the .data copy loop. */
static volatile unsigned int values[4] = {
    0x11223344u,
    0x55667788u,
    0x99AABBCCu,
    0xDDEEFF00u,
};

int main(void) {
    if (values[0] != 0x11223344u) RV32_FAIL();
    if (values[1] != 0x55667788u) RV32_FAIL();
    if (values[2] != 0x99AABBCCu) RV32_FAIL();
    if (values[3] != 0xDDEEFF00u) RV32_FAIL();
    RV32_PASS();
}
