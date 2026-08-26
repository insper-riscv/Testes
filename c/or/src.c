// RV32_TEST_KIND: unit
#include "rv32_test.h"

int main(void) {
    volatile unsigned int a = 0x55AA00FFu;
    volatile unsigned int b = 0x0F0FF0F0u;
    if ((a | b) != 0x5FAFF0FFu) RV32_FAIL();
    RV32_PASS();
}
