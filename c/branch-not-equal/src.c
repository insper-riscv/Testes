// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Desvia quando dois operandos voláteis diferem e guarda 1 nesse caso.
int main(void) {
    volatile int32_t a = 42;
    volatile int32_t b = 7;
    results[0] = (a != b) ? 1 : 0;
    RV32_PASS();
}
