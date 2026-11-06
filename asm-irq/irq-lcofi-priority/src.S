// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Sscofpmf: the counter-overflow interrupt (cause 13) has the lowest priority of the machine interrupts.
// With the timer and the overflow pending together and mtvec in vectored mode, the timer interrupt enters at
// BASE + 28 first and the overflow at BASE + 52 right after it, both over the same instruction.
#include "rv32_platform.h"

#define CSR_MHPMEVENT3    0x323
#define CSR_MHPMCOUNTER3  0xB03
#define CSR_MHPMCOUNTER3H 0xB83
#define LCOFI_BIT         0x2000
#define EVENT_BRANCH      3

    .section .text
    .globl main

main:
    RVIRQ_INIT
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)
    la   s1, vectors              # 64-byte aligned
    ori  t0, s1, 1
    csrw mtvec, t0
    li   t0, EVENT_BRANCH
    csrw CSR_MHPMEVENT3, t0
    li   t0, -10
    csrw CSR_MHPMCOUNTER3, t0
    li   t0, -1
    csrw CSR_MHPMCOUNTER3H, t0
    li   t0, RV32_MIE_MTIE | LCOFI_BIT
    csrs mie, t0
    li   t2, 100000
1:  csrr t0, mip
    li   t1, LCOFI_BIT
    and  t0, t0, t1
    bnez t0, 2f                   # the overflow is pending (the loop makes the taken branches)
    addi t2, t2, -1
    bnez t2, 1b
    j    fail1
2:  RVIRQ_TIMER_AFTER(10)
    li   t2, 100000
3:  csrr t0, mip
    andi t0, t0, RV32_MIE_MTIE
    bnez t0, 4f
    addi t2, t2, -1
    bnez t2, 3b
    j    fail2
4:  csrsi mstatus, 8              # both are pending now
site:
    addi s2, x0, 7
    lw   t0, 0(s0)
    li   t1, 2
    bne  t0, t1, fail3
    lw   t0, 0x100(s0)
    li   t1, 7
    bne  t0, t1, fail4            # the timer entry came first
    lw   t0, 0x104(s0)
    li   t1, 13
    bne  t0, t1, fail5            # the overflow second
    lw   t0, 0x108(s0)
    lw   t1, 0x10C(s0)
    bne  t0, t1, fail6            # both over the same mepc
    la   t1, site
    bltu t0, t1, fail6
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

    .balign 64
vectors:
    j    entry_bad                # 0
    j    entry_bad
    j    entry_bad
    j    entry_bad                # 3
    j    entry_bad
    j    entry_bad
    j    entry_bad
    j    entry_timer              # 7: BASE + 28
    j    entry_bad
    j    entry_bad
    j    entry_bad
    j    entry_bad                # 11
    j    entry_bad
    j    entry_lcofi              # 13: BASE + 52
    j    entry_bad
    j    entry_bad

/* Each entry logs its cause at RV32_RAM_BASE + 0x100 + 4k and its mepc at + 0x108 + 4k. t3 to t6 only. */
    .macro log_entry id
    li   t5, RV32_RAM_BASE
    lw   t6, 0(t5)
    slli t4, t6, 2
    add  t4, t4, t5
    li   t3, \id
    sw   t3, 0x100(t4)
    csrr t3, mepc
    sw   t3, 0x108(t4)
    addi t6, t6, 1
    sw   t6, 0(t5)
    .endm

    .balign 4
entry_timer:
    log_entry 7
    RVIRQ_TIMER_OFF(t5, t6)
    mret
entry_lcofi:
    log_entry 13
    li   t3, LCOFI_BIT
    csrc mip, t3
    mret
entry_bad:
    log_entry 0xFF
    RVIRQ_TIMER_OFF(t5, t6)
    li   t3, LCOFI_BIT
    csrc mip, t3
    mret
