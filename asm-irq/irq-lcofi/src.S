// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Sscofpmf: the counter-overflow interrupt (LCOFI, cause 13). The taken-branch event on mhpmcounter3 is
// armed 40 counts below the wrap of the 64-bit counter. The overflow sets mhpmevent3h.OF and mip.LCOFIP,
// and with LCOFIE and MIE the interrupt enters once with mcause 0x8000000D. With OF set another overflow asks
// for nothing; clearing OF re-arms the counter; with LCOFIE clear the request stays in mip and is taken when
// the mask is set; MINH stops the counting. mhpmeventNh are CSRs 0x723 and up, mip.LCOFIP is bit 13.
#include "rv32_platform.h"

#define CSR_MHPMEVENT3    0x323
#define CSR_MHPMEVENT3H   0x723
#define CSR_MHPMCOUNTER3  0xB03
#define CSR_MHPMCOUNTER3H 0xB83
#define LCOFI_BIT         0x2000
#define OF_BIT            0x80000000
#define MINH_BIT          0x40000000
#define EVENT_BRANCH      3
#define CAUSE_LCOFI       0x8000000D

    .section .text
    .globl main

/* Arms mhpmcounter3 to wrap after `n` taken branches. Clobbers t0 and t1. */
    .macro arm n
    li   t0, -(\n)
    csrw CSR_MHPMCOUNTER3, t0
    li   t1, -1
    csrw CSR_MHPMCOUNTER3H, t1
    .endm

/* Runs `n` iterations of a loop with one taken branch each. Clobbers t0. */
    .macro spin n
    li   t0, \n
9:  addi t0, t0, -1
    bnez t0, 9b
    .endm

main:
    RVIRQ_INIT
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)
    la   t0, handler
    csrw mtvec, t0
    csrr t0, CSR_MHPMEVENT3H
    bnez t0, fail1                # OF and MINH start at zero
    li   t0, EVENT_BRANCH
    csrw CSR_MHPMEVENT3, t0
    arm  40
    li   t0, LCOFI_BIT
    csrs mie, t0
    csrr t0, mie
    li   t1, LCOFI_BIT
    bne  t0, t1, fail2            # LCOFIE is a bit of mie
    csrsi mstatus, 8
    li   t2, 100000
1:  lw   t0, 0(s0)
    bnez t0, 2f
    addi t2, t2, -1
    bnez t2, 1b
    j    fail3                    # the interrupt never came
2:  lw   t0, 0(s0)
    li   t1, 1
    bne  t0, t1, fail4
    lw   t0, 0x100(s0)
    li   t1, CAUSE_LCOFI
    bne  t0, t1, fail5            # mcause of the entry
    lw   t0, 0x104(s0)
    li   t1, OF_BIT
    bne  t0, t1, fail6            # OF is set when the interrupt is taken
    lw   t0, 0x108(s0)
    li   t1, LCOFI_BIT
    bne  t0, t1, fail7            # and so is LCOFIP

    // OF is still set: another overflow asks for nothing
    arm  20
    spin 200
    lw   t0, 0(s0)
    li   t1, 1
    bne  t0, t1, fail8
    csrr t0, mip
    li   t1, LCOFI_BIT
    and  t0, t0, t1
    bnez t0, fail9
    csrr t0, CSR_MHPMEVENT3H
    li   t1, OF_BIT
    bne  t0, t1, fail10           # OF stays until software clears it

    // clear OF and arm again: the interrupt comes a second time
    csrw CSR_MHPMEVENT3H, x0
    arm  20
    li   t2, 100000
3:  lw   t0, 0(s0)
    li   t1, 2
    bgeu t0, t1, 4f
    addi t2, t2, -1
    bnez t2, 3b
    j    fail11
4:  lw   t0, 0x10C(s0)
    li   t1, CAUSE_LCOFI
    bne  t0, t1, fail12

    // LCOFIE clear: the request stays in mip and nothing is taken
    li   t0, LCOFI_BIT
    csrc mie, t0
    csrw CSR_MHPMEVENT3H, x0
    arm  20
    spin 200
    lw   t0, 0(s0)
    li   t1, 2
    bne  t0, t1, fail13
    csrr t0, mip
    li   t1, LCOFI_BIT
    and  t0, t0, t1
    beqz t0, fail14
    // and it is taken as soon as the mask is set
    li   t0, LCOFI_BIT
    csrs mie, t0
    nop
    nop
    lw   t0, 0(s0)
    li   t1, 3
    bne  t0, t1, fail15

    // MINH: the counter stops
    li   t0, MINH_BIT
    csrw CSR_MHPMEVENT3H, t0
    arm  20
    spin 100
    csrr t0, CSR_MHPMCOUNTER3
    li   t1, -20
    bne  t0, t1, fail16
    csrr t0, CSR_MHPMEVENT3H
    li   t1, MINH_BIT
    bne  t0, t1, fail17
    RVMODEL_HALT_PASS
fail1:
    RVMODEL_HALT_FAIL(1)
fail2:
    RVMODEL_HALT_FAIL(2)
fail3:
    RVMODEL_HALT_FAIL(3)
fail4:
    RVMODEL_HALT_FAIL(4)
fail5:
    RVMODEL_HALT_FAIL(5)
fail6:
    RVMODEL_HALT_FAIL(6)
fail7:
    RVMODEL_HALT_FAIL(7)
fail8:
    RVMODEL_HALT_FAIL(8)
fail9:
    RVMODEL_HALT_FAIL(9)
fail10:
    RVMODEL_HALT_FAIL(10)
fail11:
    RVMODEL_HALT_FAIL(11)
fail12:
    RVMODEL_HALT_FAIL(12)
fail13:
    RVMODEL_HALT_FAIL(13)
fail14:
    RVMODEL_HALT_FAIL(14)
fail15:
    RVMODEL_HALT_FAIL(15)
fail16:
    RVMODEL_HALT_FAIL(16)
fail17:
    RVMODEL_HALT_FAIL(17)

/* Logs mcause, mhpmevent3h and mip of entry k at RV32_RAM_BASE + 0x100 + 12k, counts the entry in
 * RV32_RAM_BASE + 0 and acknowledges LCOFIP in mip. It uses t3 to t6 only. */
    .balign 4
handler:
    li   t5, RV32_RAM_BASE
    lw   t6, 0(t5)
    slli t4, t6, 2
    slli t3, t6, 3
    add  t4, t4, t3
    add  t4, t4, t5
    csrr t3, mcause
    sw   t3, 0x100(t4)
    csrr t3, CSR_MHPMEVENT3H
    sw   t3, 0x104(t4)
    csrr t3, mip
    sw   t3, 0x108(t4)
    addi t6, t6, 1
    sw   t6, 0(t5)
    li   t3, LCOFI_BIT
    csrc mip, t3
    mret
