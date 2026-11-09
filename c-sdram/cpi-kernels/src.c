// RV32_EXT: M, Zicsr
// RV32_TEST_KIND: unit
// RV32_TIMEOUT_S: 90
#include <stdint.h>
#include <stdio.h>

#include "rv32_platform.h"
#include "rv32_sdram.h"
#include "rv32_test.h"

// Ciclos por instrução de cinco kernels, medidos com os contadores de ciclo e de instruções retiradas do
// Zicntr. Cada kernel roda entre duas leituras dos dois contadores, e o programa imprime uma linha por kernel
// ("cpi <nome> <ciclos> <instret>") na UART JTAG. As contagens são as mesmas na placa e na simulação, então as
// duas saídas podem ser comparadas linha a linha. O programa confere que cada kernel moveu os dois contadores
// e levou no máximo 200 ciclos por instrução.

// Registrador de estado da UART. Fica como macro porque um ponteiro para endereço fixo não pode ser constexpr
// (ISO/IEC 9899:2024, 6.7.2: só o ponteiro nulo); o acesso é volatile (6.7.4.1) e alinhado a palavra.
#define UART_STATUS ((volatile uint32_t *)0xC0000008u)

// Número máximo de leituras do estado à espera do host.
static constexpr uint32_t ATTACH_POLLS = 40000000u;
// Elementos de cada kernel.
static constexpr uint32_t N = 256;
// Número máximo de leituras do estado à espera de a UART esvaziar.
static constexpr uint32_t DRAIN_POLLS = 8000000u;
// Profundidade da FIFO de transmissão da UART, em bytes.
static constexpr uint32_t TX_DEPTH = 64u;

// Diz se um host está ligado à UART (bit 17 do estado).
static inline bool host_attached(uint32_t status) {
    return ((status >> 17) & 1u) != 0u;
}

// Extrai do estado os bytes livres na FIFO de transmissão (bits 7 a 0).
static inline uint32_t tx_free(uint32_t status) {
    return status & 0xFFu;
}

// Contagem de ciclos e de instruções retiradas no início de um kernel.
struct sample {
    uint32_t cycles;
    uint32_t instret;
};

// Lê o contador de ciclos (csr cycle).
static inline uint32_t read_cycle(void) {
    uint32_t v;
    __asm__ volatile("csrr %0, 0xC00" : "=r"(v));
    return v;
}

// Lê o contador de instruções retiradas (csr instret).
static inline uint32_t read_instret(void) {
    uint32_t v;
    __asm__ volatile("csrr %0, 0xC02" : "=r"(v));
    return v;
}

// Começa a medição de um kernel lendo os dois contadores.
static struct sample begin(void) {
    struct sample s;
    s.instret = read_instret();
    s.cycles = read_cycle();
    return s;
}

// Termina a medição, imprime a linha do kernel e confere que os contadores andaram.
static void finish(const char *name, struct sample s) {
    uint32_t cycles = read_cycle() - s.cycles;
    uint32_t instret = read_instret() - s.instret;
    printf("cpi %s %u %u\n", name, (unsigned int)cycles, (unsigned int)instret);
    // a UART guarda poucos bytes: espera o host esvaziá-los antes da linha seguinte (com um limite, para que
    // uma placa sem ninguém ligado ainda termine)
    for (uint32_t polls = 0; polls < DRAIN_POLLS && tx_free(*UART_STATUS) < TX_DEPTH; polls++) {
    }
    if (instret == 0 || cycles < instret || cycles > 200u * instret) RV32_FAIL(1);
}

// Mede os cinco kernels (inteiros, multiplicação, divisão, leitura da SDRAM e escrita de byte na SDRAM).
int main(void) {
    volatile uint32_t *m = RV32_SDRAM;
    volatile uint32_t sink = 0;
    uint32_t acc = 1;
    struct sample s;

    for (uint32_t polls = 0; polls < ATTACH_POLLS && !host_attached(*UART_STATUS); polls++) {
    }
    for (uint32_t i = 0; i < N; i++) m[i] = i * 3u + 1u;

    s = begin();                                   // inteiros: addi, add, xor, bne
    for (uint32_t i = 0; i < N; i++) acc = (acc + i) ^ (acc >> 3);
    sink = acc;
    finish("int-loop", s);

    s = begin();                                   // multiplicação
    for (uint32_t i = 1; i <= N / 4; i++) acc = acc * i + 7u;
    sink = acc;
    finish("multiply", s);

    s = begin();                                   // divisão
    for (uint32_t i = 1; i <= N / 4; i++) acc = (acc | 0x10000u) / (i + 2u);
    sink = acc;
    finish("divide", s);

    s = begin();                                   // leituras de palavra da SDRAM
    for (uint32_t i = 0; i < N; i++) acc += m[i];
    sink = acc;
    finish("sdram-load", s);

    s = begin();                                   // escritas de byte na SDRAM
    for (uint32_t i = 0; i < N; i++) ((volatile unsigned char *)m)[N * 4 + i] = (unsigned char)i;
    finish("sdram-byte-store", s);

    (void)sink;
    RV32_PASS();
}
