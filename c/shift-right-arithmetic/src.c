// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int value = -16;
    volatile unsigned int amount = 4u;
    if ((value >> amount) != -1) RV32_FAIL();
    RV32_PASS();
}
