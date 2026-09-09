/* crt0.S -- emits .flash_entry, the tiny trampoline that hands this
 * test's own boot-time constants to the fixed, shared boot_rom.S.
 *
 * All the actual startup WORK (the .data copy loop, .bss zero loop,
 * mailbox/go_flag/tohost/fromhost clear) lives in boot_rom.S, which
 * is programmed into BOOT_ROM once and never JTAG-rewritten per test
 * -- see its own header comment. Since BOOT_ROM can't see THIS test's
 * own linker symbols (a different test's .data/.bss bounds and
 * __global_pointer$ value are all different), and — critically — the
 * MEM stage has no data path to FLASH at all anymore (only RAM,
 * see rv32im_pipeline_core.vhd), this trampoline can't just leave a
 * data table for boot_rom.S to `lw`. Instead it's CODE: plain
 * instruction fetch (IF stage only) loads this test's own bounds
 * into registers, then jumps into boot_rom.S's _boot_continue (a
 * FIXED address, see boot_rom_symbols.ld, INCLUDEd by link.ld) to
 * finish the job using them.
 *
 * .option norelax: none of gp/sp/etc are valid registers yet at this
 * point, so `la` must NOT get relaxed into a (currently garbage)
 * gp-relative load — same hazard/idiom the old crt0.S already used
 * for its own gp setup (see docs/SMALL_DATA_SECTION_BUG.md).
 *
 * rv32_wait_restart no longer lives here either -- it's in boot_rom.S
 * too, referenced (by RV32_PASS()/RV32_FAIL(), rv32_test.h) via
 * link.ld's `INCLUDE boot_rom_symbols.ld`.
 */
    .section .flash_entry, "ax"
    .global _flash_entry
_flash_entry:
    .option push
    .option norelax
    la   t1, _data_load
    la   t2, _data_start
    la   t3, _data_end
    la   t4, _bss_start
    la   t5, _bss_end
    la   gp, __global_pointer$   // gp's VALUE is __global_pointer$'s own address
    la   t6, main
    .option pop
    j    _boot_continue
