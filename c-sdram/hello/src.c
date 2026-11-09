// RV32_EXT: M
// RV32_TEST_KIND: unit
#include <stdint.h>
#include <stdio.h>

#include "rv32_platform.h"
#include "rv32_test.h"

// "Hello, world!" em C, no console da UART JTAG.
//
// Na placa, inicie o console primeiro e rode o programa enquanto ele escuta:
//
//   riscv-tools --config tools/riscv_build/config.sdram.yaml console --seconds 60
//
// O printf também espelha cada byte na UART depois que um host a varreu, então o programa espera o host
// antes de imprimir (bit 17 do registrador de estado da UART, com um limite para que uma placa sem ninguém
// ligado ainda termine). Os mesmos bytes caem no buffer de stdout, que este programa confere, então ele se
// autoverifica também na simulação.

// Registrador de estado da UART. Fica como macro porque um ponteiro para endereço fixo não pode ser constexpr
// (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo); o acesso é volatile (6.7.4.1) e alinhado a palavra.
#define UART_STATUS ((volatile uint32_t *)0xC0000008u)

// Número máximo de leituras do estado à espera do host.
static constexpr uint32_t ATTACH_POLLS = 40000000u;

// Diz se um host está ligado à UART (bit 17 do estado).
static inline bool host_attached(uint32_t status) {
    return ((status >> 17) & 1u) != 0u;
}

// Layout do buffer de stdout de platform/stdio.c: comprimento, sinalizador de truncamento e os bytes.
struct stdout_buffer {
    volatile uint32_t length;
    volatile uint32_t truncated;
    volatile char data[1024];
};

// Espera o host, imprime as duas linhas e confere que o buffer de stdout as guarda.
int main(void) {
    const struct stdout_buffer *out = (const struct stdout_buffer *)RV32_STDOUT_BASE;
    const char expected[] = "Hello, world!\nRISC-V RV32IM in C, 3 of 3\n";

    for (uint32_t polls = 0; polls < ATTACH_POLLS && !host_attached(*UART_STATUS); polls++) {
    }

    puts("Hello, world!");
    printf("RISC-V RV32IM in C, %d of %d\n", 3, 3);

    if (out->length != sizeof(expected) - 1) RV32_FAIL(1);
    for (uint32_t i = 0; i < out->length; i++) {
        if (out->data[i] != expected[i]) RV32_FAIL(2);
    }
    if (out->truncated != 0) RV32_FAIL(3);
    RV32_PASS();
}
