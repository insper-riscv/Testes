// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Soma os inteiros de 1 até um limite volátil (10) num laço e guarda a soma.
int main(void) {
    volatile int32_t limit = 10;
    int32_t sum = 0;
    for (int32_t i = 1; i <= limit; i++) sum += i;
    results[0] = sum;
    RV32_PASS();
}
