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

// O buffer de stdout é linear e tem 1024 bytes (platform/stdio.c): escrever além disso o enche,
// descarta o resto e liga o sinalizador de truncamento.
int main(void) {
    const struct stdout_buffer *out = STDOUT_BUFFER;

    for (uint32_t i = 0; i < 1024; i++) putchar('a');
    if (out->length != 1024 || out->truncated != 0) RV32_FAIL(1);

    putchar('b');
    if (out->length != 1024 || out->truncated != 1) RV32_FAIL(2);
    if (out->data[0] != 'a' || out->data[1023] != 'a') RV32_FAIL(3);
    RV32_PASS();
}
