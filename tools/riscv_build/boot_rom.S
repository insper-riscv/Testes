/* boot_rom.S -- the FIXED, generic bootloader. Programmed into
 * BOOT_ROM once (initial full Quartus compile), never JTAG-rewritten
 * again -- only FLASH gets reprogrammed per test (see build_fpga.py /
 * config.yaml quartus:). This plays the role a real SOC's boot ROM
 * plays: it doesn't know or care what firmware (FLASH content) it's
 * booting, it just knows the fixed protocol FLASH exposes.
 *
 * link.ld gives every section a FIXED address and a FIXED size
 * budget, the same for every test (like a real CPU's own memory
 * map), so _data_start/_data_end/_bss_start/_bss_end/gp are the same
 * numeric constant for every test -- hardcoded directly below rather
 * than read from anywhere. link.ld's own ASSERTs are the single
 * source of truth for these numbers; if any of them ever fires
 * (a budget changed), update the matching literal here too:
 *
 *   _data_load  = 0x00002004  (FLASH, LMA of .data+.sdata combined)
 *   _data_start = 0x00008000  (RAM, VMA of .data)
 *   _data_end   = 0x00008800  (RAM, VMA end of .data+.sdata combined)
 *   _bss_start  = 0x00008800  (RAM, VMA of .sbss)
 *   _bss_end    = 0x00008E00  (RAM, VMA end of .sbss+.bss combined)
 *   gp          = 0x00008C00  (.sdata's start + 0x800)
 *
 * The only thing that still varies per test is main's own address
 * (wherever that test's code lands inside the fixed .text budget),
 * so crt0.S's .flash_header (at FLASH_BASE, 0x00000800) carries just
 * that one word now. _reset reads it with a plain `lw`: the MEM
 * stage's second FLASH read port (rv32im_pipeline_core.vhd's
 * flash_addr2/FLASH_MEM, added for the .data copy loop below) reaches
 * any FLASH-range address, so an ordinary data read works here.
 *
 * tp (thread pointer) is intentionally NOT initialized here -- no
 * test in this project uses TLS (see the old crt0.S history for why
 * that was even considered); add it back if that ever changes.
 *
 * This file must stay under BOOT_ROM_SIZE (link.ld / config.yaml
 * memory.boot_rom_words / rv32im_pipeline_core.vhd's
 * BOOT_ROM_SIZE_BYTES -- all three must agree). boot_rom.ld reserves
 * a fixed offset for rv32_wait_restart (0x100) -- see
 * boot_rom_symbols.ld, INCLUDEd by every test's own link.ld so both
 * RV32_PASS()/RV32_FAIL() (rv32_test.h) and _reset's own FLASH_BASE
 * read can reference fixed addresses without linking against this
 * file.
 */

    .section .text.reset
    .global _reset
_reset:
    // sp: fixed for every test -- top of RAM, same value _stack_top
    // used to be computed as in link.ld (ORIGIN(ram) + LENGTH(ram)).
    li   sp, 0x0002FFE8

    // Clear mailbox/go_flag/tohost/fromhost -- same fixed addresses
    // and same "must be clean on every _reset entry, cold boot or
    // restart" reasoning the old crt0.S documented (see
    // rv32_wait_restart below for why: Spike/HTIF and the mailbox
    // poller both treat a stale nonzero value as "already done").
    li   t0, 0x00030000
    sw   x0, -4(t0)              // mailbox_addr  = 0x0002FFFC
    sw   x0, -8(t0)               // go_flag_addr  = 0x0002FFF8
    sw   x0, -16(t0)              // fromhost      = 0x0002FFF0 (+4 below)
    sw   x0, -12(t0)
    sw   x0, -24(t0)              // tohost        = 0x0002FFE8 (+4 below)
    sw   x0, -20(t0)

    // Real, named symbols at these same fixed addresses -- harmless
    // on real hardware (the sw's above already wrote here via literal
    // offsets, these .equ's don't change codegen), but lets
    // golden_generator.generate_golden resolve `tohost` by name via
    // `nm` the same way it always has, since it runs a COMBINED
    // boot_rom+test ELF under Spike (see tools/riscv_build/golden.ld)
    // rather than the real, separately-linked BOOT_ROM/FLASH images.
    .equ tohost, 0x0002FFE8
    .equ fromhost, 0x0002FFF0
    .global tohost
    .global fromhost

    // Fixed memory map (see this file's own header comment): every
    // test's .data/.sdata/.sbss/.bss land at the exact same addresses,
    // so these are plain immediates, not read from anywhere.
    li   t1, 0x00002004            // _data_load
    li   t2, 0x00008000            // _data_start
    li   t3, 0x00008800            // _data_end
    li   t4, 0x00008800            // _bss_start
    li   t5, 0x00008E00            // _bss_end
    li   gp, 0x00008C00            // __global_pointer$

    // Read this test's own main() address -- the one thing that
    // still varies per test -- from crt0.S's _flash_header.
    li   t0, 0x00000800            // FLASH_BASE
    lw   t6, 0(t0)                  // main's address

    // .data+.sdata copy: FLASH (data_load) -> RAM (data_start..data_end)
copy_loop:
    bge  t2, t3, copy_done
    lw   a0, 0(t1)
    sw   a0, 0(t2)
    addi t1, t1, 4
    addi t2, t2, 4
    j    copy_loop
copy_done:

    // .sbss+.bss zero: bss_start..bss_end
bss_loop:
    bge  t4, t5, bss_done
    sw   x0, 0(t4)
    addi t4, t4, 4
    j    bss_loop
bss_done:

    jr   t6                       // -> that test's own main (FLASH)

    /* Lets build_fpga.py re-run a *different* program on this same,
     * already-configured bitstream: JTAG-write a new FLASH image,
     * then write a nonzero word to go_flag_addr without reprogramming
     * the FPGA. A core sitting in this loop notices and jumps back to
     * _reset, which clears mailbox_addr/go_flag_addr itself (above)
     * before running the new program.
     *
     * Fixed at boot_rom.ld's offset 0x100 (see boot_rom_symbols.ld)
     * so every test's own link.ld can call this as an ordinary
     * external symbol without linking against this file.
     *
     * Same HTIF tohost convention the old crt0.S wrote (1 = pass,
     * 3 = fail = (1<<1)|1) -- harmless on real hardware, nothing
     * there reads tohost; kept for ACT4/Spike parity. */
    .section .text.wait_restart
    .global rv32_wait_restart
rv32_wait_restart:
    li   t0, 0x00030000
    lw   t1, -4(t0)                // mailbox_addr = 0x0002FFFC
    li   t2, 1
    li   t3, 1                     // HTIF pass
    beq  t1, t2, 1f
    li   t3, 3                     // HTIF fail
1:
    sw   t3, -24(t0)               // tohost = 0x0002FFE8

rv32_wait_restart_poll:
    lw   t1, -8(t0)                 // go_flag_addr = 0x0002FFF8
    beqz t1, rv32_wait_restart_poll
    j    _reset
