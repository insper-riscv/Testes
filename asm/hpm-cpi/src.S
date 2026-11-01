// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: memory
//
// Decomposition of the CPI with the event counters. A kernel of 100 iterations has a load followed
// by its use, a division and a loop branch. The cycles it takes are explained by the instructions
// retired plus the cycles the counters attribute to the divider (event 1), to the taken branches
// (event 3, BRANCH_PENALTY cycles each), to the load-use stalls (event 8) and to the waits for the
// external memory (event 2), one pulse per stalled cycle. The program checks that this sum is within
// 1% of the cycles measured with mcycle (the block runs twice and the second pass counts, so that
// a slow instruction memory does not add misses to it) and stores the flags: the sum is within 1%, and each of the
// first three events moved. The counts themselves depend on the memory behind the core.
#include "rv32_platform.h"

    .equ BRANCH_PENALTY, 2

    .section .text
    .globl main

main:
    li   x5, RV32_RAM_BASE        # x5 = RESULTS_BASE
    li   x6, 1
    csrw 0x323, x6                # counter 3 = muldiv stall
    li   x6, 3
    csrw 0x324, x6                # counter 4 = taken branch
    li   x6, 8
    csrw 0x325, x6                # counter 5 = load-use
    li   x6, 2
    csrw 0x326, x6                # counter 6 = external memory wait
    addi x20, x5, 64
    sw   x0, 0(x20)
    li   x11, 1000
    li   x12, 7

    li   x4, 2                    # two passes: the first fills the caches of a slow memory
0:  li   x7, 100
    csrr x13, 0xB03
    csrr x14, 0xB04
    csrr x15, 0xB05
    csrr x16, 0xB06
    csrr x17, 0xC02
    csrr x8, 0xC00
    jal  ra, kernel
    csrr x18, 0xC00
    csrr x19, 0xC02
    csrr x28, 0xB03
    csrr x29, 0xB04
    csrr x30, 0xB05
    csrr x31, 0xB06
    addi x4, x4, -1
    bnez x4, 0b                   # the second pass is the one measured

    sub  x18, x18, x8             # cycles
    sub  x19, x19, x17            # instret
    sub  x28, x28, x13            # muldiv stall cycles
    sub  x29, x29, x14            # taken branches
    sub  x30, x30, x15            # load-use cycles
    sub  x31, x31, x16            # external wait cycles
    add  x6, x19, x28
    add  x6, x6, x30
    add  x6, x6, x31
    li   x7, BRANCH_PENALTY
    mul  x7, x7, x29
    add  x6, x6, x7               # modelled cycles
    sub  x6, x18, x6
    srai x7, x6, 31
    xor  x6, x6, x7
    sub  x6, x6, x7               # |cycles - model|
    li   x7, 100
    mul  x6, x6, x7               # 100 * error
    sltu x6, x18, x6              # x6 = 1: the error is above 1% of the cycles
    xori x6, x6, 1                # x6 = 1: within 1%
    sltu x7, x0, x28              # the divider moved
    sltu x8, x0, x29              # the branches moved
    sltu x9, x0, x30              # the load-use stalls moved
    sw   x6, 0(x5)
    sw   x7, 4(x5)
    sw   x8, 8(x5)
    sw   x9, 12(x5)

    # End of the test: tohost = 1 (HTIF pass), then wait for the host.
    RVMODEL_HALT_PASS

# The kernel: x7 iterations of a load and its use, a division and a loop branch.
kernel:
1:  lw   x21, 0(x20)
    add  x22, x21, x22            # load-use
    div  x23, x11, x12
    addi x7, x7, -1
    bnez x7, 1b
    ret
