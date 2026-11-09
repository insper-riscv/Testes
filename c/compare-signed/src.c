// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Compara dois operandos com sinal (-3 e 7) e guarda 1 se o primeiro é menor.
int main(void) {
    volatile int32_t negative = -3;
    volatile int32_t positive = 7;
    results[0] = (negative < positive) ? 1 : 0;
    RV32_PASS();
}
