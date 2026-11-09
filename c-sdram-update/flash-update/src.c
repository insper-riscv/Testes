// RV32_EXT: Zifencei
// RV32_TEST_KIND: unit
#include <stdint.h>

#include "rv32_flash_update.h"
#include "rv32_platform.h"
#include "rv32_test.h"

// Uma atualização completa da banca B, como o firmware de um produto a faz.
//
// O programa é a banca A (versão 1). O host envia a imagem da banca B pela UART JTAG (na simulação o
// testbench envia o uart_input.txt, a saída de `riscv-tools flash-image pack` para update-new); o programa
// confere o fluxo, executa a rotina de atualização da SDRAM (apaga, programa a carga, programa o cabeçalho
// por último, lê de volta) e reinicia pela memória de boot. A memória de boot vê duas bancas válidas e roda a mais
// nova, então o que encerra o teste é a banca B escrevendo o seu tohost: update-new imprime a linha do
// uart_expected.txt. Se a memória de boot rodar a banca A de novo, a palavra sobrevivente avisa e o teste falha.
//
// O controlador da FLASH só existe no topo de simulação com HAS_FLASH_CONTROLLER (config.sdram-flash-update*.yaml).

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

// Recebe a imagem pela UART, atualiza a banca B e reinicia; chegar ao fim de main é uma falha.
int main(void) {
    if (rv32_update_bank_of((uint32_t)(uintptr_t)&main) != RV32_BANK_A_BASE) RV32_FAIL(1);
    // a atualização reiniciou o núcleo e a memória de boot voltou aqui: ela não pegou a banca B
    if (*SURVIVOR == UPDATING) RV32_FAIL(2);
    uint32_t length = 0;
    int status = rv32_update_receive(image, IMAGE_CAPACITY, &length);
    if (status != RV32_UPDATE_OK) RV32_FAIL(10u + (uint32_t)status);
    *SURVIVOR = UPDATING;
    status = rv32_update_bank(RV32_BANK_B_BASE, image, length, RV32_UPDATE_RESTART, ram_code, CODE_WORDS);
    RV32_FAIL(20u + (uint32_t)status);
}
