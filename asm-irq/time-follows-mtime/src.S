// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// O CSR time é o sombreamento somente leitura do mtime do CLINT (seção 3.2.1 do volume privilegiado). Escrever o
// mtime pelo barramento muda o que time e timeh leem: a metade alta e a baixa seguem o valor escrito, e uma leitura
// de time entre duas leituras do mtime fica entre as duas. A escrita no próprio time é ilegal.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    RVIRQ_INIT
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)
    la   t0, handler
    csrw mtvec, t0
    li   s1, RV32_MTIME
    li   t0, 7
    sw   t0, 4(s1)                # mtime = 7:0x00001000 (metade alta primeiro, como o porte do FreeRTOS)
    li   t0, 0x1000
    sw   t0, 0(s1)
    csrr t1, timeh
    li   t2, 7
    bne  t1, t2, fail1            # timeh segue a escrita
    csrr t1, time
    li   t2, 0x1000
    bltu t1, t2, fail2
    li   t2, 0x1200
    bgeu t1, t2, fail3            # e time também, com pouco atraso
    li   t0, 0xFFFFFFF0           # a volta da metade baixa: o time acompanha
    sw   t0, 0(s1)
    li   s3, 40
wait_wrap:
    addi s3, s3, -1
    bnez s3, wait_wrap
    csrr t1, timeh
    li   t2, 8
    bne  t1, t2, fail4
    csrr t1, time                # leitura entre duas do mtime
    lw   t2, 0(s1)
    csrr t3, time
    bltu t2, t1, fail5
    bltu t3, t2, fail6
    csrw time, x0                 # escrita no time: instrução ilegal
    lw   t0, 0(s0)
    li   t2, 1
    bne  t0, t2, fail7
    lw   t0, 0x100(s0)
    li   t2, 2
    bne  t0, t2, fail8
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
