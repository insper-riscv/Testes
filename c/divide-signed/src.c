// RV32_EXT: M
// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int a = -84;
    volatile int b = 7;
    if (a / b != -12) RV32_FAIL();
    RV32_PASS();
}
