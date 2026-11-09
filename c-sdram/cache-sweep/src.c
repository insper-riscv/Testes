// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// Varreduras maiores que a cache de dados de 4 KB, de modo que toda linha é despejada e preenchida de novo:
// escreve um padrão em 16 KB, lê de volta, reescreve com outro padrão e lê em passos que põem duas linhas no
// mesmo índice da cache. Uma palavra que a cache perde, mantém velha ou põe em outra linha aparece.

// Número de palavras varridas (16 KB).
static constexpr uint32_t WORDS = 4096u;

// Executa as quatro varreduras e falha com o número da primeira que não confere.
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;

    for (uint32_t i = 0; i < WORDS; i++) m[i] = rv32_sdram_data(i);
    for (uint32_t i = 0; i < WORDS; i++) {
        if (m[i] != rv32_sdram_data(i)) RV32_FAIL(1);
    }

    // reescreve uma palavra sim, outra não: escritas que acertam linhas da cache e escritas que erram, intercaladas
    for (uint32_t i = 0; i < WORDS; i += 2) m[i] = ~rv32_sdram_data(i);
    for (uint32_t i = 0; i < WORDS; i++) {
        uint32_t want = (i & 1u) ? rv32_sdram_data(i) : ~rv32_sdram_data(i);
        if (m[i] != want) RV32_FAIL(2);
    }

    // duas palavras a 4 KB de distância dividem um índice da cache: alterna entre elas
    for (uint32_t k = 0; k < 64; k++) {
        uint32_t a = k * 4u, b = a + 1024u;          // 1024 palavras = 4 KB
        m[a] = 0xA0000000u | k;
        m[b] = 0xB0000000u | k;
        if (m[a] != (0xA0000000u | k)) RV32_FAIL(3);
        if (m[b] != (0xB0000000u | k)) RV32_FAIL(4);
        if (m[a] != (0xA0000000u | k)) RV32_FAIL(5);
    }

    // escritas de byte em linhas que estão na cache (unsigned char pode ser alias de qualquer objeto,
    // ISO/IEC 9899:2024, 6.5.1)
    volatile unsigned char *bytes = (volatile unsigned char *)RV32_SDRAM;
    for (uint32_t i = 0; i < 256; i++) bytes[i] = (unsigned char)i;
    for (uint32_t i = 0; i < 256; i++) {
        if (bytes[i] != (unsigned char)i) RV32_FAIL(6);
    }

    RV32_PASS();
}
