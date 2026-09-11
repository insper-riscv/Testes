// RV32_TEST_KIND: unit
#include "rv32_test.h"

static const int lut[8] = {10, 20, 30, 42, 50, 60, 70, 80};

int main(void) {
    volatile int sum = 0;
    for (int i = 0; i < 8; i++) sum += lut[i];
    if (sum != 362) RV32_FAIL();
    if (lut[3] != 42) RV32_FAIL();
    RV32_PASS();
}
