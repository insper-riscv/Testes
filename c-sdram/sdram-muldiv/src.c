// RV32_EXT: M
// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// Multiplicações e divisões cujos operandos vêm da SDRAM: o pipeline para no multiplicador ou no divisor
// enquanto o estágio de memória pode estar esperando a SDRAM, e o contrário. A mesma aritmética com
// operandos na RAM é a referência.

// Número de iterações dos laços.
static constexpr uint32_t N = 64;

// Operandos de referência, na RAM.
static uint32_t ref_a[N + 2];

// Calcula a soma de referência na RAM, repete com operandos da SDRAM e compara; depois confere uma escrita
// logo após uma multiplicação.
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;

    for (uint32_t i = 0; i < N + 2; i++) {
        ref_a[i] = i + 3;
        m[i] = i + 3;
    }

    uint32_t want = 0;
    for (uint32_t i = 0; i < N; i++) {
        want += ref_a[i] * ref_a[i + 1];
        want += (ref_a[i] * 7u + 1u) / ref_a[i + 1];
        want += (ref_a[i + 2] * 13u) % ref_a[i + 1];
    }

    uint32_t sum = 0;
    for (uint32_t i = 0; i < N; i++) {
        sum += m[i] * m[i + 1];                    // mul entre duas leituras da SDRAM
        sum += (m[i] * 7u + 1u) / m[i + 1];        // div cujo divisor é lido em seguida
        sum += (m[i + 2] * 13u) % m[i + 1];        // rem logo após uma leitura
    }
    if (sum != want) RV32_FAIL(1);

    // uma escrita logo após uma multiplicação, na SDRAM, e depois a leitura de volta
    for (uint32_t i = 0; i < N; i++) m[256 + i] = ref_a[i] * ref_a[i];
    for (uint32_t i = 0; i < N; i++) {
        if (m[256 + i] != ref_a[i] * ref_a[i]) RV32_FAIL(2);
    }

    RV32_PASS();
}
