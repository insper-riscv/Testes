// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// The three interrupt causes of the UART over JTAG (source 2) through the PLIC, with the host scanning the
// chain from the testbench (the program asks it through fromhost): transmit empty (the host drains the three
// bytes queued, and the interrupt does not come before), a received byte (the host pushes 0xA5) and an error
// (a flood of 80 writes into a queue of 64 drops some, with the host stopped).
#include "rv32_platform.h"

#define SRC RV32_IRQ_UART_JTAG

    .section .text
    .globl main

main:
    RVPLIC_START
    li   t1, 3
    RVPLIC_PRIORITY(SRC, t1)
    li   t1, 1 << SRC
    RVPLIC_ENABLE(t1)
    RVPLIC_THRESHOLD(x0)
    li   s2, RV32_UART_JTAG_BASE
    RVPLIC_OPEN

    # A: transmit empty, once the host has taken the bytes
    li   t1, 0x41
    sw   t1, UJ_TXDATA(s2)
    sw   t1, UJ_TXDATA(s2)
    sw   t1, UJ_TXDATA(s2)
    li   t1, 2
    sw   t1, UJ_CONTROL(s2)
    RVHOST(RV32_HOST_JTAG_DRAIN)
    WAIT_COUNT(1, 1)
    CHECK(0x10, SRC, 2)
    CHECKM(0x14, 0xFF, 64, 3)    # all 64 places free: the host really drained the queue

    # B: received byte
    RVHOST(RV32_HOST_JTAG_PUSH)
    li   t1, 1
    sw   t1, UJ_CONTROL(s2)
    WAIT_COUNT(2, 4)
    CHECK(0x18, SRC, 5)
    CHECK(0x80, 0x100 | RV32_HOST_BYTE, 6)

    # C: error, the host stopped so the queue fills
    RVHOST(RV32_HOST_STOP)
    DELAY(3000)
    li   t1, 4
    sw   t1, UJ_CONTROL(s2)
    li   s3, 80
1:  sw   s3, UJ_TXDATA(s2)
    addi s3, s3, -1
    bnez s3, 1b
    WAIT_COUNT(3, 7)
    CHECK(0x20, SRC, 8)
    CHECKM(0x24, 0x10000, 0x10000, 9)   # a byte was dropped
    RVMODEL_HALT_PASS

    .balign 4
handler:
    RVPLIC_ENTER
    li   t3, RV32_PLIC_CLAIM
    lw   t1, 0(t3)                # claim
    li   t3, RV32_UART_JTAG_BASE
    lw   t2, UJ_STATUS(t3)        # the read clears the dropped bit
    sw   x0, UJ_CONTROL(t3)       # every cause off
    lw   t4, UJ_RXDATA(t3)        # pops a byte if there is one
    li   t3, RV32_RAM_BASE
    sw   t4, 0x80(t3)
    RVPLIC_LOG
    li   t3, RV32_PLIC_CLAIM
    sw   t1, 0(t3)                # complete
    RVPLIC_COUNT
    RVPLIC_LEAVE
