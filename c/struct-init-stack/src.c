// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_test.h"

// Estrutura com campos de larguras e sinais distintos, para conferir o preenchimento e o acesso.
typedef struct {
    uint32_t a;
    int32_t b;
    uint16_t c;
    int16_t d;
    uint8_t e;
    int8_t f;
} test_t;

// Inicializa a estrutura na pilha por designadores, confere cada campo e o tamanho de 16 bytes.
int main(void) {
    test_t a = {
        .a = 32,
        .b = -32,
        .c = 16,
        .d = -16,
        .e = 8,
        .f = -8
    };

    if (
        a.a !=  32 ||
        a.b != -32 ||
        a.c !=  16 ||
        a.d != -16 ||
        a.e !=   8 ||
        a.f !=  -8
    ) RV32_FAIL(1);

    if (sizeof(test_t) != 16)
        RV32_FAIL(2);

    RV32_PASS();
}
