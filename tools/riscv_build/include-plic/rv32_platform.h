/* The memory map and the interrupt sources of the modular platform (Insper-RISC-V, src/simulation/modular) the
 * PLIC programs (asm-plic/) are built for, as plain numbers an assembly program can use. It must match the
 * platform.yaml of the platform, whose generated runtime header (memory_map.h) has the same names with the
 * RV32_ prefix. */
#ifndef RV32_PLATFORM_H
#define RV32_PLATFORM_H

#define RV32_RAM_BASE    0x00100000   /* first byte of RAM */
#define RV32_RAM_END     0x00200000   /* one past the last byte of RAM */
#define RV32_STDOUT_BASE 0x001FFBE0   /* the stdout buffer, at the top of RAM */
#define RV32_TOHOST      0x001FFFE8   /* HTIF tohost, 8 bytes */
#define RV32_FROMHOST    0x001FFFF0   /* HTIF fromhost: the program talks to the testbench host here */

/* The testbench host (testbench/peripheral_models.py) reads a word written to fromhost:
 * 1 starts the JTAG host scanning and pushes one byte (0xA5) to the JTAG UART, 2 starts it scanning without
 * the push (it only drains the transmit queue), 0 stops it. */
#define RV32_HOST_STOP        0
#define RV32_HOST_JTAG_PUSH   1
#define RV32_HOST_JTAG_DRAIN  2
#define RV32_HOST_BYTE        0xA5

/* The peripherals of the window of 0x80000000 and above: one slot of 256 MiB each. */
#define RV32_TIMER_BASE      0x80000000
#define RV32_SWITCHES_BASE   0x90000000
#define RV32_KEYS_BASE       0xA0000000
#define RV32_UART_BASE       0xB0000000
#define RV32_UART_JTAG_BASE  0xC0000000
#define RV32_CLINT_BASE      0xE0000000
#define RV32_PLIC_BASE       0xF0000000

/* The registers of the PLIC (riscv-plic-1.0.0), context 0. */
#define RV32_PLIC_PRIORITY   (RV32_PLIC_BASE + 0x000000)   /* + 4 * source id */
#define RV32_PLIC_PENDING    (RV32_PLIC_BASE + 0x001000)
#define RV32_PLIC_ENABLE     (RV32_PLIC_BASE + 0x002000)
#define RV32_PLIC_THRESHOLD  (RV32_PLIC_BASE + 0x200000)
#define RV32_PLIC_CLAIM      (RV32_PLIC_BASE + 0x200004)

/* The source ids, the same as interrupts.sources of the platform.yaml. */
#define RV32_IRQ_UART        1
#define RV32_IRQ_UART_JTAG   2
#define RV32_IRQ_SWITCHES    3
#define RV32_IRQ_KEYS        4
#define RV32_IRQ_TIMER       5
#define RV32_IRQ_FLASH       6

/* The bits of mie and the cause of the external interrupt. */
#define RV32_MIE_MEIE    0x00000800
#define RV32_CAUSE_MEI   0x8000000B

/* The registers of the peripherals, as byte offsets. */
/* TIMER */
#define TIMER_CONFIG     0x00   /* bit 0 start, bit 1 mode, bit 2 pwm, bit 3 irq mask */
#define TIMER_TOP        0x0C
#define TIMER_OVF_STATUS 0x14   /* a read clears it */
#define TIMER_PRESCALER  0x1C
/* GPIO (switches and keys) */
#define GPIO_DIR         0x00
#define GPIO_OUT_LOAD    0x04
#define GPIO_IRQ_MASK    0x14
#define GPIO_RISE_MASK   0x18
#define GPIO_FALL_MASK   0x1C
#define GPIO_IRQ_STAT    0x20   /* a read clears it */
#define GPIO_PINS        0x24
#define GPIO_LEVEL_MASK  0x28
/* UART on pins */
#define UART_TX_DATA     0x00
#define UART_RX_DATA     0x04
#define UART_STATUS      0x08   /* write 1 clears RX_OVERRUN (bit 2) and TX_DROPPED (bit 3) */
#define UART_CONTROL     0x0C   /* bit 0 RX, bit 1 TX empty, bit 2 error */
/* UART on JTAG */
#define UJ_TXDATA        0x00
#define UJ_RXDATA        0x04
#define UJ_STATUS        0x08   /* a read clears the dropped bit (16) */
#define UJ_CONTROL       0x0C   /* bit 0 RX, bit 1 TX empty, bit 2 error */

#include "rv32_plic_macros.h"

#endif
