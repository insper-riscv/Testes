// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_test.h"

// Estrutura com campos de alinhamento crescente misturados: o ABI do RISC-V
// insere preenchimento entre eles.
typedef struct {
    uint8_t a;
    uint16_t b;
    uint32_t c;
    uint8_t d;
} greater_t;

// Os mesmos tipos ordenados do maior para o menor, que só precisam de preenchimento no fim.
typedef struct {
    uint32_t a;
    uint16_t b;
    uint8_t c;
    uint8_t d;
} lesser_t;

// Confere os tamanhos das duas estruturas. O layout é não especificado pela norma (ISO/IEC
// 9899:2024, 6.7.3.2 e 6.2.6.1), então o teste mede o ABI do RISC-V: 8 bytes para lesser_t e 12
// para greater_t.
int main(void) {
    volatile uint32_t size_lesser = sizeof(lesser_t);
    volatile uint32_t size_greater = sizeof(greater_t);

    if (size_lesser != 8 || size_greater != 12) RV32_FAIL(1);

    RV32_PASS();
}
