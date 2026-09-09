// RV32_TEST_KIND: memory
#include "rv32_test.h"

static volatile unsigned int *const BUF = (volatile unsigned int *)0x00000010;

static void recursive_fill(int i) {
    if (i < 0) {
        return;
    }
    BUF[i] = (unsigned int) (i + 1);
    recursive_fill(i - 1);
} 

int main(void) {
    recursive_fill(10);
    RV32_PASS();
    return 0;
}
