// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// Os testes clássicos de memória sobre a SDRAM: o barramento de dados, o de endereços e uma janela. Usam a
// janela de teste de rv32_sdram.h, longe dos dados do próprio programa e da pilha.

// Roda os quatro testes em sequência e falha com o número do primeiro que não passa.
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;

    // barramento de dados: um bit 1 e um bit 0 caminhando na mesma palavra
    for (uint32_t b = 0; b < 32; b++) {
        m[0] = 1u << b;
        if (m[0] != (1u << b)) RV32_FAIL(1);
        m[0] = ~(1u << b);
        if (m[0] != ~(1u << b)) RV32_FAIL(2);
    }

    // barramento de endereços: uma palavra em cada deslocamento de potência de dois (e no deslocamento 0) que
    // fica dentro da RAM, longe da pilha e das palavras do host (8 KiB abaixo do fim dela), todas escritas antes
    // de qualquer leitura, de modo que uma linha de endereço presa ou trocada põe um valor em outra palavra
    uint32_t bits = 0;
    while (bits < 24 && RV32_SDRAM_TEST_BASE + (4u << bits) <= RV32_RAM_END - 0x2000u) bits++;
    for (uint32_t k = 0; k < bits; k++) m[1u << k] = 0xA0000000u | k;
    m[0] = 0xDEADBEEFu;
    for (uint32_t k = 0; k < bits; k++) {
        if (m[1u << k] != (0xA0000000u | k)) RV32_FAIL(3);
    }
    if (m[0] != 0xDEADBEEFu) RV32_FAIL(4);

    // uma janela de palavras com dados que dependem do endereço (elas cruzam linhas e bancos)
    for (uint32_t i = 0; i < 4096; i++) m[i + 8] = rv32_sdram_data(i);
    for (uint32_t i = 0; i < 4096; i++) {
        if (m[i + 8] != rv32_sdram_data(i)) RV32_FAIL(5);
    }

    // a última palavra da janela de teste
    m[RV32_SDRAM_TEST_WORDS - 1] = 0x600DF00Du;
    if (m[RV32_SDRAM_TEST_WORDS - 1] != 0x600DF00Du) RV32_FAIL(6);

    RV32_PASS();
}
