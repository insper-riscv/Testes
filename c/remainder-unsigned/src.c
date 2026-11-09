// RV32_EXT: M
// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Calcula o resto da divisão de dois operandos sem sinal (100 por 9) e guarda o resto.
int main(void) {
    volatile uint32_t a = 100u;
    volatile uint32_t b = 9u;
    results[0] = a % b;
    RV32_PASS();
}
