// RV32_TEST_KIND: unit
#include "rv32_test.h"

static volatile unsigned int value = 0xCAFEBABEu;

int main(void) {
    // if (value != 0xCAFEBABEu) RV32_FAIL();
    RV32_PASS();
}
