// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// Cópias entre a RAM e a SDRAM, por palavra e por byte, nos dois sentidos.

// Número de palavras copiadas.
static constexpr uint32_t WORDS = 256;

// Origem das cópias, na RAM.
static uint32_t src[WORDS];
// Destino das cópias, na RAM.
static uint32_t dst[WORDS];

// Faz as três cópias e confere o resultado de cada uma.
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;
    // acesso por byte: unsigned char pode ser alias de qualquer objeto (ISO/IEC 9899:2024, 6.5.1)
    volatile unsigned char *mb = (volatile unsigned char *)RV32_SDRAM;

    for (uint32_t i = 0; i < WORDS; i++) src[i] = rv32_sdram_data(i);

    // RAM para SDRAM por palavra, SDRAM para RAM por palavra
    for (uint32_t i = 0; i < WORDS; i++) m[i] = src[i];
    for (uint32_t i = 0; i < WORDS; i++) dst[i] = m[i];
    for (uint32_t i = 0; i < WORDS; i++) {
        if (dst[i] != src[i]) RV32_FAIL(1);
    }

    // RAM para SDRAM por byte, SDRAM para RAM por palavra
    volatile unsigned char *sb = (volatile unsigned char *)src;
    for (uint32_t i = 0; i < WORDS * 4; i++) mb[4096 + i] = sb[i];
    for (uint32_t i = 0; i < WORDS; i++) dst[i] = m[1024 + i];
    for (uint32_t i = 0; i < WORDS; i++) {
        if (dst[i] != src[i]) RV32_FAIL(2);
    }

    // SDRAM para SDRAM, cruzando o limite de uma linha do chip (512 palavras por linha)
    for (uint32_t i = 0; i < WORDS; i++) m[400 + i] = m[i];
    for (uint32_t i = 0; i < WORDS; i++) {
        if (m[400 + i] != src[i]) RV32_FAIL(3);
    }

    RV32_PASS();
}
