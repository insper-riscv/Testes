// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// Laços sobre a SDRAM: uma leitura seguida de um desvio para trás, a forma que exige que o pipeline mantenha
// um desvio tomado enquanto o estágio de memória espera.

// Executa os laços de soma, de leitura reversa com saída antecipada e aninhado, e confere cada resultado.
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;
    uint32_t want = 0;

    for (uint32_t i = 0; i < 512; i++) {
        m[i] = i ^ 0x5555u;
        want += i ^ 0x5555u;
    }

    uint32_t sum = 0;
    uint32_t i = 0;
    while (i < 512) {                 // lw, add, addi, bne
        sum += m[i];
        i++;
    }
    if (sum != want) RV32_FAIL(1);

    // lê a partir do fim, com uma saída antecipada que depende do valor lido
    uint32_t n = 0;
    for (int32_t j = 511; j >= 0; j--) {
        if (m[j] == (0u ^ 0x5555u)) break;      // m[0]
        n++;
    }
    if (n != 511) RV32_FAIL(2);

    // aninhado: uma fileira de leituras dentro de um laço externo que também escreve
    for (uint32_t r = 0; r < 8; r++) {
        for (uint32_t c = 0; c < 16; c++) m[1024 + r * 16 + c] = r + c;
    }
    uint32_t tot = 0;
    for (uint32_t r = 0; r < 8; r++) {
        for (uint32_t c = 0; c < 16; c++) {
            if (m[1024 + r * 16 + c] != r + c) RV32_FAIL(3);
            tot += m[1024 + r * 16 + c];
        }
    }
    if (tot != 1408) RV32_FAIL(4);        // 16 * (0+1+...+7) + 8 * (0+1+...+15)

    RV32_PASS();
}
