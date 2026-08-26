// RV32_TEST_KIND: unit
#include "rv32_test.h"

static volatile unsigned char value;

int main(void) {
    value = 0xA5u;
    if (value != 0xA5u) RV32_FAIL();
    RV32_PASS();
}
