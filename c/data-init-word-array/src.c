// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Diagnostica a iteração sobre várias palavras no laço de cópia de .data.
// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[4] = {
    0x11223344u,
    0x55667788u,
    0x99AABBCCu,
    0xDDEEFF00u,
};

// Só encerra o teste: os valores inicializados em .data são o que o Spike confere.
int main(void) {
    RV32_PASS();
}
