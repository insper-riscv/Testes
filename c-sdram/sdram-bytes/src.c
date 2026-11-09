// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_sdram.h"
#include "rv32_test.h"

// Acessos de byte e de meia palavra à SDRAM: as escritas tocam só os seus bytes (a máscara de bytes vai ao
// chip), as leituras estendem com e sem sinal.
//
// Os bytes passam por ponteiros de tipo caractere, que podem ser alias de qualquer objeto (ISO/IEC
// 9899:2024, 6.5.1). A norma não tem tipo de meia palavra com essa permissão, então as meias palavras passam
// por instruções explícitas (lhu, lh, sh) em __asm__ volatile: o teste mede exatamente essas instruções no
// barramento, e o asm evita ler como uint16_t um dado escrito como uint32_t.

// Lê uma meia palavra sem sinal do endereço, com a instrução lhu.
static inline uint16_t load_half(uintptr_t address) {
    uint32_t value;
    __asm__ volatile("lhu %0, 0(%1)" : "=r"(value) : "r"(address) : "memory");
    return (uint16_t)value;
}

// Lê uma meia palavra com sinal do endereço, com a instrução lh.
static inline int16_t load_half_signed(uintptr_t address) {
    int32_t value;
    __asm__ volatile("lh %0, 0(%1)" : "=r"(value) : "r"(address) : "memory");
    return (int16_t)value;
}

// Escreve uma meia palavra no endereço, com a instrução sh.
static inline void store_half(uintptr_t address, uint16_t value) {
    __asm__ volatile("sh %1, 0(%0)" : : "r"(address), "r"((uint32_t)value) : "memory");
}

// Confere os acessos de byte e de meia palavra e a extensão de sinal.
int main(void) {
    volatile uint32_t *w = RV32_SDRAM;
    volatile unsigned char *b = (volatile unsigned char *)RV32_SDRAM;
    volatile signed char *bs = (volatile signed char *)RV32_SDRAM;
    const uintptr_t base = RV32_SDRAM_TEST_BASE;

    w[0] = 0x11223344u;
    if (b[0] != 0x44 || b[1] != 0x33 || b[2] != 0x22 || b[3] != 0x11) RV32_FAIL(1);
    if (load_half(base) != 0x3344 || load_half(base + 2) != 0x1122) RV32_FAIL(2);

    b[1] = 0xAA;
    if (w[0] != 0x1122AA44u) RV32_FAIL(3);
    store_half(base + 2, 0xBEEF);
    if (w[0] != 0xBEEFAA44u) RV32_FAIL(4);
    b[3] = 0x01;
    b[0] = 0x80;
    if (w[0] != 0x01EFAA80u) RV32_FAIL(5);

    // extensão de sinal
    if (bs[0] != -128) RV32_FAIL(6);
    if (b[0] != 128) RV32_FAIL(7);
    w[1] = 0x0000F00Fu;
    if (load_half_signed(base + 4) != -4081) RV32_FAIL(8);
    if (load_half(base + 4) != 0xF00F) RV32_FAIL(9);

    // cada faixa de byte de palavras consecutivas, e uma escrita ao lado de uma palavra que não pode mudar
    for (uint32_t i = 0; i < 64; i++) w[16 + i] = 0xFFFFFFFFu;
    for (uint32_t i = 0; i < 64; i++) b[64 + i * 4 + (i & 3)] = (unsigned char)i;
    for (uint32_t i = 0; i < 64; i++) {
        uint32_t want = 0xFFFFFFFFu & ~(0xFFu << (8 * (i & 3)));
        want |= i << (8 * (i & 3));
        if (w[16 + i] != want) RV32_FAIL(10);
    }

    RV32_PASS();
}
