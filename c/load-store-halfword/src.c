// RV32_TEST_KIND: unit
#include "rv32_test.h"

static volatile unsigned short value;

int main(void) {
    value = 0xFEDCu;
    if (value != 0xFEDCu) RV32_FAIL();
    RV32_PASS();
}
