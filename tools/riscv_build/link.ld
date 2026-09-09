/* Memory map for bare-metal RV32 test programs, matching RV32IM's
 * rv32im_pipeline_core: 3 physical memories now -- BOOT_ROM (fixed,
 * shared, NOT part of this link -- see boot_rom.S/boot_rom.ld),
 * FLASH (this test's own .boot_header + .text, JTAG-rewritten per
 * test) and RAM (this test's .data/.rodata/.bss/stack -- the only
 * memory the MEM stage ever touches; nothing reads data-side straight
 * out of FLASH anymore, see rv32im_pipeline_core.vhd).
 *
 * ORIGIN/LENGTH must match memory.rom_base/rom_words/ram_base/
 * ram_words in config.yaml, and FLASH's ORIGIN must match
 * BOOT_ROM_SIZE_BYTES in rv32im_pipeline_core.vhd (that's where
 * BOOT_ROM ends and FLASH begins in the shared instruction address
 * space) and boot_rom.S's own hardcoded FLASH_BASE.
 *
 * RAM is 24 bytes shorter than the raw IP depth, reserved for:
 *  - the PASS/FAIL mailbox + restart "go" flag (2 words, fixed
 *    addresses hardcoded in boot_rom.S AND rv32_test.h -- both must
 *    match config.yaml's memory.mailbox_addr/go_flag_addr);
 *  - HTIF tohost/fromhost (16 bytes) -- ALSO just a fixed address
 *    hardcoded in boot_rom.S now, not a resolvable ELF symbol here
 *    anymore: nothing in this project's own sim (test_c_program.py)
 *    looks tohost up by symbol, it watches the mailbox directly off
 *    the ram_addr/ram_wdata bus, so there's no reason for every test
 *    to carry a real .tohost section just for that (unlike ACT4's
 *    OWN separate link.ld, which still needs it for Spike).
 * All three (mailbox/go_flag/tohost+fromhost) must stay out of the
 * stack's reach, which is why RAM's LENGTH excludes them -- see the
 * ASSERT below tying _stack_top to boot_rom.S's own hardcoded sp.
 *
 * .rodata is no longer ROM-resident: BOOT_ROM/FLASH are IF-only now
 * (see rv32im_pipeline_core.vhd, is_boot_rom_if/is_boot_rom_d) --
 * there's no data path to either of them at all anymore, only to RAM.
 * ALL of .rodata gets copied to RAM by boot_rom.S at boot now, same
 * as .data always was -- exactly what
 * tools/riscv_build/act/rv32im-min/link.ld already does for ACT4's
 * own tests (see .rodata there), just extended here too.
 *
 * That "IF-only" constraint is also why .flash_entry (below) is CODE,
 * not a data table: crt0.S used to emit a header table of
 * .data/.bss bounds for boot_rom.S to `lw` -- broken, since a data
 * read from a FLASH address silently reads RAM instead (confirmed by
 * simulation). See crt0.S/boot_rom.S's own header comments for the
 * actual (code-based) handoff.
 */

INCLUDE boot_rom_symbols.ld

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000800, LENGTH = 30K   /* = RAM's ORIGIN (0x8000) - FLASH's own ORIGIN (0x800) */
    RAM   (rw) : ORIGIN = 0x00008000, LENGTH = 160K - 24
}

SECTIONS
{
    /* Must be FIRST in FLASH -- boot_rom.S's _reset jumps to a
     * hardcoded FLASH_BASE (ORIGIN(FLASH) itself), not via a linker
     * symbol (BOOT_ROM can't see this link's own symbols). See
     * crt0.S's own header comment for why this is CODE, not data. */
    .flash_entry : { *(.flash_entry) } > FLASH

    .text : { *(.text.start) *(.text*) } > FLASH

    /* .data now absorbs *(.rodata*) unconditionally (see header
     * comment above) in addition to the small-data (.sdata) handling
     * this already had -- gp still reaches +/-0x800 past its own
     * start the same way, see docs/SMALL_DATA_SECTION_BUG.md and
     * boot_rom.S (gp comes from this section's __global_pointer$
     * value, loaded as a raw word, not pcrel-computed anymore).
     */
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

    /* No .tdata/.tbss/.tohost sections anymore -- see header comment
     * (TLS: boot_rom.S doesn't init tp, nothing uses TLS; tohost:
     * fixed address in boot_rom.S, not a symbol here). */

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_stack_top == 0x0002FFE8, "RAM region drifted out of sync with boot_rom.S's hardcoded sp -- update both together, and config.yaml's memory.* too")
}
