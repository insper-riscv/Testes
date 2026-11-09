// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Complementa bit a bit um operando volátil e guarda o resultado.
int main(void) {
    volatile uint32_t value = 0x55AA00FFu;
    results[0] = ~value;
    RV32_PASS();
}
