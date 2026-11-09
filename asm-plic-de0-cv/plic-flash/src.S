// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// The two events of the FLASH controller (source 6 of the PLIC) on the de0-cv simulation top, which has the
// command chip behind the controller: an erase of a sector of bank B raises DONE when the chip finishes (and
// the interrupt does not come before), and an erase of a protected sector raises REFUSED. Then the transmit-empty
// cause of the JTAG UART (source 2), whose host takes the queued bytes.
#include "rv32_platform.h"

#define SRC_FLASH RV32_IRQ_FLASH
#define SRC_UART  RV32_IRQ_UART_JTAG
#define SECTOR    0x30000             /* a sector of bank B */

    .section .text
    .globl main

main:
    RVPLIC_START
    li   t1, 3
    RVPLIC_PRIORITY(SRC_FLASH, t1)
    RVPLIC_PRIORITY(SRC_UART, t1)
    li   t1, (1 << SRC_FLASH) | (1 << SRC_UART)
    RVPLIC_ENABLE(t1)
    RVPLIC_THRESHOLD(x0)
    li   s2, RV32_FLASH_CTRL_BASE
    li   s3, RV32_UART_BASE
    RVPLIC_OPEN

    # A: DONE, once the chip has erased the sector
    li   t1, 1
    sw   t1, FL_IRQ_ENABLE(s2)
    li   t1, SECTOR
    sw   t1, FL_ADDR(s2)
    li   t1, FL_WREN
    sw   t1, FL_CMD(s2)
    li   t1, FL_ERASE
    sw   t1, FL_CMD(s2)
    lw   t1, FL_STATUS(s2)        # the chip shows busy right after the command
    andi t1, t1, 1
    bnez t1, 1f
    RVMODEL_HALT_FAIL(1)
1:
    WAIT_COUNT(1, 2)
    CHECK(0x10, SRC_FLASH, 3)
    CHECK(0x14, 1, 4)             # DONE and nothing else
    lw   t1, FL_STATUS(s2)
    andi t1, t1, 1
    beqz t1, 2f                   # the chip is idle when the interrupt arrives
    RVMODEL_HALT_FAIL(5)
2:

    # B: REFUSED, an erase of a protected sector
    li   t1, FL_PROTECT
    sw   t1, FL_CMD(s2)
    li   t1, FL_WREN
    sw   t1, FL_CMD(s2)
    li   t1, 2
    sw   t1, FL_IRQ_ENABLE(s2)
    li   t1, FL_ERASE
    sw   t1, FL_CMD(s2)
    WAIT_COUNT(2, 6)
    CHECK(0x18, SRC_FLASH, 7)
    CHECK(0x1C, 2, 8)             # REFUSED and nothing else
    li   t1, FL_UNPROTECT
    sw   t1, FL_CMD(s2)

    # C: transmit empty of the JTAG UART, after the host has drained the bytes
    li   t1, 0x41
    sw   t1, UJ_TXDATA(s3)
    sw   t1, UJ_TXDATA(s3)
    sw   t1, UJ_TXDATA(s3)
    li   t1, 2
    sw   t1, UJ_CONTROL(s3)
    WAIT_COUNT(3, 9)
    CHECK(0x20, SRC_UART, 10)
    CHECKM(0x24, 0xFF, 64, 11)    # all the places free: the host took the three bytes
    # the testbench compares what the host read from the UART with the stdout buffer: 3 bytes, "AAA"
    li   t0, RV32_STDOUT_BASE
    li   t1, 3
    sw   t1, 0(t0)                # length
    sw   x0, 4(t0)                # not truncated
    li   t1, 0x414141
    sw   t1, 8(t0)
    RVMODEL_HALT_PASS

    .balign 4
handler:
    RVPLIC_ENTER
    li   t3, RV32_PLIC_CLAIM
    lw   t1, 0(t3)                # claim
    li   t4, SRC_FLASH
    bne  t1, t4, 1f
    li   t3, RV32_FLASH_CTRL_BASE
    lw   t2, FL_IRQ_STATUS(t3)
    li   t4, 3
    sw   t4, FL_IRQ_STATUS(t3)    # clears both events
    sw   x0, FL_IRQ_ENABLE(t3)
    j    2f
1:
    li   t3, RV32_UART_BASE
    lw   t2, UJ_STATUS(t3)
    sw   x0, UJ_CONTROL(t3)
2:
    RVPLIC_LOG
    li   t3, RV32_PLIC_CLAIM
    sw   t1, 0(t3)                # complete
    RVPLIC_COUNT
    RVPLIC_LEAVE
