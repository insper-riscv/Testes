// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// A SDRAM guarda o conteúdo enquanto o barramento fica ocioso por muitos períodos de refresh (o controlador
// faz o refresh sozinho); lido de volta depois de uma espera longa.

// Escreve uma palavra por linha do chip, espera bem mais que um período de refresh e confere as palavras.
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;

    for (uint32_t i = 0; i < 256; i++) m[i * 512] = rv32_sdram_data(i);   // uma palavra por linha

    // muito mais que um período de refresh (7,8 us); t vive na SDRAM, então cada passada custa dezenas de ciclos
    for (volatile uint32_t t = 0; t < 1000; t++) { }

    for (uint32_t i = 0; i < 256; i++) {
        if (m[i * 512] != rv32_sdram_data(i)) RV32_FAIL(1);
    }

    RV32_PASS();
}
