/* boot_rom.S -- the FIXED, generic bootloader. Programmed into
 * BOOT_ROM once (initial full Quartus compile), never JTAG-rewritten
 * again -- only FLASH gets reprogrammed per test (see build_fpga.py /
 * config.yaml quartus:). This plays the role a real SOC's boot ROM
 * plays: it doesn't know or care what firmware (FLASH content) it's
 * booting, it just knows the fixed protocol FLASH exposes.
 *
 * IMPORTANT: BOOT_ROM and FLASH are BOTH fetch-only (IF stage) --
 * nothing in this design gives the MEM stage a data path to either of
 * them (see rv32im_pipeline_core.vhd: only RAM is wired to the MEM
 * stage). That means this fixed bootloader CANNOT `lw` a per-test
 * "header table" out of FLASH the way an earlier version of this file
 * tried to (silently reads RAM instead, since MEM-stage addresses
 * only ever reach RAM -- confirmed by simulation: t1..t6 all came
 * back zero and `jr t6` looped back to address 0).
 *
 * Instead, the handoff is CODE, not data: every test's own crt0.S
 * emits a tiny "entry trampoline" (see link.ld's .flash_entry, placed
 * first in FLASH, at FLASH_BASE) that `la`s that test's own
 * .data/.bss bounds, gp, and main's address into t1-t6/gp using
 * ordinary instruction fetch (no MEM-stage access needed -- `la`
 * expands to auipc+addi, pure code), then jumps to _boot_continue
 * below (a FIXED address, see boot_rom_symbols.ld) to finish the
 * job. _reset itself only ever touches things that are the SAME for
 * every test (sp, mailbox/go_flag/tohost/fromhost -- all fixed
 * addresses), so it doesn't need any per-test data either.
 *
 * Register contract _flash_entry hands off to _boot_continue with
 * (see a test's own crt0.S):
 *   t1 = _data_load    (source, in FLASH -- LMA of .data)
 *   t2 = _data_start    (dest, in RAM -- VMA of .data)
 *   t3 = _data_end
 *   t4 = _bss_start     (in RAM)
 *   t5 = _bss_end
 *   t6 = main's address (in FLASH)
 *   gp = __global_pointer$'s value (already loaded by _flash_entry)
 *
 * tp (thread pointer) is intentionally NOT initialized here -- no
 * test in this project uses TLS (see the old crt0.S history for why
 * that was even considered); add it back if that ever changes.
 *
 * This file must stay under BOOT_ROM_SIZE (link.ld / config.yaml
 * memory.boot_rom_words / rv32im_pipeline_core.vhd's
 * BOOT_ROM_SIZE_BYTES -- all three must agree). boot_rom.ld reserves
 * fixed offsets for _reset (0x0), rv32_wait_restart (0x100) and
 * _boot_continue (0x180) -- see boot_rom_symbols.ld, INCLUDEd by
 * every test's own link.ld so both RV32_PASS()/RV32_FAIL()
 * (rv32_test.h) and crt0.S's own .flash_entry can reference them as
 * ordinary external symbols without linking against this file.
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

    j    0x00000800               // FLASH_BASE -- that test's own .flash_entry

    /* Register contract from _flash_entry (see boot_rom.S's own
     * header comment): t1=data_load t2=data_start t3=data_end
     * t4=bss_start t5=bss_end t6=main gp=__global_pointer$ value.
     * Fixed at boot_rom.ld's offset 0x180 -- see boot_rom_symbols.ld.
     */
    .section .text.boot_continue
    .global _boot_continue
_boot_continue:
    // .data copy: FLASH (data_load) -> RAM (data_start..data_end)
copy_loop:
    bge  t2, t3, copy_done
    lw   a0, 0(t1)
    sw   a0, 0(t2)
    addi t1, t1, 4
    addi t2, t2, 4
    j    copy_loop
copy_done:

    // .bss zero: bss_start..bss_end
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
