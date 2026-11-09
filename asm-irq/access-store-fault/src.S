// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Falha de acesso de store (causa 7): um store na ROM (BOOT_MEMORY ou FLASH, só de leitura), numa região sem
// memória do mapa e numa janela vazia do barramento de periféricos trapa com mepc no store e mtval no endereço,
// e não escreve (a ROM e a RAM seguem intactas). Um store em RAM válida continua funcionando.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    RVIRQ_INIT
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)
    la   t0, handler
    csrw mtvec, t0
    li   t1, 0x5A5A5A5A
    li   s3, RV32_ROM_ADDR
site_rom:
    sw   t1, 0(s3)                # store em ROM
    li   s4, RV32_HOLE_ADDR
site_hole:
    sw   t1, 0(s4)                # store em região sem memória
    li   s5, RV32_EMPTY_SLOT
site_slot:
    sb   t1, 0(s5)                # store numa janela de periférico vazia (byte)
    addi s6, s0, 0x80
site_ok:
    sw   t1, 0(s6)                # store em RAM válida: não trapa
    lw   t2, 0(s6)
    bne  t1, t2, fail1
    lw   t0, 0(s0)
    li   t2, 3
    bne  t0, t2, fail2            # exatamente três traps
    lw   t0, 0x100(s0)
    li   t2, 7
    bne  t0, t2, fail3
    lw   t0, 0x104(s0)
    la   t2, site_rom
    bne  t0, t2, fail4
    lw   t0, 0x108(s0)
    bne  t0, s3, fail5            # mtval = endereço do store
    lw   t0, 0x10C(s0)
    li   t2, 7
    bne  t0, t2, fail6
    lw   t0, 0x110(s0)
    la   t2, site_hole
    bne  t0, t2, fail7
    lw   t0, 0x114(s0)
    bne  t0, s4, fail8
    lw   t0, 0x118(s0)
    li   t2, 7
    bne  t0, t2, fail9
    lw   t0, 0x11C(s0)
    la   t2, site_slot
    bne  t0, t2, fail10
    lw   t0, 0x120(s0)
    bne  t0, s5, fail11
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

/* Registra mcause, mepc e mtval do trap k em RV32_RAM_BASE + 0x100 + 12k e retoma depois da instrução. t3 a t6 só. */
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
    csrr t3, mepc
    addi t3, t3, 4
    csrw mepc, t3
    mret
