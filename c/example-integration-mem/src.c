// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Chegar a RV32_PASS() só prova que o programa não travou: o golden.json (gerado do Spike na
// compilação, veja docs/creating-a-c-test.md) é que confere se os valores chegaram à memória.
// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[4];

// Escreve o padrão 1, 2, 3, 4 em results.
int main(void) {
    for (uint32_t i = 0; i < 4; i++) {
        results[i] = i + 1u;
    }
    RV32_PASS();
    return 0;
}
