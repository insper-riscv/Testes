// RV32_EXT: M
#include "rv32_test.h"

int main(void) {
    int a = 6, b = 7;
    if (a * b == 42) {
        RV32_PASS();
    }
    RV32_FAIL();
    return 0;
}
