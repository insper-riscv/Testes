// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint8_t results[1];

// Armazena um byte em results para o Spike conferir.
int main(void) {
    results[0] = 0xA5u;
    RV32_PASS();
}
