/* Minimal bare-metal startup. RAM starts blank on real hardware (only
 * ROM gets preloaded via JTAG/the .mif), so any initialized globals
 * (.data) have to be copied out of ROM by hand, and .bss zeroed,
 * before main() can rely on them. There's no OS, so if main() ever
 * returns we just spin — there's nothing sensible left to do. */
.section .text.start
.global _start
_start:
    la sp, _stack_top

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
5:
    j 5b
