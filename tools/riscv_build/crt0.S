/* crt0.S -- emits .flash_header, a 1-word DATA table (no code at all)
 * carrying just this test's own main() address for the fixed, shared
 * boot_rom.S to read.
 *
 * Every other boot-time constant used to live here too (.data/.bss
 * bounds, gp), but link.ld now gives every section a FIXED address
 * and a FIXED size budget, the same for every test -- so those
 * values are the same fixed numbers for every test too, and
 * boot_rom.S hardcodes them directly instead of reading them from
 * here (see its own header comment for the actual numbers). main's
 * address is the one thing that still varies per test, since it
 * depends on where that test's own code lands inside the fixed .text
 * budget.
 *
 * All the actual startup WORK (reading this header, the .data copy
 * loop, .bss zero loop, mailbox/go_flag/tohost/fromhost clear) lives
 * in boot_rom.S, which is programmed into BOOT_ROM once and never
 * JTAG-rewritten per test -- see its own header comment. boot_rom.S
 * reads this header with a plain `lw` from a fixed FLASH address
 * (FLASH_BASE, where .flash_header is placed by link.ld): the MEM
 * stage's second FLASH read port (rv32im_pipeline_core.vhd's
 * flash_addr2/FLASH_MEM) already reaches any FLASH-range address, so
 * an ordinary data read works here, no code/register handoff needed.
 *
 * rv32_wait_restart lives in boot_rom.S too, referenced (by
 * RV32_PASS()/RV32_FAIL(), rv32_test.h) via link.ld's
 * `INCLUDE boot_rom_symbols.ld`.
 */
    .section .flash_header, "a"
    .global _flash_header
_flash_header:
    .word main
