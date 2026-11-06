/* The macros of the PLIC programs (asm-plic/ and asm-plic-de0-cv/), for assembly. The platform header defines the
 * addresses (RV32_RAM_BASE, RV32_TOHOST, RV32_FROMHOST, RV32_PLIC_*, RV32_MIE_MEIE) and includes this file. */
#ifndef RV32_PLIC_MACROS_H
#define RV32_PLIC_MACROS_H

#ifdef __ASSEMBLER__
/* How an assembly test ends, with the names of the riscv-arch-test model. tohost = 1 is a pass,
 * (code << 1) | 1 a failure with that code. Clobbers t0 and t1. */
#define RVMODEL_HALT_PASS \
    li   t0, RV32_TOHOST; \
    li   t1, 1; \
    sw   t1, 0(t0); \
    sw   x0, 4(t0); \
    tail rv32_wait_restart
#define RVMODEL_HALT_FAIL(code) \
    li   t0, RV32_TOHOST; \
    li   t1, ((code) << 1) | 1; \
    sw   t1, 0(t0); \
    sw   x0, 4(t0); \
    tail rv32_wait_restart

/* Sets the priority of source `id` to the value in register `rv`. Clobbers t0. */
#define RVPLIC_PRIORITY(id, rv) \
    li   t0, RV32_PLIC_PRIORITY + 4 * (id); \
    sw   rv, 0(t0)
/* Writes the enable mask (bit n is source n) held in register `rv`. Clobbers t0. */
#define RVPLIC_ENABLE(rv) \
    li   t0, RV32_PLIC_ENABLE; \
    sw   rv, 0(t0)
/* Writes the threshold held in register `rv`. Clobbers t0. */
#define RVPLIC_THRESHOLD(rv) \
    li   t0, RV32_PLIC_THRESHOLD; \
    sw   rv, 0(t0)
/* Opens the external interrupt: mie.MEIE and mstatus.MIE. Clobbers t0. */
#define RVPLIC_OPEN \
    li   t0, RV32_MIE_MEIE; \
    csrs mie, t0; \
    csrsi mstatus, 8
/* Claims into `rd`: the id of the winning source, or 0. Clobbers t0. */
#define RVPLIC_CLAIM(rd) \
    li   t0, RV32_PLIC_CLAIM; \
    lw   rd, 0(t0)
/* Completes the source held in register `rv`. Clobbers t0. */
#define RVPLIC_COMPLETE(rv) \
    li   t0, RV32_PLIC_CLAIM; \
    sw   rv, 0(t0)
/* Tells the testbench host to do `what` (RV32_HOST_*). Clobbers t0 and t1. */
#define RVHOST(what) \
    li   t0, RV32_FROMHOST; \
    li   t1, what; \
    sw   t1, 0(t0)

/* The handler of the PLIC programs keeps t0 to t4 of the interrupted code in the save area
 * RV32_RAM_BASE + 0x100 (mscratch points to it from the start of main) and leaves t0 holding that
 * area. Between RVPLIC_ENTER and RVPLIC_LEAVE the handler may use t1 to t4 and must not touch t0. */
#define RVPLIC_SAVE   (RV32_RAM_BASE + 0x100)
#define RVPLIC_ENTER \
    csrrw t0, mscratch, t0; \
    sw   t1, 0(t0); \
    sw   t2, 4(t0); \
    sw   t3, 8(t0); \
    sw   t4, 12(t0); \
    csrr t1, mscratch; \
    sw   t1, 16(t0)
#define RVPLIC_LEAVE \
    lw   t1, 0(t0); \
    lw   t2, 4(t0); \
    lw   t3, 8(t0); \
    lw   t4, 12(t0); \
    csrw mscratch, t0; \
    lw   t0, 16(t0); \
    mret
/* The start of main of every program: mtvec, mscratch, the log (s0 = RV32_RAM_BASE, count at +0). */
#define RVPLIC_START \
    la   t0, handler; \
    csrw mtvec, t0; \
    li   t0, RVPLIC_SAVE; \
    csrw mscratch, t0; \
    li   s0, RV32_RAM_BASE; \
    sw   x0, 0(s0)
/* The handler logs the entry k at RV32_RAM_BASE + 0x10 + 8k (the source id, then a word of the service)
 * and bumps the count at +0 last, after the complete. Appends: t1 = id, t2 = extra, t3 and t4 scratch.
 * Leaves the new count in t3. */
#define RVPLIC_LOG \
    li   t3, RV32_RAM_BASE; \
    lw   t4, 0(t3); \
    slli t4, t4, 3; \
    add  t4, t4, t3; \
    sw   t1, 0x10(t4); \
    sw   t2, 0x14(t4)
#define RVPLIC_COUNT \
    li   t3, RV32_RAM_BASE; \
    lw   t4, 0(t3); \
    addi t4, t4, 1; \
    sw   t4, 0(t3)
/* Waits until the handler has run n times in total (the count in s0), up to a bound, or fails. Clobbers
 * s1, t1 and t2. */
#define WAIT_COUNT(n, code) \
    li   s1, 400000; \
8:  lw   t1, 0(s0); \
    li   t2, n; \
    bgeu t1, t2, 9f; \
    addi s1, s1, -1; \
    bnez s1, 8b; \
    RVMODEL_HALT_FAIL(code); \
9:
/* Spends about n loops, for "nothing happens" checks. Clobbers s1. */
#define DELAY(n) \
    li   s1, n; \
7:  addi s1, s1, -1; \
    bnez s1, 7b
/* Fails with `code` unless the word at s0 + off is val. Clobbers t1 and t2. */
#define CHECK(off, val, code) \
    lw   t1, off(s0); \
    li   t2, val; \
    beq  t1, t2, 9f; \
    RVMODEL_HALT_FAIL(code); \
9:
/* Fails with `code` unless (the word at s0 + off) & mask is val. Clobbers t1 and t2. */
#define CHECKM(off, mask, val, code) \
    lw   t1, off(s0); \
    li   t2, mask; \
    and  t1, t1, t2; \
    li   t2, val; \
    beq  t1, t2, 9f; \
    RVMODEL_HALT_FAIL(code); \
9:
/* Closes and opens mstatus.MIE, to arm several sources before any interrupt is taken. */
#define RVPLIC_MIE_OFF csrci mstatus, 8
#define RVPLIC_MIE_ON  csrsi mstatus, 8
#endif

#endif
