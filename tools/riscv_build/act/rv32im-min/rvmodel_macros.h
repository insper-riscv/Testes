# rvmodel_macros.h
# DUT-specific macro definitions for rv32im_pipeline_core (RV32IM/src)
# under ACT4 — I/M only, no Zicsr, no trap/privilege support.
#
# See link.ld for why this differs from every other config's
# rvmodel_macros.h in this vendored framework: Harvard MODIFICADO
# (separate instruction/data buses, ROM has no write path), so
# RVMODEL_BOOT below does the ROM->RAM copy + bss-zero + sp/gp setup
# this project's own crt0.S does for its regular tests — none of that
# is needed on the unified-memory targets (spike, cva6, ...) this
# macro file was originally modeled on.

#ifndef _RVMODEL_MACROS_H
#define _RVMODEL_MACROS_H

# tests/env/sail_macros.h unconditionally requires these two for every
# .sig.elf (signature-mode) build, regardless of ref_model_exe — a
# framework quirk confirmed by actually building against it:
# build_plan.py only auto-supplies them via sail.json when
# ref_model_type==SAIL (config.py), but riscv_arch_test.h includes
# sail_macros.h for EVERY .sig.elf build, Spike-referenced ones
# included. Since this project's own ref_model_exe is spike (see
# test_config.yaml), sail.json's own platform.clint/
# simple_interrupt_generator.base values (present here anyway, for if
# this ever switches to Sail) never actually reach the compiler —
# these values are pure placeholders to satisfy sail_macros.h's
# #ifndef guard, never used by anything that runs.
#define SAIL_CLINT_BASE_ADDRESS 0x2000000
#define SAIL_SIMPLE_INTERRUPT_GENERATOR_BASE_ADDRESS 0xC000000

#define RVMODEL_DATA_SECTION \
        .pushsection .tohost,"aw",@progbits;                \
        .balign 8; .global tohost; tohost: .dword 0;         \
        .balign 8; .global fromhost; fromhost: .dword 0;     \
        .popsection

##### STARTUP #####

# RVMODEL_BOOT: no M-mode/CSRs implemented (see test_config.yaml's
# include_priv_tests: False), so RVMODEL_BOOT_TO_MMODE stays
# undefined below (bypasses tests/env/rvtest_setup.h's CSR-writing
# default boot entirely — see rvtest_setup.h: #ifdef
# RVMODEL_BOOT_TO_MMODE / #else #ifdef STANDARD_SM_SUPPORTED, neither
# defined here). RVMODEL_BOOT itself is this core's ONLY boot-time
# hook, so it does everything this project's own crt0.S normally does
# before a test can rely on .data/.bss/the stack being valid:
#   1. gp, same .option norelax idiom as crt0.S (a `la` to a symbol
#      within +/-0x800 of gp gets relaxed to a single gp-relative
#      load — with gp still zero at that point, that reads through a
#      garbage address instead of the real one).
#   2. sp — nothing upstream in rvtest_setup.h sets it (confirmed: no
#      la/li sp anywhere in tests/env/rvtest_setup.h, only sp-relative
#      addi inside the trap handler, which assumes sp is already
#      valid).
#   3. .rodata+.data ROM->RAM copy (_romcopy_load/_romcopy_start/
#      _romcopy_end, see link.ld) — ROM has no write path on real
#      hardware, so these can't already be sitting at their run
#      address in RAM the way a unified-memory target's loader would
#      put them.
#   4. .bss zero (_bss_start/_bss_end, see link.ld).
#define RVMODEL_BOOT                                    \
  .option push                                          ;\
  .option norelax                                       ;\
1:auipc gp, %pcrel_hi(__global_pointer$)                 ;\
  addi  gp, gp, %pcrel_lo(1b)                            ;\
  .option pop                                            ;\
  la    sp, _stack_top                                   ;\
  la    t0, _romcopy_load                                ;\
  la    t1, _romcopy_start                               ;\
  la    t2, _romcopy_end                                 ;\
rvmodel_boot_romcopy:                                    ;\
  bge   t1, t2, rvmodel_boot_romcopy_done                ;\
  lw    t3, 0(t0)                                        ;\
  sw    t3, 0(t1)                                        ;\
  addi  t0, t0, 4                                        ;\
  addi  t1, t1, 4                                        ;\
  j     rvmodel_boot_romcopy                              ;\
rvmodel_boot_romcopy_done:                                ;\
  la    t1, _bss_start                                   ;\
  la    t2, _bss_end                                     ;\
rvmodel_boot_bsszero:                                     ;\
  bge   t1, t2, rvmodel_boot_bsszero_done                ;\
  sw    x0, 0(t1)                                        ;\
  addi  t1, t1, 4                                        ;\
  j     rvmodel_boot_bsszero                              ;\
rvmodel_boot_bsszero_done:

// Left undefined on purpose — see the RVMODEL_BOOT comment above.
//#define RVMODEL_BOOT_TO_MMODE

##### TERMINATION #####

# Same tohost HTIF encoding this project's OWN crt0.S already writes
# on every test's completion (rv32_wait_restart: "1 = pass, 3 = fail
# ((1 << 1) | 1)") — not a new convention, just reused here.
#define RVMODEL_HALT_PASS  \
  li x1, 1                ;\
  la t0, tohost           ;\
  write_tohost_pass:      ;\
    sw x1, 0(t0)          ;\
    sw x0, 4(t0)          ;\
  self_loop_pass:         ;\
    j self_loop_pass      ;\

#define RVMODEL_HALT_FAIL \
  li x1, 3                ;\
  la t0, tohost           ;\
  write_tohost_fail:      ;\
    sw x1, 0(t0)          ;\
    sw x0, 4(t0)          ;\
  self_loop_fail:         ;\
    j self_loop_fail      ;\

##### IO #####

# No initialization needed — the "console" is a single plain RAM
# word (rv32_act_console, see link.ld), watched directly off the
# ram_addr/ram_wdata bus by tools/riscv_build/act/sim/test_act.py,
# not a real UART with a status/ready register to poll.
//#define RVMODEL_IO_INIT(_R1, _R2, _R3)

#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR) \
1:                           ;                        \
  lbu  _R1, 0(_STR_PTR)      ; /* Load byte */        \
  beqz _R1, 3f               ; /* Exit if null */     \
2:                           ;                        \
  la   _R2, rv32_act_console ;                        \
  sb   _R1, 0(_R2)           ;                        \
  addi _STR_PTR, _STR_PTR, 1 ; /* Next char */        \
  j 1b                       ; /* Loop */              \
3:

#endif
