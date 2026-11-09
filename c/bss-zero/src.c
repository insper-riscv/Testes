// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Sem inicializador, o objeto vai para .bss e o laço de zeragem do crt0.S o limpa antes de main().
// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile uint32_t results[1];

// Só encerra o teste: a zeragem de .bss é o que o Spike confere.
int main(void) {
    RV32_PASS();
}
