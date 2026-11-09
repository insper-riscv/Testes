// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Compara dois operandos sem sinal (0xFFFFFFFD e 7) e guarda 1 se o primeiro é maior.
int main(void) {
    volatile uint32_t high = 0xFFFFFFFDu;
    volatile uint32_t low = 7u;
    results[0] = (high > low) ? 1u : 0u;
    RV32_PASS();
}
