// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_test.h"

// Tabela de consulta em .rodata, lida por índice.
static const int32_t lut[8] = {10, 20, 30, 42, 50, 60, 70, 80};

// Soma a tabela inteira e confere a soma e o quarto elemento.
int main(void) {
    volatile int32_t sum = 0;
    for (uint32_t i = 0; i < 8; i++) sum += lut[i];
    if (sum != 362) RV32_FAIL(1);
    if (lut[3] != 42) RV32_FAIL(2);
    RV32_PASS();
}
