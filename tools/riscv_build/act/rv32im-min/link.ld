/* Linker script for rv32im_pipeline_core (RV32IM/src) under ACT4.
 *
 * Unlike every other config's link.ld in the vendored framework
 * (which assume ONE flat read/write/execute memory region — see
 * config/spike/spike-RVI20U32/link.ld), this core is Harvard
 * MODIFICADO: instruction fetch (rom_addr) and data load/store
 * (ram_addr) are two physically separate buses, and only RAM is
 * writable — see this project's OWN tools/riscv_build/link.ld for
 * the identical constraint on its regular (non-ACT4) tests. ACT4's
 * own boot sequence (tests/env/rvtest_setup.h) assumes a test's
 * .data is already sitting at its run address by the time the test
 * body starts — untrue here, since ROM has no write path at all. The
 * RVMODEL_BOOT hook (rvmodel_macros.h) copies .rodata+.data from
 * their ROM load address to RAM before anything else runs, the same
 * way this project's own crt0.S does for its regular tests.
 *
 * ORIGIN/LENGTH must match this project's own memory.rom_words /
 * memory.ram_words / memory.ram_base (tools/riscv_build/config.yaml)
 * — same physical ROM/RAM the regular test suite runs on.
 */

MEMORY
{
  rom (rx) : ORIGIN = 0x00000000, LENGTH = 128K
  /* Top 20 bytes reserved: tohost+fromhost (8+8, HTIF, see
   * rvmodel_macros.h) and a 4-byte "console" word RVMODEL_IO_WRITE_STR
   * writes to — both watched directly by tools/riscv_build/act/sim/
   * test_act.py off the raw ram_addr/ram_wdata bus, the same way
   * test_c_program.py already watches this project's own mailbox.
   * 128K/128K (not 64K/64K) to match config.yaml's memory.rom_words/
   * ram_words — real hardware's ROM/RAM were doubled specifically to
   * fit ACT4 test images (see config.yaml's own memory: comment). */
  ram (rw) : ORIGIN = 0x00020000, LENGTH = 128K - 20
}

TEST_BASE = ORIGIN(rom);
STACK_SIZE = 0x1000;

OUTPUT_ARCH("riscv")
ENTRY(rvtest_entry_point)

SECTIONS
{
  .text.init   TEST_BASE : { *(.text.init) } > rom
  .text.rvtest . : { *(.text.rvtest) *(.text.rvtest.*) } > rom

  /* .text.rvmodel (RVMODEL_BOOT/HALT, IO macros) must be executable
   * from rom like every other .text section on this core — unlike
   * the unified-memory targets this framework normally certifies,
   * "after .data" (the usual convention, see AGENTS.md) has no
   * meaning here since this build never produces a .sig.elf to keep
   * address parity with (self-checking only, no Sail signature
   * comparison — see docs/certification-notes.md). */
  .text.rvmodel . : { *(.text.rvmodel) *(.text.rvmodel.*) *(.text) *(.text.*) } > rom

  /* .rodata+.data share one ROM->RAM copy loop (RVMODEL_BOOT) — both
   * treated as "needs copying to RAM before use", not split the way
   * this project's own link.ld splits them (which relies on the
   * second ROM read port for true consts, unproven for ACT4's own
   * generated data-pool sections). Simpler and always correct, at
   * the cost of copying a few read-only bytes that didn't strictly
   * need it. */
  .rodata ORIGIN(ram) : {
    _romcopy_start = .;
    *(.rodata) *(.rodata.*) *(.srodata) *(.srodata.*)
  } > ram AT> rom
  .data . : {
    . = ALIGN(4);
    /* gp reaches +/-0x800 — same convention this project's own
     * link.ld/crt0.S use, see rvmodel_macros.h's RVMODEL_BOOT. */
    PROVIDE(__global_pointer$ = . + 0x800);
    *(.data) *(.data.*) *(.sdata) *(.sdata.*)
    . = ALIGN(4);
    _romcopy_end = .;
  } > ram AT> rom
  /* One contiguous ROM source (rodata immediately followed by data,
   * both LMA-adjacent since neither sets an explicit load address)
   * for RVMODEL_BOOT's single copy loop — see rvmodel_macros.h. */
  _romcopy_load = LOADADDR(.rodata);

  . = ALIGN(16);
  .bss (NOLOAD) : {
    _bss_start = .;
    *(.sbss) *(.sbss.*) *(.bss) *(.bss.*) *(COMMON)
    . = ALIGN(16);
    _bss_end = .;
  } > ram

  . = ALIGN(16);
  _stack_bottom = .;
  . += STACK_SIZE;
  _stack_top = .;

  ASSERT(_stack_top <= ORIGIN(ram) + LENGTH(ram), "ACT ELF exceeds RAM; grow STACK_SIZE's budget or shrink SIGUPD_COUNT")

  /* tohost/fromhost (.global symbols, 8 bytes each) come from
   * RVMODEL_DATA_SECTION's own ".tohost" section (rvmodel_macros.h)
   * — placed here explicitly, past RAM's declared LENGTH, same idea
   * (and same "no '> ram' here on purpose" reasoning — a section
   * placed exactly at ORIGIN+LENGTH trips ld's region-overflow check
   * even though the address itself is real, reserved RAM) as this
   * project's own tools/riscv_build/link.ld. */
  .tohost ORIGIN(ram) + LENGTH(ram) (NOLOAD) : { *(.tohost) }
}

PROVIDE(rv32_act_console = ORIGIN(ram) + LENGTH(ram) + 16);
