// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Armazena uma palavra em results para o Spike conferir.
int main(void) {
    results[0] = 0x89ABCDEFu;
    RV32_PASS();
}
