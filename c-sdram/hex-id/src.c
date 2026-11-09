// RV32_EXT: M
// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// O programa nomeia os seis dígitos do display de sete segmentos (registrador 0xD0000000) para que cada um
// possa ser distinguido na placa. O dígito k é HEX<k>, com HEX0 à direita.
//
// A fase 1 acende um dígito por vez com um A, de HEX0 a HEX5, cerca de um segundo cada; os outros cinco
// dígitos mostram 0. A fase 2 escreve 543210, de modo que cada dígito mostra o seu próprio número, e o
// mantém por alguns segundos. O display fica mostrando 543210. As pausas são pensadas para uma pessoa, então
// o programa roda na placa com --only (não faz parte da suíte padrão).

// Registrador do display. Fica como macro porque um ponteiro para endereço fixo não pode ser constexpr
// (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo); o acesso é volatile (6.7.4.1) e alinhado a palavra.
#define DISPLAY ((volatile uint32_t *)0xD0000000u)

// Número de dígitos do display.
static constexpr uint32_t DIGITS = 6u;
// Bits de cada dígito no registrador.
static constexpr uint32_t BITS_PER_DIGIT = 4u;
// Valor de marca aceso na fase 1.
static constexpr uint32_t MARK = 0xAu;
// Valor final da fase 2.
static constexpr uint32_t FINAL_VALUE = 0x543210u;
// Iterações do laço de uma pausa.
static constexpr uint32_t PAUSE_ITERATIONS = 2000000u;
// Pausas seguidas que seguram o valor final.
static constexpr uint32_t HOLD_PAUSES = 3u;

// Espera cerca de um segundo com um laço volátil.
static void pause(void) {
    for (volatile uint32_t i = 0; i < PAUSE_ITERATIONS; i++) {
    }
}

// Escreve value no display e falha se a leitura de volta for diferente.
static void show(uint32_t value) {
    *DISPLAY = value;
    if (*DISPLAY != value) RV32_FAIL(1);
}

// Executa a fase 1 (um A por dígito) e a fase 2 (543210 mantido por algumas pausas).
int main(void) {
    for (uint32_t digit = 0; digit < DIGITS; digit++) {
        show(MARK << (digit * BITS_PER_DIGIT));
        pause();
    }
    show(FINAL_VALUE);
    for (uint32_t i = 0; i < HOLD_PAUSES; i++) pause();
    RV32_PASS();
}
