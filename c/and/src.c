// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Aplica E bit a bit a dois operandos voláteis e guarda o resultado.
int main(void) {
    volatile uint32_t a = 0x55AA00FFu;
    volatile uint32_t b = 0x0F0FF0F0u;
    results[0] = a & b;
    RV32_PASS();
}
