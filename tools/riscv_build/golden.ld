/* Spike-only combined link script: boot_rom.S + crt0.S + a test's own
 * source, all in ONE ELF. Real hardware/GHDL sim never use this --
 * BOOT_ROM and FLASH are genuinely separate images there (see
 * boot_rom.ld/link.ld) -- this exists ONLY so
 * golden_generator.generate_golden can run a single, self-contained
 * ELF under Spike that faithfully replays the real boot sequence
 * (BOOT_ROM's _reset reads FLASH's .flash_header, copies .data, zeros
 * .bss, jumps to main), the same way real hardware actually boots,
 * instead of starting mid-sequence with no way to reach an entry
 * point Spike can run from cold.
 *
 * Layout mirrors boot_rom.ld + link.ld exactly (same fixed addresses
 * and budgets -- see link.ld's own header comment for why every
 * section's address/size is fixed now), just merged into one
 * MEMORY/SECTIONS so a single `ld` invocation can place boot_rom.S's
 * sections AND a test's own .flash_header/.text/.rodata/.data/.sdata/
 * .sbss/.bss/stack together. tohost/fromhost are real, named symbols
 * here (see boot_rom.S's own .equ) so golden_generator can resolve
 * `tohost` via `nm` the way it always has.
 */

MEMORY
{
    BOOT_ROM (rx) : ORIGIN = 0x00000000, LENGTH = 2K
    FLASH    (rx) : ORIGIN = 0x00000800, LENGTH = 30K
    RAM      (rw) : ORIGIN = 0x00008000, LENGTH = 160K - 24
}

HEADER_BUDGET = 0x00000004;
TEXT_BUDGET   = 0x00001000;
RODATA_BUDGET = 0x00000800;
DATA_BUDGET   = 0x00000400;
SDATA_BUDGET  = 0x00000400;
SBSS_BUDGET   = 0x00000200;
BSS_BUDGET    = 0x00000400;

ENTRY(_reset)

SECTIONS
{
    .text.reset 0x00000000 : { *(.text.reset) } > BOOT_ROM
    .text.wait_restart 0x100 : { *(.text.wait_restart) } > BOOT_ROM

    .flash_header ORIGIN(FLASH) : { *(.flash_header) } > FLASH
    .text ORIGIN(FLASH) + HEADER_BUDGET : { *(.text.start) *(.text*) } > FLASH
    .rodata ORIGIN(FLASH) + HEADER_BUDGET + TEXT_BUDGET : { *(.rodata*) } > FLASH

    .data ORIGIN(RAM) : AT(ORIGIN(FLASH) + HEADER_BUDGET + TEXT_BUDGET + RODATA_BUDGET) {
        *(.data*)
    } > RAM
    _data_load = LOADADDR(.data);

    .sdata ORIGIN(RAM) + DATA_BUDGET : AT(ORIGIN(FLASH) + HEADER_BUDGET + TEXT_BUDGET + RODATA_BUDGET + DATA_BUDGET) {
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2)
        *(.srodata .srodata.*)
        *(.sdata .sdata.* .gnu.linkonce.s.*)
    } > RAM

    .sbss ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET (NOLOAD) : {
        *(.dynsbss)
        *(.sbss .sbss.* .gnu.linkonce.sb.*)
        *(.scommon)
    } > RAM

    .bss ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET + SBSS_BUDGET (NOLOAD) : {
        *(.bss*) *(COMMON)
    } > RAM

    _data_start = ORIGIN(RAM);
    _data_end   = ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET;
    _bss_start  = ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET;
    _bss_end    = ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET + SBSS_BUDGET + BSS_BUDGET;

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_stack_top == 0x0002FFE8, "RAM region drifted out of sync with boot_rom.S's hardcoded sp -- update both together, and config.yaml's memory.* too")
}
