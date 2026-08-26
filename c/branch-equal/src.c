// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int a = 42;
    volatile int b = 42;
    if (a == b) RV32_PASS();
    RV32_FAIL();
}
