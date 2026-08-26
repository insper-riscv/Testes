// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile unsigned int value = 0x80000001u;
    volatile unsigned int amount = 4u;
    if ((value << amount) != 0x00000010u) RV32_FAIL();
    RV32_PASS();
}
