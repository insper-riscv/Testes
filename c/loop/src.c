// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile int limit = 10;
    int sum = 0;
    for (int i = 1; i <= limit; i++) sum += i;
    if (sum != 55) RV32_FAIL();
    RV32_PASS();
}
