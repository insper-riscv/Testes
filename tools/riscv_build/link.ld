/* Memory map for bare-metal RV32 test programs, matching RV32IM's
 * rv32im_pipeline_core: Harvard MODIFICADO. ROM and RAM are still two
 * physically independent memories (rom_addr/ram_addr are separate
 * buses, separate BRAM IPs), but the ROM now has a second read port
 * wired to the MEM stage (see rom2port.vhd/rv32im_pipeline_core.vhd),
 * and ROM/RAM sit in a single, non-overlapping address space so a
 * `lw` can be routed to the right one by address alone — bit 16
 * decides (0 = ROM, 1 = RAM; see is_rom_data in
 * rv32im_pipeline_core.vhd). This is what makes .data's ROM->RAM copy
 * loop below (crt0.S) actually work: before this, ROM and RAM both
 * started at 0x0 and a data-side `lw` could NEVER reach ROM at all,
 * no matter the address (see docs/DATA_HARVARD_BUG.md for the
 * original bug and investigation).
 *
 * ORIGIN/LENGTH must match memory.rom_words / memory.ram_words /
 * memory.ram_base in config.yaml. RAM is 24 bytes shorter than the
 * raw IP depth:
 *  - the last two words are reserved for the PASS/FAIL mailbox and
 *    the restart "go" flag (see include/rv32_test.h) — fixed
 *    addresses, not linker symbols, hardcoded in crt0.S to match
 *    config.yaml (mailbox_addr/go_flag_addr = ram_base + ram_words*4
 *    - 4 / - 8);
 *  - the .tohost section below reserves another 16 bytes for HTIF's
 *    tohost/fromhost (see crt0.S) — real linker symbols this time,
 *    since Spike locates them by ELF symbol lookup, not by address.
 * Both must stay out of the stack's reach, which is why RAM's LENGTH
 * excludes them.
 */

MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 64K        /* rom_words: 16384 * 4 bytes */
    RAM (rw) : ORIGIN = 0x00010000, LENGTH = 64K - 24    /* ram_words: 16384 * 4 bytes, minus mailbox + go-flag (8) + tohost/fromhost (16) */
}

SECTIONS
{
    .text : { *(.text.start) *(.text*) } > ROM
    .rodata : { *(.rodata*) } > ROM

    /* .data holds both regular initialized globals AND "small data"
     * (.sdata) — RISC-V gcc redirects globals under a size threshold
     * (default 8 bytes) into .sdata, addressed gp-relative instead of
     * absolutely, for shorter code. __global_pointer$ is placed
     * .sdata's own start + 0x800: RISC-V immediates are signed
     * 12-bit (+/-2048=0x800), so gp reaching 0x800 past .sdata's
     * start can address the back half of whatever came before it
     * (regular .data, within reach) AND up to 0x800 past into .sbss
     * (see below — .bss keeps .sdata's uninitialized counterpart
     * immediately adjacent, same convention GNU ld's own default
     * riscv linker scripts use). See docs/SMALL_DATA_SECTION_BUG.md
     * for how this was found (small globals with .data/.bss having no
     * *(.sdata*)/*(.sbss*) rule at all silently landed outside
     * _data_start/_data_end's copied range) and crt0.S for gp's own
     * init sequence.
     */
    .data : {
        _data_start = .;
        *(.data*)
        . = ALIGN(4);
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2)
        *(.srodata .srodata.*)
        *(.sdata .sdata.* .gnu.linkonce.s.*)
        _data_end = .;
    } > RAM AT> ROM
    _data_load = LOADADDR(.data);

    /* .sbss right after .data (not after .bss) so it stays within
     * __global_pointer$'s +/-0x800 reach — .bss proper can be
     * arbitrarily large and would push .sbss out of range if it came
     * first. _bss_start marks .sbss's own start, not .bss's — both
     * are NOLOAD/zero-initialized, so crt0.S's single zero loop
     * treats them as one contiguous region; no separate loop or
     * symbol pair needed just because they're two output sections. */
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

    /* Thread-local storage — nothing in this project declares a
     * __thread/_Thread_local variable today (both sections are always
     * empty in practice), but tp (crt0.S) is initialized regardless
     * so that changes silently if it ever happens, rather than
     * repeating .sdata's mistake (see
     * docs/SMALL_DATA_SECTION_BUG.md). RISC-V uses TLS "Variant I":
     * tp = one past the end of the TCB. This bare-metal setup has no
     * real TCB (no dynamic linking/DTV), so its size is 0 and tp
     * equals _tls_base = .tdata's own start directly. */
    .tdata : {
        _tls_base = .;
        _tdata_start = .;
        *(.tdata .tdata.*)
        _tdata_end = .;
    } > RAM AT> ROM
    _tdata_load = LOADADDR(.tdata);

    .tbss (NOLOAD) : {
        _tbss_start = .;
        *(.tbss .tbss.*)
        _tbss_end = .;
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
