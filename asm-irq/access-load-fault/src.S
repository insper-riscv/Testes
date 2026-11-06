// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Falha de acesso de load (causa 5): um load numa região sem memória do mapa e numa janela vazia do barramento de
// periféricos trapa com mepc no load e mtval no endereço, e não escreve o registrador destino. A leitura da ROM e
// da RAM continua legal, e um load desalinhado fora do mapa dá a falha de acesso e não o desalinhamento.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    RVIRQ_INIT
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)
    la   t0, handler
    csrw mtvec, t0
    li   s3, RV32_HOLE_ADDR
    li   s4, RV32_EMPTY_SLOT
    li   s5, RV32_ROM_ADDR
    li   a1, 0x11111111
    li   a2, 0x22222222
    li   a3, 0x33333333
site_hole:
    lw   a1, 0(s3)                # load em região sem memória
site_slot:
    lh   a2, 0(s4)                # load numa janela de periférico vazia
site_mis:
    lw   a3, 1(s3)                # desalinhado fora do mapa: falha de acesso, não a causa 4
site_rom:
    lw   t1, 0(s5)                # a ROM aceita leitura
    addi s6, s0, 0x80
    sw   s6, 0(s6)
site_ok:
    lw   t2, 0(s6)                # a RAM também
    bne  t2, s6, fail1
    li   t2, 0x11111111
    bne  a1, t2, fail2            # o destino não foi escrito
    li   t2, 0x22222222
    bne  a2, t2, fail3
    li   t2, 0x33333333
    bne  a3, t2, fail4
    lw   t0, 0(s0)
    li   t2, 3
    bne  t0, t2, fail5            # exatamente três traps
    lw   t0, 0x100(s0)
    li   t2, 5
    bne  t0, t2, fail6
    lw   t0, 0x104(s0)
    la   t2, site_hole
    bne  t0, t2, fail7
    lw   t0, 0x108(s0)
    bne  t0, s3, fail8
    lw   t0, 0x10C(s0)
    li   t2, 5
    bne  t0, t2, fail9
    lw   t0, 0x110(s0)
    la   t2, site_slot
    bne  t0, t2, fail10
    lw   t0, 0x114(s0)
    bne  t0, s4, fail11
    lw   t0, 0x118(s0)
    li   t2, 5
    bne  t0, t2, fail12           # a falha de acesso vence o desalinhamento
    lw   t0, 0x11C(s0)
    la   t2, site_mis
    bne  t0, t2, fail13
    lw   t0, 0x120(s0)
    addi t2, s3, 1
    bne  t0, t2, fail14
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
