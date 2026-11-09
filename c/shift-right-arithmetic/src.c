// RV32_TEST_KIND: memory
#include <stdint.h>

#include "rv32_test.h"

// Conferido contra o Spike (modelo de referência da RISC-V Foundation) na compilação,
// não contra um literal calculado à mão; veja docs/creating-a-c-test.md.
volatile int32_t results[1];

// Desloca um operando negativo (-16) para a direita por uma contagem volátil menor que 32.
// O resultado de >> sobre valor negativo é definido pela implementação (ISO/IEC 9899:2024,
// 6.5.8); o GCC o documenta como deslocamento aritmético, que é a instrução sra do RISC-V e
// o que este teste mede. Reescrever sem >> (por exemplo, por divisão) deixaria de exercitar
// a sra, então a forma foi mantida de propósito.
int main(void) {
    volatile int32_t value = -16;
    volatile uint32_t amount = 4u;
    results[0] = value >> amount;
    RV32_PASS();
}
