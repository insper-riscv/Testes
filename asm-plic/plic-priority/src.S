// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Priority, tie and threshold with two sources pending at once: the UART transmitter-empty cause (source 1)
// and a high level on a button pin (source 4). With MIE closed both are armed and the PLIC pending register
// shows 0x12; opening MIE the handler runs once per source. A: priority 2 for source 1 and 5 for source 4
// takes 4 then 1. B: equal priorities take the lower id first. C: threshold 3 lets only source 4 (5) through
// until the threshold goes to 0. D: priority 0 never interrupts until it is raised.
#include "rv32_platform.h"

#define PENDING_BOTH 0x12

    .section .text
    .globl main

/* Arms both sources (MIE is closed) and waits until the PLIC shows both pending. */
#define ARM(code) \
    li   t1, 8; \
    sw   t1, GPIO_IRQ_MASK(s3); \
    li   t1, 2; \
    sw   t1, UART_CONTROL(s2); \
    li   s1, 400000; \
5:  li   t1, RV32_PLIC_PENDING; \
    lw   t1, 0(t1); \
    li   t2, PENDING_BOTH; \
    and  t1, t1, t2; \
    beq  t1, t2, 6f; \
    addi s1, s1, -1; \
    bnez s1, 5b; \
    RVMODEL_HALT_FAIL(code); \
6:

main:
    RVPLIC_START
    li   t1, (1 << RV32_IRQ_UART) | (1 << RV32_IRQ_KEYS)
    RVPLIC_ENABLE(t1)
    RVPLIC_THRESHOLD(x0)
    li   s2, RV32_UART_BASE
    li   s3, RV32_KEYS_BASE
    li   t1, 8                    # pin 3 high, a level source once the mask is on
    sw   t1, GPIO_DIR(s3)
    sw   t1, GPIO_OUT_LOAD(s3)
    sw   t1, GPIO_RISE_MASK(s3)
    sw   t1, GPIO_LEVEL_MASK(s3)
    li   t1, RV32_MIE_MEIE
    csrs mie, t1

    # A: priorities 2 (UART) and 5 (keys): keys first
    li   t1, 2
    RVPLIC_PRIORITY(RV32_IRQ_UART, t1)
    li   t1, 5
    RVPLIC_PRIORITY(RV32_IRQ_KEYS, t1)
    ARM(1)
    RVPLIC_MIE_ON
    WAIT_COUNT(2, 2)
    CHECK(0x10, RV32_IRQ_KEYS, 3)
    CHECK(0x18, RV32_IRQ_UART, 4)
    RVPLIC_MIE_OFF

    # B: equal priorities: the lower id first
    li   t1, 3
    RVPLIC_PRIORITY(RV32_IRQ_UART, t1)
    RVPLIC_PRIORITY(RV32_IRQ_KEYS, t1)
    ARM(5)
    RVPLIC_MIE_ON
    WAIT_COUNT(4, 6)
    CHECK(0x20, RV32_IRQ_UART, 7)
    CHECK(0x28, RV32_IRQ_KEYS, 8)
    RVPLIC_MIE_OFF

    # C: threshold 3: only the source of priority 5 is taken
    li   t1, 2
    RVPLIC_PRIORITY(RV32_IRQ_UART, t1)
    li   t1, 5
    RVPLIC_PRIORITY(RV32_IRQ_KEYS, t1)
    li   t1, 3
    RVPLIC_THRESHOLD(t1)
    ARM(9)
    RVPLIC_MIE_ON
    WAIT_COUNT(5, 10)
    DELAY(2000)
    CHECK(0, 5, 11)               # the source of priority 2 is held back
    CHECK(0x30, RV32_IRQ_KEYS, 12)
    li   t1, RV32_PLIC_PENDING
    lw   t1, 0(t1)
    li   t2, 1 << RV32_IRQ_UART
    beq  t1, t2, 1f               # still pending in the PLIC
    RVMODEL_HALT_FAIL(13)
1:
    RVPLIC_THRESHOLD(x0)
    WAIT_COUNT(6, 14)
    CHECK(0x38, RV32_IRQ_UART, 15)
    RVPLIC_MIE_OFF

    # D: priority 0 never interrupts
    li   t1, 0
    RVPLIC_PRIORITY(RV32_IRQ_UART, t1)
    ARM(16)
    RVPLIC_MIE_ON
    WAIT_COUNT(7, 17)
    DELAY(2000)
    CHECK(0, 7, 18)
    CHECK(0x40, RV32_IRQ_KEYS, 19)
    li   t1, 1
    RVPLIC_PRIORITY(RV32_IRQ_UART, t1)
    WAIT_COUNT(8, 20)
    CHECK(0x48, RV32_IRQ_UART, 21)

    # nothing left: the claim returns 0
    RVPLIC_CLAIM(t1)
    beqz t1, 2f
    RVMODEL_HALT_FAIL(22)
2:
    RVMODEL_HALT_PASS

    .balign 4
handler:
    RVPLIC_ENTER
    li   t3, RV32_PLIC_CLAIM
    lw   t1, 0(t3)                # claim
    li   t2, 0
    li   t3, RV32_UART_BASE
    li   t4, RV32_IRQ_UART
    bne  t1, t4, 1f
    sw   x0, UART_CONTROL(t3)     # the UART cause off
    j    2f
1:
    li   t3, RV32_KEYS_BASE
    sw   x0, GPIO_IRQ_MASK(t3)    # the button level off
    lw   t2, GPIO_IRQ_STAT(t3)
2:
    RVPLIC_LOG
    li   t3, RV32_PLIC_CLAIM
    sw   t1, 0(t3)                # complete
    RVPLIC_COUNT
    RVPLIC_LEAVE
