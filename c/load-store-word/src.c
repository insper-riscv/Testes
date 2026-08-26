// RV32_TEST_KIND: unit
#include "rv32_test.h"

static volatile unsigned int value;

int main(void) {
    value = 0x89ABCDEFu;
    if (value != 0x89ABCDEFu) RV32_FAIL();
    RV32_PASS();
}
