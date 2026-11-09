// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Soma dois operandos voláteis (37 e 12) e guarda a soma.
int main(void) {
    volatile int32_t a = 37;
    volatile int32_t b = 12;
    results[0] = a + b;
    RV32_PASS();
}
