// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Diagnostica a inicialização de um objeto de um byte em .data.
// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint8_t results[1] = {0xA5u};

// Só encerra o teste: o valor inicializado em .data é o que o Spike confere.
int main(void) {
    RV32_PASS();
}
