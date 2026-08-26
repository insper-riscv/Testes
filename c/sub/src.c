// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int a = 37;
    volatile int b = 12;
    if (a - b != 25) RV32_FAIL();
    RV32_PASS();
}
