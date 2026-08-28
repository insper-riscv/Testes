/* Memory map for bare-metal RV32 test programs, matching RV32IM's
 * rv32im_pipeline_core: a Harvard core with two INDEPENDENT address
 * spaces (rom_addr and ram_addr are separate buses), each starting at
 * 0x0 — not a unified memory map. ROM and RAM below both having
 * ORIGIN 0x0 is intentional, not a typo.
 *
 * LENGTH must match memory.rom_words / memory.ram_words in
 * config.yaml. RAM is 24 bytes shorter than the raw IP depth:
 *  - the last two words are reserved for the PASS/FAIL mailbox and
 *    the restart "go" flag (see include/rv32_test.h) — fixed
 *    addresses, not linker symbols, hardcoded in crt0.S to match
 *    config.yaml (mailbox_addr/go_flag_addr = ram_words*4 - 4 / - 8);
 *  - the .tohost section below reserves another 16 bytes for HTIF's
 *    tohost/fromhost (see crt0.S) — real linker symbols this time,
 *    since Spike locates them by ELF symbol lookup, not by address.
 * Both must stay out of the stack's reach, which is why RAM's LENGTH
 * excludes them.
 */

MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 32K        /* rom_words: 8192 * 4 bytes */
    RAM (rw) : ORIGIN = 0x00000000, LENGTH = 16K - 24    /* ram_words: 4096 * 4 bytes, minus mailbox + go-flag (8) + tohost/fromhost (16) */
}

SECTIONS
{
    .text : { *(.text.start) *(.text*) } > ROM
    .rodata : { *(.rodata*) } > ROM

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > RAM AT> ROM
    _data_load = LOADADDR(.data);

    .bss (NOLOAD) : {
        _bss_start = .;
        *(.bss*) *(COMMON)
        _bss_end = .;
    } > RAM

    /* HTIF (Host-Target InterFace): the convention Spike/riscv-tests
     * use to detect a bare-metal program's completion in simulation
     * — meaningless on real hardware, nothing there watches these
     * addresses. Real ELF symbols (not a hardcoded offset like
     * mailbox/go_flag), because Spike finds tohost/fromhost by symbol
     * lookup rather than a fixed address — but the address itself is
     * still pinned explicitly (ORIGIN(RAM) + LENGTH(RAM), 8-byte
     * aligned by construction), not left to "wherever .bss happens to
     * end". A test with empty/near-empty .data+.bss would otherwise
     * leave the RAM location counter at 0, placing tohost at RAM
     * address 0x0 — indistinguishable from a test's own data there.
     * See crt0.S. */
    /* No "> RAM" here on purpose: RAM's declared LENGTH already ends
     * at ORIGIN(RAM)+LENGTH(RAM) (that's the whole point — it's what
     * keeps .data/.bss/the stack out of this reserved tail), so a
     * section placed AT that exact boundary would trip ld's "not
     * within region RAM" region-overflow check even though the
     * address itself is perfectly valid, real RAM. */
    .tohost ORIGIN(RAM) + LENGTH(RAM) (NOLOAD) : {
        PROVIDE(tohost = .);
        . += 8;
        PROVIDE(fromhost = .);
        . += 8;
    }

    /* Stack grows down from the top of RAM; the mailbox word sits
     * just past LENGTH(RAM), so the stack can never reach it. */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
