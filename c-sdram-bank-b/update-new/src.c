// RV32_TEST_KIND: unit
#include <stdint.h>
#include <stdio.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// O programa que os testes de atualização enviam: banca B, versão 2. Não é um teste próprio (o
// config.sdram-flash.yaml não olha esta pasta): `make flash-update-images` o constrói com o
// config.sdram-flash-bank-b.yaml, o liga no início da banca B depois da página de cabeçalho, o empacota como
// versão 2 e escreve a imagem no uart_input.txt dos testes de atualização. Ele confere que roda da banca B,
// zera a palavra sobrevivente que os programas de atualização deixam, imprime uma linha e passa.

// Palavra da RAM que sobrevive ao reinício e marca a atualização em andamento. Fica como macro porque um
// ponteiro para endereço fixo não pode ser constexpr (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo).
#define SURVIVOR ((volatile uint32_t *)(RV32_RAM_BASE + 0x03000000u))

// Confere que main está na banca B, limpa a palavra sobrevivente, imprime a linha da versão 2 e passa.
int main(void) {
    uint32_t pc = (uint32_t)(uintptr_t)&main;
    if (pc < RV32_BANK_B_BASE || pc >= RV32_BANK_B_BASE + RV32_BANK_B_SIZE) RV32_FAIL(1);
    *SURVIVOR = 0;
    printf("bank B running, version 2\n");
    RV32_PASS();
}
