/* As macros dos programas do PLIC (asm-plic/ e asm-plic-de0-cv/), para assembly. O cabeçalho da plataforma define
 * os endereços (RV32_RAM_BASE, RV32_TOHOST, RV32_FROMHOST, RV32_PLIC_*, RV32_MIE_MEIE) e inclui este arquivo.
 *
 * Os números ficam em #define (e não em constexpr ou enum) porque o assembly (.S) inclui este arquivo e só o
 * pré-processador os enxerga (ISO/IEC 9899:2024, 6.10); o C de 6.7.2 não é visível ao montador. */
#ifndef RV32_PLIC_MACROS_H
#define RV32_PLIC_MACROS_H

#ifdef __ASSEMBLER__
/* Como um teste em assembly termina, com os nomes do modelo do riscv-arch-test. tohost = 1 é aprovação,
 * (código << 1) | 1 é falha com esse código. Altera t0 e t1. */
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

/* Põe a prioridade da fonte `id` no valor do registrador `rv`. Altera t0. */
#define RVPLIC_PRIORITY(id, rv) \
    li   t0, RV32_PLIC_PRIORITY + 4 * (id); \
    sw   rv, 0(t0)
/* Escreve a máscara de habilitação (o bit n é a fonte n) que está no registrador `rv`. Altera t0. */
#define RVPLIC_ENABLE(rv) \
    li   t0, RV32_PLIC_ENABLE; \
    sw   rv, 0(t0)
/* Escreve o limiar que está no registrador `rv`. Altera t0. */
#define RVPLIC_THRESHOLD(rv) \
    li   t0, RV32_PLIC_THRESHOLD; \
    sw   rv, 0(t0)
/* Abre a interrupção externa: mie.MEIE e mstatus.MIE. Altera t0. */
#define RVPLIC_OPEN \
    li   t0, RV32_MIE_MEIE; \
    csrs mie, t0; \
    csrsi mstatus, 8
/* Reivindica em `rd` o id da fonte vencedora, ou 0. Altera t0. */
#define RVPLIC_CLAIM(rd) \
    li   t0, RV32_PLIC_CLAIM; \
    lw   rd, 0(t0)
/* Completa a fonte que está no registrador `rv`. Altera t0. */
#define RVPLIC_COMPLETE(rv) \
    li   t0, RV32_PLIC_CLAIM; \
    sw   rv, 0(t0)
/* Manda o host do testbench fazer `what` (RV32_HOST_*). Altera t0 e t1. */
#define RVHOST(what) \
    li   t0, RV32_FROMHOST; \
    li   t1, what; \
    sw   t1, 0(t0)

/* O tratador dos programas do PLIC guarda t0 a t4 do código interrompido na área de salvamento
 * RV32_RAM_BASE + 0x100 (o mscratch aponta para ela desde o início de main) e deixa t0 com essa área. Entre
 * RVPLIC_ENTER e RVPLIC_LEAVE o tratador pode usar t1 a t4 e não deve tocar em t0. */
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
/* O início de main de todo programa: mtvec, mscratch e o registro (s0 = RV32_RAM_BASE, contagem em +0). */
#define RVPLIC_START \
    la   t0, handler; \
    csrw mtvec, t0; \
    li   t0, RVPLIC_SAVE; \
    csrw mscratch, t0; \
    li   s0, RV32_RAM_BASE; \
    sw   x0, 0(s0)
/* O tratador registra a entrada k em RV32_RAM_BASE + 0x10 + 8k (o id da fonte e depois uma palavra do
 * atendimento) e incrementa a contagem em +0 por último, depois do complete. Acrescenta: t1 = id, t2 = extra,
 * t3 e t4 de rascunho. Deixa a nova contagem em t3. */
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
/* O limite de WAIT_COUNT em voltas de laço; o cabeçalho da plataforma pode aumentá-lo (na placa, o host que
 * esvazia a UART se conecta segundos depois de o programa começar, enquanto o host da simulação responde de uma
 * vez). */
#ifndef RVPLIC_WAIT_POLLS
#define RVPLIC_WAIT_POLLS 400000
#endif
/* Espera até o tratador ter rodado n vezes no total (a contagem em s0), até um limite, ou falha. Altera
 * s1, t1 e t2. */
#define WAIT_COUNT(n, code) \
    li   s1, RVPLIC_WAIT_POLLS; \
8:  lw   t1, 0(s0); \
    li   t2, n; \
    bgeu t1, t2, 9f; \
    addi s1, s1, -1; \
    bnez s1, 8b; \
    RVMODEL_HALT_FAIL(code); \
9:
/* Gasta cerca de n voltas, para as conferências de "nada acontece". Altera s1. */
#define DELAY(n) \
    li   s1, n; \
7:  addi s1, s1, -1; \
    bnez s1, 7b
/* Falha com `code` a menos que a palavra em s0 + off seja val. Altera t1 e t2. */
#define CHECK(off, val, code) \
    lw   t1, off(s0); \
    li   t2, val; \
    beq  t1, t2, 9f; \
    RVMODEL_HALT_FAIL(code); \
9:
/* Falha com `code` a menos que (a palavra em s0 + off) & mask seja val. Altera t1 e t2. */
#define CHECKM(off, mask, val, code) \
    lw   t1, off(s0); \
    li   t2, mask; \
    and  t1, t1, t2; \
    li   t2, val; \
    beq  t1, t2, 9f; \
    RVMODEL_HALT_FAIL(code); \
9:
/* Fecha e abre o mstatus.MIE, para armar várias fontes antes de qualquer interrupção ser tomada. */
#define RVPLIC_MIE_OFF csrci mstatus, 8
#define RVPLIC_MIE_ON  csrsi mstatus, 8
#endif

#endif
