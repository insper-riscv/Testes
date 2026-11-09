// RV32_EXT: M
// RV32_TEST_KIND: unit
#include <stdint.h>
#include <stdio.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// Layout do buffer de stdout de platform/stdio.c: um cabeçalho com o comprimento e o sinalizador de
// truncamento, depois os bytes.
struct stdout_buffer {
    volatile uint32_t length;
    volatile uint32_t truncated;
    volatile char data[1024];
};

// Endereço do buffer de stdout no topo da RAM. Fica como macro porque o ponteiro para um endereço fixo
// não pode ser constexpr (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo).
#define STDOUT_BUFFER ((const struct stdout_buffer *)RV32_STDOUT_BASE)

// As conversões de inteiro do printf (%d, %x), escritas no buffer de stdout na RAM (veja
// platform/stdio.c). Elas dividem pela base com um div logo antes de um rem: duas instruções de
// multiplicação/divisão seguidas, que o núcleo errava até insper-riscv/RV32IM#33 (veja
// asm/div-rem-back-to-back).
int main(void) {
    const struct stdout_buffer *out = STDOUT_BUFFER;
    const char expected[] = "42 -7 beef";

    printf("%d %d %x", 42, -7, 0xBEEF);

    if (out->length != sizeof(expected) - 1) RV32_FAIL(1);
    for (uint32_t i = 0; i < out->length; i++) {
        if (out->data[i] != expected[i]) RV32_FAIL(2);
    }
    RV32_PASS();
}
