// RV32_EXT: M
// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Calcula o resto da divisão de dois operandos com sinal (-100 por 9) e guarda o resto.
int main(void) {
    volatile int32_t a = -100;
    volatile int32_t b = 9;
    results[0] = a % b;
    RV32_PASS();
}
