/* Spike-only combined link script: boot_rom.S + crt0.S + a test's own
 * source, all in ONE ELF. Real hardware/GHDL sim never use this --
 * BOOT_ROM and FLASH are genuinely separate images there (see
 * boot_rom.ld/link.ld) -- this exists ONLY so
 * golden_generator.generate_golden can run a single, self-contained
 * ELF under Spike that faithfully replays the real boot sequence
 * (BOOT_ROM's _reset -> FLASH's .flash_entry -> _boot_continue ->
 * main), the same way real hardware actually boots, instead of
 * starting mid-sequence with no way to reach an entry point Spike can
 * run from cold.
 *
 * Layout mirrors boot_rom.ld + link.ld exactly (same addresses), just
 * merged into one MEMORY/SECTIONS so a single `ld` invocation can
 * place boot_rom.S's sections AND a test's own .flash_entry/.text/
 * .data/.bss/stack together. tohost/fromhost are real, named symbols
 * here (see boot_rom.S's own .equ) so golden_generator can resolve
 * `tohost` via `nm` the way it always has.
 */

MEMORY
{
    BOOT_ROM (rx) : ORIGIN = 0x00000000, LENGTH = 2K
    FLASH    (rx) : ORIGIN = 0x00000800, LENGTH = 30K
    RAM      (rw) : ORIGIN = 0x00008000, LENGTH = 160K - 24
}

ENTRY(_reset)

SECTIONS
{
    .text.reset 0x00000000 : { *(.text.reset) } > BOOT_ROM
    .text.wait_restart 0x100 : { *(.text.wait_restart) } > BOOT_ROM
    .text.boot_continue 0x180 : { *(.text.boot_continue) } > BOOT_ROM

    .flash_entry 0x00000800 : { *(.flash_entry) } > FLASH
    .text : { *(.text.start) *(.text*) } > FLASH

    .data : {
        _data_start = .;
        *(.data*)
        . = ALIGN(4);
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.rodata*)
        *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2)
        *(.srodata .srodata.*)
        *(.sdata .sdata.* .gnu.linkonce.s.*)
        _data_end = .;
    } > RAM AT> FLASH
    _data_load = LOADADDR(.data);

    .sbss (NOLOAD) : {
        _bss_start = .;
        *(.dynsbss)
        *(.sbss .sbss.* .gnu.linkonce.sb.*)
        *(.scommon)
    } > RAM

    .bss (NOLOAD) : {
        *(.bss*) *(COMMON)
        _bss_end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_stack_top == 0x0002FFE8, "RAM region drifted out of sync with boot_rom.S's hardcoded sp -- update both together, and config.yaml's memory.* too")
}
