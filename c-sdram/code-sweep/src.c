// RV32_TEST_KIND: unit
#include "rv32_test.h"

// Code larger than the 4 KB instruction cache, run several times: 16 KB of straight-line instructions,
// each pass evicts the lines the previous pass filled, and the result must be the same every time.

#define I1 "addi %0, %0, 1\n\t"
#define I4 I1 I1 I1 I1
#define I16 I4 I4 I4 I4
#define I64 I16 I16 I16 I16
#define I256 I64 I64 I64 I64
#define I1024 I256 I256 I256 I256

__attribute__((noinline)) static unsigned int run(unsigned int x) {
    __asm__ volatile (I1024 I1024 I1024 I1024 : "+r"(x));
    return x;
}

int main(void) {
    unsigned int x = 0;
    for (unsigned int pass = 1; pass <= 4; pass++) {
        x = run(x);
        if (x != pass * 4096u) RV32_FAIL(pass);
    }
    RV32_PASS();
}
