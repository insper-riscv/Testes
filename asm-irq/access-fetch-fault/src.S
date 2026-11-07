// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Falha de acesso de instrução (causa 1): a busca numa janela vazia do barramento de periféricos e numa região sem
// memória do mapa trapa com mepc e mtval no endereço da busca, antes da decodificação (a palavra buscada, que o
// modelo devolve como zero, seria uma instrução ilegal). O tratador volta a um rótulo guardado em s2.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    RVIRQ_INIT
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)
    la   t0, handler
    csrw mtvec, t0
    li   s3, RV32_EMPTY_SLOT
    li   s4, RV32_HOLE_ADDR
    la   s2, back1
    jalr x0, 0(s3)                # salta para a janela vazia
back1:
    la   s2, back2
    jalr x0, 0(s4)                # e para a região sem memória
back2:
    lw   t0, 0(s0)
    li   t2, 2
    bne  t0, t2, fail1            # exatamente dois traps
    lw   t0, 0x100(s0)
    li   t2, 1
    bne  t0, t2, fail2
    lw   t0, 0x104(s0)
    bne  t0, s3, fail3            # mepc = endereço da busca
    lw   t0, 0x108(s0)
    bne  t0, s3, fail4            # mtval = endereço da busca
    lw   t0, 0x10C(s0)
    li   t2, 1
    bne  t0, t2, fail5
    lw   t0, 0x110(s0)
    bne  t0, s4, fail6
    lw   t0, 0x114(s0)
    bne  t0, s4, fail7
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

/* Registra mcause, mepc e mtval do trap k em RV32_RAM_BASE + 0x100 + 12k e retoma: depois da instrução, ou, na falha de
 * busca (causa 1), no endereço guardado em s2. Usa t3 a t6 só. */
    .balign 4
handler:
    li   t5, RV32_RAM_BASE
    lw   t6, 0(t5)
    slli t4, t6, 3
    slli t3, t6, 2
    add  t4, t4, t3
    add  t4, t4, t5
    csrr t3, mcause
    sw   t3, 0x100(t4)
    csrr t3, mepc
    sw   t3, 0x104(t4)
    csrr t3, mtval
    sw   t3, 0x108(t4)
    addi t6, t6, 1
    sw   t6, 0(t5)
    csrr t3, mcause
    li   t4, 1
    beq  t3, t4, 1f
    csrr t3, mepc
    addi t3, t3, 4
    csrw mepc, t3
    mret
1:  csrw mepc, s2
    mret
