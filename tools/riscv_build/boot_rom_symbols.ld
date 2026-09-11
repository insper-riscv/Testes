/* Fixed BOOT_ROM address (see boot_rom.ld), INCLUDEd by every test's
 * own link.ld so it can reference boot_rom.S's rv32_wait_restart as
 * an ordinary external symbol without that test being linked against
 * boot_rom.S/boot_rom.ld at all -- BOOT_ROM is a SEPARATE link unit,
 * compiled and JTAG-written once (see boot_rom.S's own header
 * comment). Keep this in sync with boot_rom.ld's RESET_RESERVED.
 *
 *   rv32_wait_restart -- called by RV32_PASS()/RV32_FAIL() (rv32_test.h).
 */
PROVIDE(rv32_wait_restart = 0x00000100);
