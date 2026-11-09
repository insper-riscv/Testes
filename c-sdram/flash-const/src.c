// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// Constantes lidas da FLASH, que é um chip atrás das caches: leituras alinhadas e desalinhadas de uma tabela na
// FLASH, uma segunda passada depois que o tráfego da SDRAM despejou as linhas, e uma escrita na FLASH que o chip
// ignora (a tabela deve manter o valor, esteja ou não a sua linha na cache).
//
// Duas operações aqui não têm definição na norma, e o teste existe justamente para medi-las no hardware, então
// cada uma é feita por uma instrução explícita em __asm__ volatile, fora da máquina abstrata, em vez de por
// uma expressão em C:
//   1. o acesso desalinhado a uma palavra (ISO/IEC 9899:2024, 6.3.3.3 não define o ponteiro desalinhado), que
//      mede a extensão Zicclsm: lw_misaligned executa uma instrução lw num endereço que não é múltiplo de 4;
//   2. a escrita num objeto definido const (6.7.4.1 a torna indefinida em C), que mede o chip: sw_flash executa
//      uma instrução sw sobre a FLASH, que a ignora, de modo que o objeto const nunca muda de fato. As leituras
//      de conferência passam por ponteiro volatile, para que o compilador não as troque pela constante.

// Tabela de 64 palavras guardada na FLASH (.rodata).
static const uint32_t table[64] = {
    0x00000000u, 0x11111111u, 0x22222222u, 0x33333333u, 0x44444444u, 0x55555555u, 0x66666666u, 0x77777777u,
    0x88888888u, 0x99999999u, 0xAAAAAAAAu, 0xBBBBBBBBu, 0xCCCCCCCCu, 0xDDDDDDDDu, 0xEEEEEEEEu, 0xFFFFFFFFu,
    0x01234567u, 0x89ABCDEFu, 0xFEDCBA98u, 0x76543210u, 0x0F1E2D3Cu, 0x4B5A6978u, 0xA1B2C3D4u, 0xE5F60718u,
    0xDEADBEEFu, 0xCAFEBABEu, 0x8BADF00Du, 0xFEEDFACEu, 0x0BADC0DEu, 0xC0FFEE00u, 0xABCDEF01u, 0x10FEDCBAu,
    0x13579BDFu, 0x2468ACE0u, 0x00FF00FFu, 0xFF00FF00u, 0x0000FFFFu, 0xFFFF0000u, 0x12345678u, 0x87654321u,
    0x5A5A5A5Au, 0xA5A5A5A5u, 0x3C3C3C3Cu, 0xC3C3C3C3u, 0x0F0F0F0Fu, 0xF0F0F0F0u, 0x01010101u, 0x80808080u,
    0x11223344u, 0x55667788u, 0x99AABBCCu, 0xDDEEFF00u, 0x00000001u, 0x00000002u, 0x00000004u, 0x00000008u,
    0x00000010u, 0x00000020u, 0x00000040u, 0x00000080u, 0x00000100u, 0x00000200u, 0x00000400u, 0x00000800u,
};

// Lê uma palavra num endereço qualquer com a instrução lw; o endereço pode ser desalinhado (Zicclsm).
static inline uint32_t lw_misaligned(uintptr_t address) {
    uint32_t value;
    __asm__ volatile("lw %0, 0(%1)" : "=r"(value) : "r"(address) : "memory");
    return value;
}

// Escreve uma palavra num endereço da FLASH com a instrução sw; o chip ignora a escrita.
static inline void sw_flash(uintptr_t address, uint32_t value) {
    __asm__ volatile("sw %1, 0(%0)" : : "r"(address), "r"(value) : "memory");
}

// Lê uma palavra alinhada da FLASH por um ponteiro volatile, sempre do chip ou da cache.
static inline uint32_t read_flash(uintptr_t address) {
    return *(const volatile uint32_t *)address;
}

// Soma de verificação das palavras da tabela, lidas como palavras.
static uint32_t checksum(void) {
    uint32_t x = 0;
    for (uint32_t i = 0; i < 64; i++) x = (x << 1 | x >> 31) ^ table[i];
    return x;
}

// Soma de verificação dos bytes da tabela, lidos como bytes (unsigned char pode ser alias de qualquer
// objeto, ISO/IEC 9899:2024, 6.5.1).
static uint32_t checksum_bytes(void) {
    const volatile unsigned char *p = (const volatile unsigned char *)table;
    uint32_t x = 0;
    for (uint32_t i = 0; i < sizeof(table); i++) x = (x << 3 | x >> 29) ^ p[i];
    return x;
}

// Executa as leituras alinhadas e desalinhadas, a passada depois do despejo da cache e a escrita ignorada.
int main(void) {
    uint32_t first = checksum();
    uint32_t first_bytes = checksum_bytes();
    // duas vezes seguidas: a segunda passada acerta a cache de dados
    if (checksum() != first) RV32_FAIL(1);
    if (checksum_bytes() != first_bytes) RV32_FAIL(2);

    // leituras desalinhadas atravessando duas palavras da FLASH (Zicclsm)
    const volatile unsigned char *p = (const volatile unsigned char *)table;
    for (uint32_t i = 1; i < 4; i++) {
        uint32_t want = (uint32_t)p[4 + i] | (uint32_t)p[5 + i] << 8 |
                        (uint32_t)p[6 + i] << 16 | (uint32_t)p[7 + i] << 24;
        if (lw_misaligned((uintptr_t)(p + 4 + i)) != want) RV32_FAIL(3);
    }

    // despeja a cache de dados com 16 KB de tráfego da SDRAM e lê a tabela de novo
    volatile uint32_t *sweep = (volatile uint32_t *)(RV32_RAM_BASE + 0x00800000u);
    for (uint32_t i = 0; i < 4096; i++) sweep[i] = i;
    uint32_t sum = 0;
    for (uint32_t i = 0; i < 4096; i++) sum += sweep[i];
    if (sum != 4096u * 4095u / 2u) RV32_FAIL(4);
    if (checksum() != first) RV32_FAIL(5);

    // uma escrita na FLASH é ignorada, numa linha que está na cache e numa que não está
    const uintptr_t flash = (uintptr_t)&table[3];
    uint32_t before = read_flash(flash);                 // traz a linha
    sw_flash(flash, 0xFFFFFFFFu);
    if (read_flash(flash) != before) RV32_FAIL(6);
    const uintptr_t far_word = (uintptr_t)&table[60];
    uint32_t before_far = read_flash(far_word);
    sw_flash(far_word, 0u);
    if (read_flash(far_word) != before_far) RV32_FAIL(7);
    for (uint32_t i = 0; i < 4096; i++) sweep[i] = ~i;   // despeja
    if (read_flash(flash) != before || read_flash(far_word) != before_far) RV32_FAIL(8);
    if (checksum() != first) RV32_FAIL(9);

    RV32_PASS();
}
