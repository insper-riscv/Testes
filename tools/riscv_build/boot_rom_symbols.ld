/* Fixed BOOT_ROM addresses (see boot_rom.ld), INCLUDEd by every
 * test's own link.ld so it can reference boot_rom.S's entry points as
 * ordinary external symbols without that test being linked against
 * boot_rom.S/boot_rom.ld at all -- BOOT_ROM is a SEPARATE link unit,
 * compiled and JTAG-written once (see boot_rom.S's own header
 * comment). Keep these in sync with boot_rom.ld's RESET_RESERVED /
 * WAIT_RESTART_RESERVED.
 *
 *   rv32_wait_restart -- called by RV32_PASS()/RV32_FAIL() (rv32_test.h).
 *   _boot_continue    -- jumped to by crt0.S's own .flash_entry
 *                        trampoline, once it's loaded t1-t6/gp (see
 *                        boot_rom.S's register-contract comment).
 */
PROVIDE(rv32_wait_restart = 0x00000100);
PROVIDE(_boot_continue = 0x00000180);
