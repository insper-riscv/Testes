// RV32_EXT: M
// RV32_TEST_KIND: unit
#include <stdio.h>
#include <string.h>

#include "rv32_test.h"

// Lê pela UART, com a stdin do runtime, um nome e um número, e responde pela stdout: o programa imprime
// READY, espera a linha "UART 42" e imprime a saudação com os dois valores lidos. É o protocolo fixo dos
// testes de cocotb e da placa física.

// Nome que o host deve enviar.
static const char EXPECTED_NAME[] = "UART";
// Valor que o host deve enviar. É int porque o scanf com %d grava num int (ISO/IEC 9899:2024, 7.23.6.2).
static constexpr int EXPECTED_VALUE = 42;

// Espera o nome e o valor, confere os dois e responde; cada divergência é uma falha com o seu código.
int main(void) {
    char name[16];
    // int pelo mesmo motivo de EXPECTED_VALUE.
    int value = 0;

    printf("READY\n");
    if (scanf("%15s %d", name, &value) != 2) RV32_FAIL(1);
    if (strcmp(name, EXPECTED_NAME) != 0) RV32_FAIL(2);
    if (value != EXPECTED_VALUE) RV32_FAIL(3);

    printf("Hello, %s! value=%d\n", name, value);
    RV32_PASS();
}
