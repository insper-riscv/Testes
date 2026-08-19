/* Memory map for bare-metal RV32 test programs, matching RV32IM's
 * rv32im_pipeline_core: a Harvard core with two INDEPENDENT address
 * spaces (rom_addr and ram_addr are separate buses), each starting at
 * 0x0 — not a unified memory map. ROM and RAM below both having
 * ORIGIN 0x0 is intentional, not a typo.
 *
 * LENGTH must match memory.rom_words / memory.ram_words in
 * config.yaml. RAM is 4 bytes shorter than the raw IP depth because
 * the last word is reserved for the PASS/FAIL mailbox (see
 * include/rv32_test.h) and must stay out of the stack's reach —
 * that's why the mailbox address is (ram_words*4 - 4).
 */

MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 32K       /* rom_words: 8192 * 4 bytes */
    RAM (rw) : ORIGIN = 0x00000000, LENGTH = 16K - 4    /* ram_words: 4096 * 4 bytes, minus the mailbox word */
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

    /* Stack grows down from the top of RAM; the mailbox word sits
     * just past LENGTH(RAM), so the stack can never reach it. */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
