// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Desloca um operando sem sinal para a esquerda por uma contagem volátil menor que 32 e guarda o resultado.
int main(void) {
    volatile uint32_t value = 0x80000001u;
    volatile uint32_t amount = 4u;
    results[0] = value << amount;
    RV32_PASS();
}
