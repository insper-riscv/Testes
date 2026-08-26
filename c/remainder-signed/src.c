// RV32_EXT: M
// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int a = -100;
    volatile int b = 9;
    if (a % b != -1) RV32_FAIL();
    RV32_PASS();
}
