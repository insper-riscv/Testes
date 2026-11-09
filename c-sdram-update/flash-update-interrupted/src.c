// RV32_EXT: M,Zifencei
// RV32_TEST_KIND: unit
#include <stdint.h>
#include <stdio.h>

#include "rv32_flash_update.h"
#include "rv32_platform.h"
#include "rv32_test.h"

// Uma atualização que perde energia antes do fim: a página de cabeçalho da banca B nunca é escrita.
//
// É o mesmo programa de flash-update até a rotina, que recebe a ordem de cortar a atualização
// (RV32_UPDATE_CUT): ela apaga a banca B e programa a carga, mas deixa a página de cabeçalho apagada, e
// reinicia. A ROM de boot não acha cabeçalho válido na banca B e roda a banca A de novo, que é a segunda
// execução da palavra sobrevivente: ela lê a banca B de volta, acha o cabeçalho inválido e a carga lá (o
// corte foi depois da carga, não antes de tudo), imprime a linha do uart_expected.txt e passa.

// Capacidade, em bytes, do buffer que recebe a imagem da banca B.
static constexpr uint32_t IMAGE_CAPACITY = 4096u;
// Palavras reservadas para a cópia da rotina de atualização na SDRAM.
static constexpr uint32_t CODE_WORDS = 160u;
// Valor da palavra sobrevivente que marca a atualização em andamento.
static constexpr uint32_t UPDATING = 0x0FEDCBA9u;

// Palavra da RAM que sobrevive ao reinício. Fica como macro porque um ponteiro para endereço fixo não pode
// ser constexpr (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo).
#define SURVIVOR ((volatile uint32_t *)(RV32_RAM_BASE + 0x03000000u))

// Buffer da imagem recebida, alinhado a palavra porque a rotina em assembly a lê com lw (alignas, 6.7.6).
alignas(4) static uint8_t image[IMAGE_CAPACITY];
// Buffer da cópia da rotina de atualização.
static uint32_t ram_code[CODE_WORDS];

// Na primeira execução recebe a imagem e corta a atualização; na segunda confere a banca B e passa.
int main(void) {
    if (rv32_update_bank_of((uint32_t)(uintptr_t)&main) != RV32_BANK_A_BASE) RV32_FAIL(1);
    if (*SURVIVOR == UPDATING) {
        uint32_t version = 0;
        if (rv32_update_check(RV32_BANK_B_BASE, RV32_BANK_B_SIZE, &version) == RV32_UPDATE_OK) RV32_FAIL(3);
        if (*(volatile uint32_t *)(RV32_BANK_B_BASE + RV32_HEADER_SIZE) == RV32_FLASH_ERASED_WORD) RV32_FAIL(4);
        *SURVIVOR = 0;
        printf("interrupted update: the boot ROM stayed on bank A\n");
        RV32_PASS();
    }
    uint32_t length = 0;
    int status = rv32_update_receive(image, IMAGE_CAPACITY, &length);
    if (status != RV32_UPDATE_OK) RV32_FAIL(10u + (uint32_t)status);
    *SURVIVOR = UPDATING;
    status = rv32_update_bank(
        RV32_BANK_B_BASE, image, length, RV32_UPDATE_CUT | RV32_UPDATE_RESTART, ram_code, CODE_WORDS);
    RV32_FAIL(20u + (uint32_t)status);
}
