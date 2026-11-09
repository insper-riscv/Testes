/* O mapa de memória e as fontes de interrupção da plataforma modular (Insper-RISC-V, src/simulation/modular) para
 * os quais os programas do PLIC (asm-plic/) são construídos, como números simples que um programa em assembly
 * usa. Deve coincidir com o platform.yaml da plataforma, cujo cabeçalho de runtime gerado (memory_map.h) tem os
 * mesmos nomes com o prefixo RV32_.
 *
 * Os números ficam em #define (e não em constexpr ou enum) porque o assembly (.S) inclui este arquivo e só o
 * pré-processador os enxerga (ISO/IEC 9899:2024, 6.10); o C de 6.7.2 não é visível ao montador. */
#ifndef RV32_PLATFORM_H
#define RV32_PLATFORM_H

#define RV32_RAM_BASE    0x00100000   /* primeiro byte da RAM */
#define RV32_RAM_END     0x00200000   /* um após o último byte da RAM */
#define RV32_STDOUT_BASE 0x001FFBE0   /* o buffer de stdout, no topo da RAM */
#define RV32_TOHOST      0x001FFFE8   /* tohost do HTIF, 8 bytes */
#define RV32_FROMHOST    0x001FFFF0   /* fromhost do HTIF: o programa fala aqui com o host do testbench */

/* O host do testbench (testbench/peripheral_models.py) lê uma palavra escrita no fromhost: 1 inicia a varredura
 * do host JTAG e empurra um byte (0xA5) para a UART JTAG, 2 inicia a varredura sem o empurrão (só esvazia a fila
 * de transmissão) e 0 a para. */
#define RV32_HOST_STOP        0
#define RV32_HOST_JTAG_PUSH   1
#define RV32_HOST_JTAG_DRAIN  2
#define RV32_HOST_BYTE        0xA5

/* Os periféricos da janela de 0x80000000 em diante: um slot de 256 MiB cada. */
#define RV32_TIMER_BASE      0x80000000
#define RV32_SWITCHES_BASE   0x90000000
#define RV32_KEYS_BASE       0xA0000000
#define RV32_UART_BASE       0xB0000000
#define RV32_UART_JTAG_BASE  0xC0000000
#define RV32_CLINT_BASE      0xE0000000
#define RV32_PLIC_BASE       0xF0000000

/* Os registradores do PLIC (riscv-plic-1.0.0), contexto 0. */
#define RV32_PLIC_PRIORITY   (RV32_PLIC_BASE + 0x000000)   /* + 4 * id da fonte */
#define RV32_PLIC_PENDING    (RV32_PLIC_BASE + 0x001000)
#define RV32_PLIC_ENABLE     (RV32_PLIC_BASE + 0x002000)
#define RV32_PLIC_THRESHOLD  (RV32_PLIC_BASE + 0x200000)
#define RV32_PLIC_CLAIM      (RV32_PLIC_BASE + 0x200004)

/* Os ids das fontes, os mesmos de interrupts.sources do platform.yaml. */
#define RV32_IRQ_UART        1
#define RV32_IRQ_UART_JTAG   2
#define RV32_IRQ_SWITCHES    3
#define RV32_IRQ_KEYS        4
#define RV32_IRQ_TIMER       5
#define RV32_IRQ_FLASH       6

/* Os bits do mie e a causa da interrupção externa. */
#define RV32_MIE_MEIE    0x00000800
#define RV32_CAUSE_MEI   0x8000000B

/* Os registradores dos periféricos, como deslocamentos em bytes. */
/* TIMER */
#define TIMER_CONFIG     0x00   /* bit 0 inicia, bit 1 modo, bit 2 pwm, bit 3 máscara de irq */
#define TIMER_TOP        0x0C
#define TIMER_OVF_STATUS 0x14   /* uma leitura o limpa */
#define TIMER_PRESCALER  0x1C
/* GPIO (chaves e botões) */
#define GPIO_DIR         0x00
#define GPIO_OUT_LOAD    0x04
#define GPIO_IRQ_MASK    0x14
#define GPIO_RISE_MASK   0x18
#define GPIO_FALL_MASK   0x1C
#define GPIO_IRQ_STAT    0x20   /* uma leitura o limpa */
#define GPIO_PINS        0x24
#define GPIO_LEVEL_MASK  0x28
/* UART nos pinos */
#define UART_TX_DATA     0x00
#define UART_RX_DATA     0x04
#define UART_STATUS      0x08   /* escrever 1 limpa RX_OVERRUN (bit 2) e TX_DROPPED (bit 3) */
#define UART_CONTROL     0x0C   /* bit 0 RX, bit 1 TX vazio, bit 2 erro */
/* UART no JTAG */
#define UJ_TXDATA        0x00
#define UJ_RXDATA        0x04
#define UJ_STATUS        0x08   /* uma leitura limpa o bit de descarte (16) */
#define UJ_CONTROL       0x0C   /* bit 0 RX, bit 1 TX vazio, bit 2 erro */

#include "rv32_plic_macros.h"

#endif
