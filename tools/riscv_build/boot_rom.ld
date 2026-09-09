/* Linker script for boot_rom.S -- the fixed, generic bootloader.
 * Compiled and JTAG-written ONCE (part of the initial full Quartus
 * compile), never touched again -- see boot_rom.S's own header
 * comment and config.yaml quartus:.
 *
 * ORIGIN/LENGTH must match rv32im_pipeline_core.vhd's
 * BOOT_ROM_SIZE_BYTES and config.yaml memory.boot_rom_words.
 *
 * rv32_wait_restart and _boot_continue are both pinned to FIXED
 * addresses so every test's own link.ld (via boot_rom_symbols.ld) can
 * call/jump to them as ordinary external symbols without linking
 * against this file at all -- see boot_rom_symbols.ld. The ASSERTs
 * below catch either section ever growing past its reservation.
 */

MEMORY
{
  boot_rom (rx) : ORIGIN = 0x00000000, LENGTH = 2K
}

RESET_RESERVED         = 0x100;
WAIT_RESTART_RESERVED  = 0x80;   /* 0x100 .. 0x17F */

OUTPUT_ARCH("riscv")
ENTRY(_reset)

SECTIONS
{
  .text.reset 0x00000000 : { *(.text.reset) } > boot_rom
  ASSERT(SIZEOF(.text.reset) <= RESET_RESERVED,
         "boot_rom.S's _reset grew past RESET_RESERVED -- move rv32_wait_restart's fixed address (boot_rom_symbols.ld) or grow the reservation")

  .text.wait_restart RESET_RESERVED : { *(.text.wait_restart) } > boot_rom
  ASSERT(SIZEOF(.text.wait_restart) <= WAIT_RESTART_RESERVED,
         "boot_rom.S's rv32_wait_restart grew past WAIT_RESTART_RESERVED -- move _boot_continue's fixed address (boot_rom_symbols.ld) or grow the reservation")

  .text.boot_continue RESET_RESERVED + WAIT_RESTART_RESERVED : { *(.text.boot_continue) } > boot_rom

  . = ALIGN(4);
  ASSERT(. <= ORIGIN(boot_rom) + LENGTH(boot_rom), "boot_rom.S exceeds BOOT_ROM -- grow memory.boot_rom_words (config.yaml) and BOOT_ROM_SIZE_BYTES (rv32im_pipeline_core.vhd)")
}
