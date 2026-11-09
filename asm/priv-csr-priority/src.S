// RV32_EXT: M,Zicsr
// RV32_TEST_KIND: unit
//
// Volume privilegiado, M-mode: a ordem das exceções da Tabela 17 e o espaço dos CSRs. Um JALR ou um desvio de
// codificação reservada com alvo desalinhado gera a causa 2 (instrução ilegal), nunca a 0, e o salto legal com
// alvo desalinhado gera a causa 0 com mtval igual ao alvo. Os CSRs do bloco de depuração (0x7B0 a 0x7BF) e a
// escrita em CSR de identificação geram a causa 2; a leitura deles é legal. mhartid vale zero, misa anuncia RV32
// e a base I ou E, mstatush ignora a escrita, mepc tem os dois bits baixos em zero e o bit 1 de mtvec lê zero.
// O mtval da causa 2 fica sem conferência: o manual deixa zero ou a palavra da instrução à escolha da implementação.
#include "rv32_platform.h"

    .section .text
    .globl main

main:
    li   s0, RV32_RAM_BASE
    sw   x0, 0(s0)                # contagem de traps
    la   t0, handler
    csrw mtvec, t0

    // identificação e campos WARL
    csrr t0, mhartid
    bnez t0, fail1                # um hart, de número zero
    csrr t0, misa
    srli t1, t0, 30
    li   t2, 1
    bne  t1, t2, fail2            # MXL = 1 (RV32)
    srli t1, t0, 4
    srli t2, t0, 8
    xor  t1, t1, t2
    andi t1, t1, 1
    beqz t1, fail3                # exatamente um entre E (bit 4) e I (bit 8)
    csrr t0, mstatush
    bnez t0, fail4
    li   t0, -1
    csrw mstatush, t0
    csrr t0, mstatush
    bnez t0, fail5                # a escrita é ignorada
    li   t0, -1
    csrw mepc, t0
    csrr t0, mepc
    andi t0, t0, 3
    bnez t0, fail8                # IALIGN = 32: mepc[1:0] em zero
    la   t0, handler
    ori  t0, t0, 3
    csrw mtvec, t0
    csrr t0, mtvec
    andi t0, t0, 2
    bnez t0, fail9                # o bit 1 de mtvec lê zero (modo reservado)
    la   t0, handler
    csrw mtvec, t0

    // exceções: cada caso é uma instrução cujo endereço, causa e mtval o tratador registra
    li   a4, 6                    # x14: valor com o bit 1 aceso, alvo desalinhado dos saltos
    li   a5, 7                    # x15: valor diferente de a4
site_jalr_f1:
    .word 0x00071067               # jalr com funct3 = 001 e alvo 6 (a4)
site_jalr_f7:
    .word 0x00077067               # jalr com funct3 = 111 e alvo 6
site_br_f2_eq:
    .word 0x00E72363               # desvio funct3 = 010, rs1 = rs2, deslocamento 6
site_br_f2_ne:
    .word 0x00F72363               # desvio funct3 = 010, rs1 != rs2
site_br_f3_eq:
    .word 0x00E73363               # desvio funct3 = 011, rs1 = rs2
site_br_f3_ne:
    .word 0x00F73363               # desvio funct3 = 011, rs1 != rs2
site_jalr_ok:
    jalr x0, 2(x0)                # salto legal ao endereço 2
site_beq_ok:
    beq  x0, x0, .+6              # desvio legal tomado, alvo desalinhado
site_dbg0:
    csrr a3, 0x7B0               # CSR do bloco de depuração
site_dbg1:
    csrr a3, 0x7B1               # CSR do bloco de depuração
site_dbg2:
    csrr a3, 0x7B2               # CSR do bloco de depuração
site_dbg3:
    csrr a3, 0x7B3               # CSR do bloco de depuração
site_dbg4:
    csrr a3, 0x7B4               # CSR do bloco de depuração
site_dbg5:
    csrr a3, 0x7BF               # CSR do bloco de depuração
site_wr_hartid:
    csrrw x0, mhartid, x0         # escrita em CSR somente leitura
site_wr_vendor:
    csrrs x0, mvendorid, a4       # escrita efetiva (rs1 != x0) em CSR somente leitura
    csrrs a3, mvendorid, x0       # leitura sem escrita: legal
    csrrs a3, mhartid, x0
    csrrs a3, misa, x0
    csrrs a3, mstatush, x0

    lw   t0, 0(s0)
    li   t1, 16
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(10)         # número de traps: só as instruções de teste trapam
1:
    lw   t0, 256(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(20)         # jalr_f1: mcause
1:  lw   t0, 260(s0)
    la   t1, site_jalr_f1
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(21)         # jalr_f1: mepc
1:
    lw   t0, 268(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(23)         # jalr_f7: mcause
1:  lw   t0, 272(s0)
    la   t1, site_jalr_f7
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(24)         # jalr_f7: mepc
1:
    lw   t0, 280(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(26)         # br_f2_eq: mcause
1:  lw   t0, 284(s0)
    la   t1, site_br_f2_eq
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(27)         # br_f2_eq: mepc
1:
    lw   t0, 292(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(29)         # br_f2_ne: mcause
1:  lw   t0, 296(s0)
    la   t1, site_br_f2_ne
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(30)         # br_f2_ne: mepc
1:
    lw   t0, 304(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(32)         # br_f3_eq: mcause
1:  lw   t0, 308(s0)
    la   t1, site_br_f3_eq
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(33)         # br_f3_eq: mepc
1:
    lw   t0, 316(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(35)         # br_f3_ne: mcause
1:  lw   t0, 320(s0)
    la   t1, site_br_f3_ne
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(36)         # br_f3_ne: mepc
1:
    lw   t0, 328(s0)
    li   t1, 0
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(38)         # jalr_ok: mcause
1:  lw   t0, 332(s0)
    la   t1, site_jalr_ok
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(39)         # jalr_ok: mepc
1:  lw   t0, 336(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(40)         # jalr_ok: mtval
1:
    lw   t0, 340(s0)
    li   t1, 0
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(41)         # beq_ok: mcause
1:  lw   t0, 344(s0)
    la   t1, site_beq_ok
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(42)         # beq_ok: mepc
1:  lw   t0, 348(s0)
    la   t1, site_beq_ok
    addi t1, t1, 6
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(43)         # beq_ok: mtval
1:
    lw   t0, 352(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(44)         # dbg0: mcause
1:  lw   t0, 356(s0)
    la   t1, site_dbg0
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(45)         # dbg0: mepc
1:
    lw   t0, 364(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(47)         # dbg1: mcause
1:  lw   t0, 368(s0)
    la   t1, site_dbg1
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(48)         # dbg1: mepc
1:
    lw   t0, 376(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(50)         # dbg2: mcause
1:  lw   t0, 380(s0)
    la   t1, site_dbg2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(51)         # dbg2: mepc
1:
    lw   t0, 388(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(53)         # dbg3: mcause
1:  lw   t0, 392(s0)
    la   t1, site_dbg3
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(54)         # dbg3: mepc
1:
    lw   t0, 400(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(56)         # dbg4: mcause
1:  lw   t0, 404(s0)
    la   t1, site_dbg4
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(57)         # dbg4: mepc
1:
    lw   t0, 412(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(59)         # dbg5: mcause
1:  lw   t0, 416(s0)
    la   t1, site_dbg5
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(60)         # dbg5: mepc
1:
    lw   t0, 424(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(62)         # wr_hartid: mcause
1:  lw   t0, 428(s0)
    la   t1, site_wr_hartid
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(63)         # wr_hartid: mepc
1:
    lw   t0, 436(s0)
    li   t1, 2
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(65)         # wr_vendor: mcause
1:  lw   t0, 440(s0)
    la   t1, site_wr_vendor
    beq  t0, t1, 1f
    RVMODEL_HALT_FAIL(66)         # wr_vendor: mepc
1:
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
fail8:
    RVMODEL_HALT_FAIL(8)
fail9:
    RVMODEL_HALT_FAIL(9)

/* Registra mcause, mepc e mtval do trap k em RV32_RAM_BASE + 0x100 + 12k, conta o trap e retoma depois da instrução.
 * Usa a0 a a3 (a2 salvo em mscratch), e os casos usam a4 e a5 como valores. */
    .balign 4
handler:
    csrw mscratch, a2
    li   a2, RV32_RAM_BASE
    lw   a3, 0(a2)
    slli a1, a3, 3
    slli a0, a3, 2
    add  a1, a1, a0
    add  a1, a1, a2
    csrr a0, mcause
    sw   a0, 0x100(a1)
    csrr a0, mepc
    sw   a0, 0x104(a1)
    csrr a0, mtval
    sw   a0, 0x108(a1)
    addi a3, a3, 1
    sw   a3, 0(a2)
    csrr a0, mepc
    addi a0, a0, 4
    csrw mepc, a0
    csrr a2, mscratch
    mret
