/* Memory map for bare-metal RV32 test programs, matching RV32IM's
 * rv32im_pipeline_core: 3 physical memories -- BOOT_ROM (fixed,
 * shared, NOT part of this link -- see boot_rom.S/boot_rom.ld),
 * FLASH (this test's own .flash_header/.text/.rodata, JTAG-rewritten
 * per test) and RAM (this test's .data/.sdata/.sbss/.bss/stack).
 *
 * Every section below gets a FIXED address and a FIXED size budget,
 * the same for every test -- like a real CPU's own memory map, which
 * doesn't move depending on what firmware happens to be flashed. A
 * test whose own content is smaller than its section's budget just
 * leaves the rest of that budget unused; a test that overflows its
 * budget fails to link (see the ASSERTs below), loudly, instead of
 * silently colliding with the next section.
 *
 * Because every section's address AND size are fixed, _data_start/
 * _data_end/_bss_start/_bss_end/__global_pointer$ are the exact same
 * numeric value for every test -- boot_rom.S hardcodes them directly
 * instead of reading them from a per-test header (see its own header
 * comment). Only main's address still varies per test (wherever that
 * test's own code lands inside the fixed .text budget), so
 * crt0.S's .flash_header carries just that one word now.
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
 *    hardcoded in boot_rom.S, not a resolvable ELF symbol here:
 *    nothing in this project's own sim (test_c_program.py) looks
 *    tohost up by symbol, it watches the mailbox directly off the
 *    ram_addr/ram_wdata bus, so there's no reason for every test to
 *    carry a real .tohost section just for that (unlike ACT4's OWN
 *    separate link.ld, which still needs it for Spike).
 * All three (mailbox/go_flag/tohost+fromhost) must stay out of the
 * stack's reach, which is why RAM's LENGTH excludes them -- see the
 * ASSERT below tying _stack_top to boot_rom.S's own hardcoded sp.
 *
 * .rodata (regular, non-small constants) is FLASH-resident, same as
 * .text: VMA == LMA, never copied. This works because FLASH has a
 * second, MEM-stage-only read port (rv32im_pipeline_core.vhd's
 * flash_addr2/FLASH_MEM, added for boot_rom.S's own .data copy loop)
 * that reaches any FLASH-range address generically, not just during
 * that copy loop -- an ordinary `lw` to a .rodata constant routes
 * through it at runtime too.
 *
 * .sdata (small read-write, needs init) and .srodata (small
 * read-only) are the one FLASH-ineligible exception: both are
 * gp-relative addressed, and gp is computed from a fixed point in
 * RAM (there's only one gp register), so anything reached through it
 * has to live in RAM too -- merged into one fixed .sdata section
 * along with .srodata, right after .data, so a single copy loop still
 * covers both (see boot_rom.S). .sbss (small, zero-init, also
 * gp-relative) sits right after that, so gp reaches it too.
 */

INCLUDE boot_rom_symbols.ld

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000800, LENGTH = 30K   /* = RAM's ORIGIN (0x8000) - FLASH's own ORIGIN (0x800) */
    RAM   (rw) : ORIGIN = 0x00008000, LENGTH = 160K - 24
}

/* Fixed per-section budgets -- generous headroom over the largest
 * this project's own suite actually uses today (measured via
 * objdump across all 85 tests): .text 228B, .rodata 32B, .data 16B,
 * .sbss 8B, .bss 16B. FLASH has ~24.5K left unused after these; RAM
 * has the whole rest of its 160K for heap+stack (see below). Grow
 * whichever budget a future test actually needs -- the ASSERTs below
 * catch it immediately instead of silently corrupting the next
 * section. */
HEADER_BUDGET = 0x00000004;   /* .flash_header: just main's address now */
TEXT_BUDGET   = 0x00001000;   /* .text: 4096 bytes */
RODATA_BUDGET = 0x00000800;   /* .rodata: 2048 bytes */
DATA_BUDGET   = 0x00000400;   /* .data: 1024 bytes */
SDATA_BUDGET  = 0x00000400;   /* .sdata + .srodata: 1024 bytes */
SBSS_BUDGET   = 0x00000200;   /* .sbss: 512 bytes */
BSS_BUDGET    = 0x00000400;   /* .bss: 1024 bytes */

SECTIONS
{
    /* Must be FIRST in FLASH -- boot_rom.S's _reset reads it with a
     * plain `lw` from a hardcoded FLASH_BASE (ORIGIN(FLASH) itself),
     * not via a linker symbol (BOOT_ROM can't see this link's own
     * symbols). Just main's address now (4 bytes) -- see crt0.S's own
     * header comment. */
    .flash_header ORIGIN(FLASH) : { *(.flash_header) } > FLASH
    ASSERT(SIZEOF(.flash_header) <= HEADER_BUDGET, ".flash_header grew past HEADER_BUDGET -- update it here and boot_rom.S's hardcoded offsets together")

    .text ORIGIN(FLASH) + HEADER_BUDGET : { *(.text.start) *(.text*) } > FLASH
    ASSERT(SIZEOF(.text) <= TEXT_BUDGET, ".text grew past TEXT_BUDGET -- grow it here and boot_rom.S's hardcoded offsets together")

    .rodata ORIGIN(FLASH) + HEADER_BUDGET + TEXT_BUDGET : { *(.rodata*) } > FLASH
    ASSERT(SIZEOF(.rodata) <= RODATA_BUDGET, ".rodata grew past RODATA_BUDGET -- grow it here and boot_rom.S's hardcoded offsets together")

    .data ORIGIN(RAM) : AT(ORIGIN(FLASH) + HEADER_BUDGET + TEXT_BUDGET + RODATA_BUDGET) {
        *(.data*)
    } > RAM
    ASSERT(SIZEOF(.data) <= DATA_BUDGET, ".data grew past DATA_BUDGET -- grow it here and boot_rom.S's hardcoded offsets together")

    .sdata ORIGIN(RAM) + DATA_BUDGET : AT(ORIGIN(FLASH) + HEADER_BUDGET + TEXT_BUDGET + RODATA_BUDGET + DATA_BUDGET) {
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2)
        *(.srodata .srodata.*)
        *(.sdata .sdata.* .gnu.linkonce.s.*)
    } > RAM
    ASSERT(SIZEOF(.sdata) <= SDATA_BUDGET, ".sdata grew past SDATA_BUDGET -- grow it here and boot_rom.S's hardcoded offsets together")

    .sbss ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET (NOLOAD) : {
        *(.dynsbss)
        *(.sbss .sbss.* .gnu.linkonce.sb.*)
        *(.scommon)
    } > RAM
    ASSERT(SIZEOF(.sbss) <= SBSS_BUDGET, ".sbss grew past SBSS_BUDGET -- grow it here and boot_rom.S's hardcoded offsets together")

    .bss ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET + SBSS_BUDGET (NOLOAD) : {
        *(.bss*) *(COMMON)
    } > RAM
    ASSERT(SIZEOF(.bss) <= BSS_BUDGET, ".bss grew past BSS_BUDGET -- grow it here and boot_rom.S's hardcoded offsets together")

    /* No .tdata/.tbss/.tohost sections -- TLS: boot_rom.S doesn't init
     * tp, nothing uses TLS; tohost: fixed address in boot_rom.S, not
     * a symbol here. */

    /* Still real ELF symbols, at their now-fixed values, even though
     * boot_rom.S itself hardcodes matching literals rather than
     * reading these: syscalls.c's malloc() references _bss_end
     * directly (`extern char _bss_end;`), and having the rest
     * (_data_start/_data_end/_bss_start) resolvable by name is worth
     * keeping for anyone inspecting the ELF with nm/objdump. */
    _data_start = ORIGIN(RAM);
    _data_end   = ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET;
    _data_load  = LOADADDR(.data);
    _bss_start  = ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET;
    _bss_end    = ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET + SBSS_BUDGET + BSS_BUDGET;

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
    ASSERT(_stack_top == 0x0002FFE8, "RAM region drifted out of sync with boot_rom.S's hardcoded sp -- update both together, and config.yaml's memory.* too")

    /* All of these are fixed constants now (same value every test) --
     * boot_rom.S hardcodes matching literals directly instead of
     * reading them from a header. These ASSERTs are the single source
     * of truth boot_rom.S's own comment points back to; if any of
     * them ever fires, update boot_rom.S's hardcoded values together. */
    ASSERT(ORIGIN(RAM) == 0x00008000, "RAM origin drifted -- update boot_rom.S's hardcoded _data_start together")
    ASSERT(ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET == 0x00008800, "_bss_start drifted -- update boot_rom.S's hardcoded literal together")
    ASSERT(ORIGIN(RAM) + DATA_BUDGET + SDATA_BUDGET + SBSS_BUDGET + BSS_BUDGET == 0x00008E00, "_bss_end drifted -- update boot_rom.S's hardcoded literal together")
    ASSERT(__global_pointer$ == 0x00008C00, "gp drifted -- update boot_rom.S's hardcoded literal together")
    ASSERT(LOADADDR(.data) == 0x00002004, "_data_load drifted -- update boot_rom.S's hardcoded literal together")
}
