// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// The overflow of the TIMER reaches the core through the PLIC: with the source enabled in the timer
// (irq mask) and in the PLIC, the overflow raises MEIP once, the handler claims source 5, reads the
// overflow status (which clears it), stops the timer and completes; the pending bit of the PLIC is
// clear afterwards and the handler ran exactly once.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    RVPLIC_START
    li   t1, 3
    RVPLIC_PRIORITY(RV32_IRQ_TIMER, t1)
    li   t1, 1 << RV32_IRQ_TIMER
    RVPLIC_ENABLE(t1)
    RVPLIC_THRESHOLD(x0)
    li   s2, RV32_TIMER_BASE
    sw   x0, TIMER_PRESCALER(s2)
    li   t1, 200
    sw   t1, TIMER_TOP(s2)
    RVPLIC_OPEN
    li   t1, 9                    # start and the interrupt mask
    sw   t1, TIMER_CONFIG(s2)
    WAIT_COUNT(1, 1)
    DELAY(2000)                   # a second entry would show up here
    CHECK(0, 1, 2)                # exactly one entry
    CHECK(0x10, RV32_IRQ_TIMER, 3)   # the claim returned the timer
    li   t1, RV32_PLIC_PENDING
    lw   t1, 0(t1)
    beqz t1, 1f                   # nothing is pending in the PLIC
    RVMODEL_HALT_FAIL(4)
1:
    RVMODEL_HALT_PASS

    .balign 4
handler:
    RVPLIC_ENTER
    li   t3, RV32_PLIC_CLAIM
    lw   t1, 0(t3)                # claim
    li   t3, RV32_TIMER_BASE
    lw   t2, TIMER_OVF_STATUS(t3) # the read clears the status
    sw   x0, TIMER_CONFIG(t3)     # stops the timer
    RVPLIC_LOG
    li   t3, RV32_PLIC_CLAIM
    sw   t1, 0(t3)                # complete
    RVPLIC_COUNT
    RVPLIC_LEAVE
