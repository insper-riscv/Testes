// RV32_EXT: M,Zicsr,Zimop
// RV32_TEST_KIND: memory
//
// Zimop: the 8 encodings of mop.rr.n (n = 0 to 7) write zero to rd and never trap.
// Each n runs in three forms, and the value stored after it is the result:
//  a. rd = x6 holds 0x5A5A5A5A before the MOP, the sources are x5 and x9 (nonzero): the result is 0;
//  b. rd = rs1 = rs2 = x8, which holds a nonzero value: the result is 0;
//  c. rd = x0: no register is written, so x0 still reads zero and the next instruction, which
//     reads x0 right behind the MOP, gets zero: x7 = x0 | x5 = x5.
// A trap handler counts the exceptions and skips the instruction; the count (the last word) is 0
// because the extension makes the MOP legal.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   x20, RV32_RAM_BASE       # x20 = RESULTS_BASE, advances 4 bytes per result
    li   x30, 0                   # exception count
    la   x6, handler
    csrw mtvec, x6
    li   x5, 0xA5A5A5A5           # nonzero source
    li   x9, 0x3C3C3C3C           # nonzero second source
    .irp n, 0,1,2,3,4,5,6,7
    li   x6, 0x5A5A5A5A
    mop.rr.\n x6, x5, x9
    sw   x6, 0(x20)
    li   x8, 0x5A5A5A5A
    mop.rr.\n x8, x8, x8
    sw   x8, 4(x20)
    mop.rr.\n x0, x5, x9
    or   x7, x0, x5
    sw   x7, 8(x20)
    addi x20, x20, 12
    .endr

    sw   x30, 0(x20)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS

    # Counts the exception and resumes after the faulting instruction.
handler:
    addi x30, x30, 1
    csrr x31, mepc
    addi x31, x31, 4
    csrw mepc, x31
    mret
