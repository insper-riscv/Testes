// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile unsigned int high = 0xFFFFFFFDu;
    volatile unsigned int low = 7u;
    if (!(high > low)) RV32_FAIL();
    RV32_PASS();
}
