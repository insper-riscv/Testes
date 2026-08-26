// RV32_EXT: M
// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile unsigned int a = 100u;
    volatile unsigned int b = 9u;
    if (a % b != 1u) RV32_FAIL();
    RV32_PASS();
}
