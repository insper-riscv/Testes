// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int negative = -3;
    volatile int positive = 7;
    if (!(negative < positive)) RV32_FAIL();
    RV32_PASS();
}
