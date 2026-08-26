// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile unsigned int value = 0x55AA00FFu;
    if ((~value) != 0xAA55FF00u) RV32_FAIL();
    RV32_PASS();
}
