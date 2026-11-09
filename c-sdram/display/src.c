// RV32_EXT: M
// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// O programa aciona o registrador do display de sete segmentos (0xD0000000): mostra 000001 a 00000F, um
// depois do outro com uma pausa curta, depois 123456, e lê o registrador de volta a cada vez. A leitura de
// volta é a conferência, e HEX5 a HEX0 ficam mostrando 123456. Para olhar os dígitos um a um, use o
// monitor: `poke D0000000 000003`.

// Registrador do display. Fica como macro porque um ponteiro para endereço fixo não pode ser constexpr
// (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo); o acesso é volatile (6.7.4.1) e alinhado a palavra.
#define DISPLAY ((volatile uint32_t *)0xD0000000u)

// Iterações do laço de pausa entre dois valores.
static constexpr uint32_t PAUSE_ITERATIONS = 100u;
// Valor final deixado no display.
static constexpr uint32_t FINAL_VALUE = 0x123456u;

// Espera um tempo curto com um laço volátil.
static void pause(void) {
    for (volatile uint32_t i = 0; i < PAUSE_ITERATIONS; i++) {
    }
}

// Escreve cada valor de 1 a 15 no display, confere a leitura de volta, e termina com 123456.
int main(void) {
    for (uint32_t value = 1; value <= 0xF; value++) {
        *DISPLAY = value;
        if (*DISPLAY != value) RV32_FAIL(1);
        pause();
    }
    *DISPLAY = FINAL_VALUE;
    if (*DISPLAY != FINAL_VALUE) RV32_FAIL(2);
    pause();
    RV32_PASS();
}
