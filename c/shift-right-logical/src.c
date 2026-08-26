// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile unsigned int value = 0x80000000u;
    volatile unsigned int amount = 4u;
    if ((value >> amount) != 0x08000000u) RV32_FAIL();
    RV32_PASS();
}
