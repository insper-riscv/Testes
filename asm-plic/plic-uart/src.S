// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// The three interrupt causes of the UART on two pins (source 1) through the PLIC, with the transmitter
// wired back to the receiver by the testbench: transmitter empty (up as soon as it is enabled with the queue
// empty), a received byte (the byte sent comes back and the handler reads it) and an error (a flood of
// writes drops one byte). Each handler claims source 1, switches the causes off, clears the errors, logs
// STATUS and completes.
#include "rv32_platform.h"

#define SRC RV32_IRQ_UART

    .section .text
    .globl main

main:
    RVPLIC_START
    li   t1, 3
    RVPLIC_PRIORITY(SRC, t1)
    li   t1, 1 << SRC
    RVPLIC_ENABLE(t1)
    RVPLIC_THRESHOLD(x0)
    li   s2, RV32_UART_BASE
    RVPLIC_OPEN

    # A: transmitter empty
    li   t1, 2
    sw   t1, UART_CONTROL(s2)
    WAIT_COUNT(1, 1)
    CHECK(0x10, SRC, 2)
    CHECKM(0x14, 0x23, 0x22, 3)  # TX_EMPTY and TX_READY, no RX_VALID

    # B: received byte (RX_VALID, TX_READY and one byte in the queue)
    li   t1, 0x55
    sw   t1, UART_TX_DATA(s2)
    li   t1, 1
    sw   t1, UART_CONTROL(s2)
    WAIT_COUNT(2, 4)
    CHECK(0x18, SRC, 5)
    CHECKM(0x1C, 0x103, 0x103, 6)
    CHECK(0x80, 0x55, 7)         # the byte that came back

    # C: error, a flood of writes drops one
    li   t1, 4
    sw   t1, UART_CONTROL(s2)
    li   s3, 24
1:  sw   s3, UART_TX_DATA(s2)
    addi s3, s3, -1
    bnez s3, 1b
    WAIT_COUNT(3, 8)
    CHECK(0x20, SRC, 9)
    CHECKM(0x24, 0xC, 0x8, 10)   # TX_DROPPED, no RX_OVERRUN
    RVMODEL_HALT_PASS

    .balign 4
handler:
    RVPLIC_ENTER
    li   t3, RV32_PLIC_CLAIM
    lw   t1, 0(t3)                # claim
    li   t3, RV32_UART_BASE
    lw   t2, UART_STATUS(t3)
    sw   x0, UART_CONTROL(t3)     # every cause off
    li   t4, 0xC
    sw   t4, UART_STATUS(t3)      # clears the errors
    andi t4, t2, 1
    beqz t4, 1f
    lw   t4, UART_RX_DATA(t3)     # pops the byte
    li   t3, RV32_RAM_BASE
    sw   t4, 0x80(t3)
1:
    RVPLIC_LOG
    li   t3, RV32_PLIC_CLAIM
    sw   t1, 0(t3)                # complete
    RVPLIC_COUNT
    RVPLIC_LEAVE
