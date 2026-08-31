/* Minimal bare-metal startup. RAM starts blank on real hardware (only
 * ROM gets preloaded via JTAG/the .mif), so any initialized globals
 * (.data) have to be copied out of ROM by hand, and .bss zeroed,
 * before main() can rely on them. */
.section .text.start
.global _start
_start:
    /* gp (x3) MUST be set before anything else — including `la sp`
     * below — because once it's valid, the assembler/linker are free
     * to RELAX any later `la reg, symbol` whose target falls within
     * gp's +/-0x800 reach into a single gp-relative load instead of
     * the usual two-instruction auipc+addi sequence. An uninitialized
     * gp turns that optimization into a load/store through a garbage
     * address instead of a slow instruction — see
     * docs/SMALL_DATA_SECTION_BUG.md for exactly this failure mode
     * (found via .data's small-data half, .sdata, silently landing
     * outside the range crt0.S copied — same root cause, gp was never
     * initialized here at all until this fix). `.option norelax`
     * wraps the sequence itself so the auipc+addi pair that COMPUTES
     * gp doesn't get relaxed to depend on gp before it's set —
     * standard RISC-V psABI idiom, see
     * https://github.com/riscv-non-isa/riscv-elf-psabi-doc. */
    .option push
    .option norelax
1:  auipc gp, %pcrel_hi(__global_pointer$)
    addi  gp, gp, %pcrel_lo(1b)
    .option pop

    /* tp (x4, thread pointer) isn't exercised by anything in this
     * project today — no test declares a `__thread`/`_Thread_local`
     * variable, confirmed by grepping every compiled test's ELF for
     * .tdata/.tbss (see docs/SMALL_DATA_SECTION_BUG.md) — but it's
     * the exact same class of bug as gp above waiting to happen the
     * day someone adds one: RISC-V's TLS access sequence
     * (%tprel_hi/%tprel_add/%tprel_lo) trusts tp unconditionally, no
     * warning if it's garbage. Set it up now while nothing depends on
     * getting it wrong yet. RISC-V uses TLS "Variant I": tp points
     * one PAST the end of the Thread Control Block; this bare-metal
     * setup has no real TCB (no dynamic linking, no DTV — that's only
     * needed for the general-dynamic TLS model), so its size is 0 and
     * tp simply equals the TLS block's own start (_tls_base, see
     * link.ld's .tdata/.tbss). */
    la tp, _tls_base

    la sp, _stack_top

    /* mailbox_addr and go_flag_addr both live just past LENGTH(RAM)
     * (see link.ld), specifically so the .bss zero loop below never
     * reaches them — which also means it never CLEARS them. The host
     * polls mailbox_addr for this run's result and pulses go_flag_addr
     * to trigger a restart (build_fpga.py / rv32_test.h); both must
     * start clean on every entry to _start, cold boot or restart,
     * or a restart would either loop forever (go_flag still set) or
     * report the previous test's stale mailbox value. */
    lui  t0, 0x20
    sw   x0, -4(t0)         // mailbox_addr = 0x1FFFC
    sw   x0, -8(t0)         // go_flag_addr  = 0x1FFF8

    /* HTIF's tohost/fromhost (link.ld) get the same "start clean on
     * every _start entry" treatment — Spike treats any nonzero tohost
     * as "test finished", so a stale value here would make the very
     * next test's run under Spike look instantly done. Real linker
     * symbols (not a fixed offset like mailbox/go_flag above), so
     * loaded via `la`. */
    la   t3, tohost
    sw   x0, 0(t3)
    sw   x0, 4(t3)
    la   t3, fromhost
    sw   x0, 0(t3)
    sw   x0, 4(t3)

    /* .data: copy from its ROM load address to its RAM run address */
    la t0, _data_load
    la t1, _data_start
    la t2, _data_end
1:
    bge t1, t2, 2f
    lw  t3, 0(t0)
    sw  t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j   1b
2:

    /* .bss: zero it */
    la t1, _bss_start
    la t2, _bss_end
3:
    bge t1, t2, 4f
    sw  x0, 0(t1)
    addi t1, t1, 4
    j   3b
4:

    /* .tdata/.tbss: same copy-then-zero treatment as .data/.bss above
     * — currently always empty (nothing uses TLS, see the tp comment
     * above), so both loops run zero iterations today. Kept for when
     * that stops being true, so a future __thread variable gets
     * correctly initialized instead of silently landing in
     * uninitialized RAM the way .data's small-data half did before
     * this fix. */
    la t0, _tdata_load
    la t1, _tdata_start
    la t2, _tdata_end
5:
    bge t1, t2, 6f
    lw  t3, 0(t0)
    sw  t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j   5b
6:

    la t1, _tbss_start
    la t2, _tbss_end
7:
    bge t1, t2, 8f
    sw  x0, 0(t1)
    addi t1, t1, 4
    j   7b
8:

    call main
    /* main() returning (shouldn't normally happen for our tests)
     * falls straight into the same restart wait RV32_PASS/RV32_FAIL
     * use below. */

/* Lets build_fpga.py re-run a *different* program on this same,
 * already-configured bitstream: JTAG-write a new ROM image, then
 * write a nonzero word to go_flag_addr (config.yaml memory section;
 * 0x0001FFF8 here) without reprogramming the FPGA. A core sitting in
 * this loop notices and jumps back to _start, which clears both
 * mailbox_addr and go_flag_addr itself (see above) before running the
 * new program — so no cleanup is needed between runs.
 *
 * Every test funnels through here exactly once per run — whether via
 * RV32_PASS()/RV32_FAIL() (rv32_test.h) or a raw-asm test writing the
 * mailbox by hand and jumping here directly (see
 * test_section6_loadstore.S) — so this is also the one place that
 * translates our mailbox convention into HTIF's tohost convention for
 * Spike (see link.ld and mem_validator.generate_golden in the Tools
 * repo): 1 = pass, 3 = fail ((1 << 1) | 1). Harmless on real
 * hardware — nothing there reads tohost. */
.global rv32_wait_restart
rv32_wait_restart:
    lui  t0, 0x20
    lw   t1, -4(t0)          // mailbox_addr = 0x1FFFC
    li   t2, 1
    li   t3, 1                // HTIF pass
    beq  t1, t2, 1f
    li   t3, 3                // HTIF fail
1:
    la   t4, tohost
    sw   t3, 0(t4)

rv32_wait_restart_poll:
    lw   t1, -8(t0)           // go_flag_addr = 0x1FFF8
    beqz t1, rv32_wait_restart_poll
    j    _start
