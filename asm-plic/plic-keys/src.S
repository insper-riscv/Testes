// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// The push-button GPIO (source 4) through the PLIC, one pin driven by its own output: a rising edge, a
// falling edge, a high level and a low level (the rise mask asks for the high level and the fall mask for the
// low one when the level mode is on), each raising MEIP once with the pin in IRQ_STAT; a pin that is not in
// the global mask raises nothing.
#include "rv32_platform.h"

#define GPIO RV32_KEYS_BASE
#define SRC  RV32_IRQ_KEYS
#define OTHER 0x4                 /* a second output pin, outside the global mask in the last phase */

    .section .text
    .globl main

main:
    RVPLIC_START
    li   t1, 3
    RVPLIC_PRIORITY(SRC, t1)
    li   t1, 1 << SRC
    RVPLIC_ENABLE(t1)
    RVPLIC_THRESHOLD(x0)
    li   s2, GPIO
    li   t1, 8 | OTHER            # pin 3 and the other pin are outputs, both low
    sw   t1, GPIO_DIR(s2)
    sw   x0, GPIO_OUT_LOAD(s2)
    RVPLIC_OPEN
    DELAY(50)

    # A: rising edge of pin 3
    li   t1, 8
    sw   t1, GPIO_RISE_MASK(s2)
    sw   x0, GPIO_FALL_MASK(s2)
    sw   x0, GPIO_LEVEL_MASK(s2)
    sw   t1, GPIO_IRQ_MASK(s2)
    sw   t1, GPIO_OUT_LOAD(s2)
    WAIT_COUNT(1, 1)
    CHECK(0x10, SRC, 2)
    CHECK(0x14, 8, 3)

    # B: falling edge of pin 3
    li   t1, 8
    sw   x0, GPIO_RISE_MASK(s2)
    sw   t1, GPIO_FALL_MASK(s2)
    sw   t1, GPIO_IRQ_MASK(s2)
    sw   x0, GPIO_OUT_LOAD(s2)
    WAIT_COUNT(2, 4)
    CHECK(0x18, SRC, 5)
    CHECK(0x1C, 8, 6)

    # C: high level of pin 3: nothing while it is low, an interrupt once it goes high
    li   t1, 8
    sw   x0, GPIO_FALL_MASK(s2)
    sw   t1, GPIO_RISE_MASK(s2)
    sw   t1, GPIO_LEVEL_MASK(s2)
    sw   t1, GPIO_IRQ_MASK(s2)
    DELAY(300)
    CHECK(0, 2, 7)
    li   t1, 8
    sw   t1, GPIO_OUT_LOAD(s2)
    WAIT_COUNT(3, 8)
    CHECK(0x20, SRC, 9)
    CHECK(0x24, 8, 10)

    # D: low level of pin 3: nothing while it is high, an interrupt once it goes low
    li   t1, 8
    sw   x0, GPIO_RISE_MASK(s2)
    sw   t1, GPIO_FALL_MASK(s2)
    sw   t1, GPIO_IRQ_MASK(s2)
    DELAY(300)
    CHECK(0, 3, 11)
    sw   x0, GPIO_OUT_LOAD(s2)
    WAIT_COUNT(4, 12)
    CHECK(0x28, SRC, 13)
    CHECK(0x2C, 8, 14)

    # E: the other pin is not in the global mask: its edge raises nothing
    li   t1, 8 | OTHER
    sw   x0, GPIO_LEVEL_MASK(s2)
    sw   t1, GPIO_RISE_MASK(s2)
    li   t1, 8
    sw   t1, GPIO_IRQ_MASK(s2)
    li   t1, OTHER
    sw   t1, GPIO_OUT_LOAD(s2)
    DELAY(300)
    CHECK(0, 4, 15)
    RVMODEL_HALT_PASS

    .balign 4
handler:
    RVPLIC_ENTER
    li   t3, RV32_PLIC_CLAIM
    lw   t1, 0(t3)                # claim
    li   t3, GPIO
    sw   x0, GPIO_IRQ_MASK(t3)    # the level source stops here
    lw   t2, GPIO_IRQ_STAT(t3)    # the pins that raised it; the read clears them
    RVPLIC_LOG
    li   t3, RV32_PLIC_CLAIM
    sw   t1, 0(t3)                # complete
    RVPLIC_COUNT
    RVPLIC_LEAVE
