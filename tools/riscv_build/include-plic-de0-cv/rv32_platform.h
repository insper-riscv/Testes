/* The memory map and the interrupt sources of the de0-cv platform (Insper-RISC-V, src/cyclone-v/de0-cv) the PLIC
 * programs (asm-plic-de0-cv/) are built for. It must match the platform.yaml of the platform, whose generated
 * runtime header (memory_map.h) has the same names with the RV32_ prefix. */
#ifndef RV32_PLATFORM_H
#define RV32_PLATFORM_H

#define RV32_RAM_BASE    0x40000000   /* first byte of RAM (the SDRAM) */
#define RV32_RAM_END     0x44000000   /* one past the last byte of RAM */
#define RV32_STDOUT_BASE 0x43FFFBE0   /* the stdout buffer, at the top of RAM */
#define RV32_TOHOST      0x43FFFFE8   /* HTIF tohost, 8 bytes */
#define RV32_FROMHOST    0x43FFFFF0   /* HTIF fromhost */

#define RV32_FLASH_CTRL_BASE 0xB0000000
#define RV32_UART_BASE       0xC0000000   /* the JTAG UART, slot 4 */
#define RV32_CLINT_BASE      0xE0000000
#define RV32_PLIC_BASE       0xF0000000

#define RV32_PLIC_PRIORITY   (RV32_PLIC_BASE + 0x000000)
#define RV32_PLIC_PENDING    (RV32_PLIC_BASE + 0x001000)
#define RV32_PLIC_ENABLE     (RV32_PLIC_BASE + 0x002000)
#define RV32_PLIC_THRESHOLD  (RV32_PLIC_BASE + 0x200000)
#define RV32_PLIC_CLAIM      (RV32_PLIC_BASE + 0x200004)

/* The source ids, the same as interrupts.sources of the platform.yaml. */
#define RV32_IRQ_UART_JTAG   2
#define RV32_IRQ_FLASH       6

#define RV32_MIE_MEIE    0x00000800
#define RV32_CAUSE_MEI   0x8000000B

/* The registers of the FLASH controller, as byte offsets, and the commands of the chip. */
#define FL_CMD         0x00
#define FL_ADDR        0x04
#define FL_STATUS      0x08   /* bit 0 busy, bit 1 write latch, bit 2 refused */
#define FL_IRQ_ENABLE  0x14   /* bit 0 done, bit 1 refused */
#define FL_IRQ_STATUS  0x18   /* write 1 to clear */
#define FL_WREN        1
#define FL_ERASE       2
#define FL_PROGRAM     3
#define FL_PROTECT     4
#define FL_UNPROTECT   5

/* The JTAG UART registers. */
#define UJ_TXDATA        0x00
#define UJ_RXDATA        0x04
#define UJ_STATUS        0x08   /* a read clears the dropped bit (16) */
#define UJ_CONTROL       0x0C   /* bit 0 RX, bit 1 TX empty, bit 2 error */

#include "../include-plic/rv32_plic_macros.h"

#endif
