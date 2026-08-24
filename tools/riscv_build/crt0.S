/* Minimal bare-metal startup. RAM starts blank on real hardware (only
 * ROM gets preloaded via JTAG/the .mif), so any initialized globals
 * (.data) have to be copied out of ROM by hand, and .bss zeroed,
 * before main() can rely on them. */
.section .text.start
.global _start
_start:
    la sp, _stack_top

    /* mailbox_addr and go_flag_addr both live just past LENGTH(RAM)
     * (see link.ld), specifically so the .bss zero loop below never
     * reaches them — which also means it never CLEARS them. The host
     * polls mailbox_addr for this run's result and pulses go_flag_addr
     * to trigger a restart (build_fpga.py / rv32_test.h); both must
     * start clean on every entry to _start, cold boot or restart,
     * or a restart would either loop forever (go_flag still set) or
     * report the previous test's stale mailbox value. */
    lui  t0, 0x4
    sw   x0, -4(t0)         // mailbox_addr = 0x3FFC
    sw   x0, -8(t0)         // go_flag_addr  = 0x3FF8

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

    call main
    /* main() returning (shouldn't normally happen for our tests)
     * falls straight into the same restart wait RV32_PASS/RV32_FAIL
     * use below. */

/* Lets build_fpga.py re-run a *different* program on this same,
 * already-configured bitstream: JTAG-write a new ROM image, then
 * write a nonzero word to go_flag_addr (config.yaml memory section;
 * 0x00003FF8 here) without reprogramming the FPGA. A core sitting in
 * this loop notices and jumps back to _start, which clears both
 * mailbox_addr and go_flag_addr itself (see above) before running the
 * new program — so no cleanup is needed between runs. */
.global rv32_wait_restart
rv32_wait_restart:
    lui  t0, 0x4
    lw   t1, -8(t0)         // go_flag_addr = 0x3FF8
    beqz t1, rv32_wait_restart
    j    _start
