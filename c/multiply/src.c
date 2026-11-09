// RV32_EXT: M
// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Multiplica dois operandos voláteis (84 e 7) e guarda o produto.
int main(void) {
    volatile int32_t a = 84;
    volatile int32_t b = 7;
    results[0] = a * b;
    RV32_PASS();
}
