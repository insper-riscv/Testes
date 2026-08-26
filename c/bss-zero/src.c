// RV32_TEST_KIND: unit
#include "rv32_test.h"

static volatile unsigned int value;

int main(void) {
    if (value != 0u) RV32_FAIL();
    RV32_PASS();
}
