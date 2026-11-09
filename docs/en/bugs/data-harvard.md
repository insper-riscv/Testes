> **Update**: this bug was fixed for good at the hardware level: `.data` with a non-zero initial value works normally now. See [Definitive fix: modified Harvard](#definitive-fix-modified-harvard) below. The rest of this document (the original investigation + the software mitigation that came before the hardware fix) stays as a record of how the bug was found and diagnosed.

# Bug: `.data` (globals with a non-zero initial value) does not work on this core

🌐 [Português](../../pt-br/bugs/data-harvard.md) · [English](data-harvard.md)

## Summary

This core (`rv32im_pipeline_core`) is a **true Harvard** architecture: the ROM (`rom_addr`) and RAM (`ram_addr`) buses are physically independent, and `lw`/`sw` **never** reach the ROM: only the *program counter* (instruction fetch) uses the ROM bus. This means the standard `.data` mechanism (copying the initial value from ROM to RAM at boot) **cannot work at all** on this hardware, regardless of any fix in `crt0.S`/`link.ld`.

This is **not a requirement of the RISC-V ISA**: most RISC-V implementations (including embedded ones) use a unified memory map (von Neumann) or a "modified" Harvard where the data bus still reaches the program region, allowing `.data` to work normally. It is a design choice **specific to this educational core**, not a limit of the standard.

## How it was discovered (full investigation)

### 1. Initial symptom: a "hang"

`data-init-byte` (`c/data-init-byte/src.c`, at the time with `static volatile unsigned char value = 0xA5u;`) reported `no mailbox result after 15.0s`: no PASS, no FAIL. Consistently reproduced (the same 42-test suite run several times always stopped exactly at this test, with everything else around it passing cleanly), which ruled out a coincidence of JTAG instability (see [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md) for the different "chain broken" problem in the programming step).

### 2. `gp`/`.sdata`: a real fix, but not enough

The first cause found was a `gp` (global pointer) never initialized in `crt0.S`, which left small globals (`.sdata`, `gp`-relative addressing) outside the range that `crt0.S` knew how to copy/zero: see [small-data-section.md](small-data-section.md) and [CRT0_BOOT_REFERENCE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/CRT0_BOOT_REFERENCE.md) for that complete fix (which remains valid and necessary; it just was not the full cause of this specific bug).

After fixing `gp`/`tp` and adding `.sdata`/`.sbss`/`.tdata`/`.tbss` to `link.ld`, `data-init-byte` **kept failing**, in exactly the same way.

### 3. The question that solved it: "does it really hang, or does only the read fail?"

Instead of assuming it was a CPU hang, the mailbox was read **manually, just once**, without going through the orchestrator's automatic polling loop:

```bash
# writes the test ROM, pulses the go-flag, waits, reads the mailbox directly
quartus_stp -t write_full.tcl "USB-Blaster [1-4]" "@1: ..." 0 data-init-byte.mif
quartus_stp -t write_word.tcl "USB-Blaster [1-4]" "@1: ..." 1 4094 1   # go-flag
sleep 5
quartus_stp -t read_words.tcl "USB-Blaster [1-4]" "@1: ..." 1 4095 1  # mailbox
```

Result: **mailbox = 2 (FAIL)**. The CPU **did not hang**: it ran to the end and correctly wrote FAIL, given the value it read (wrong, but it did not know that). Reading `RAM[0]` (where `value` should be) confirmed: `0`, not `0xA5`: the `.data`→ROM copy loop of `crt0.S` copied garbage (whatever was already in `RAM[_data_load]`, an address reused by numeric coincidence of the ROM space), not the real ROM value.

That led to the confirmation in the VHDL:

```
# rv32im_pipeline_core.vhd
ram_addr <= exmem_alu_out;
```

`ram_addr` comes **directly** from the ALU in the EX/MEM stage: that is, from any `lw`/`sw`. `rom_addr` is a completely separate line, plugged only into `pc_fetch`. There is no physical path from a `lw`/`sw` to the ROM.

### 4. The real "timeout" bug: too much JTAG polling, too fast

If the CPU does not hang, why does the orchestrator report a timeout? `config.yaml` had `poll_interval_seconds: 0.5`: with a 15 s timeout, this allows up to **~30 separate `quartus_stp` calls**, each opening and closing its own JTAG/In-System Memory Editor session from scratch, in quick sequence. This is the same class of fragility already documented for the `quartus_sh`→`quartus_pgm` handoff (see [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md)), only multiplied by ~30 attempts in a 15 s window instead of two isolated attempts.

The manual read (one call, with real time to spare) worked the first time, confirming that the volume of rapid repeated calls, not the hardware itself, is what causes the read failure.

## The two fixes applied

1. **`poll_interval_seconds` `0.5` → `2.5`** (`config.yaml`): fewer JTAG sessions opened/closed in the timeout window, trading detection latency for read reliability.

2. **Compile-time check** (`Tools/compiler/build.py`, `_check_data_section_empty`): `riscv-tools compile` now fails immediately, with a message explaining why, if a test produces a non-empty `.data`, instead of letting it run and silently corrupt. `.bss` (zero-init) keeps working normally: `crt0.S` zeroes it with plain `sw`, without needing to read anything from the ROM.

## Definitive fix: modified Harvard

The two fixes above (`poll_interval_seconds` + compile-time check) were a **mitigation**: they prevented a non-empty `.data` from silently corrupting a test, but did not make `.data` work: the core still had no path from the MEM stage to the ROM.

That changed with the 3-part memory redesign (BOOT_MEMORY, a fixed bootloader; FLASH, the firmware of each test; RAM, data), which gave the MEM stage a second read port to FLASH specifically for the `.data` copy loop at boot. `.data` with a non-zero initial value works normally now; the compile-time check and the "`.bss` only" restriction described above no longer apply.

See [MEMORY_ARCHITECTURE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/MEMORY_ARCHITECTURE.md) for the complete architecture (memory map, the Quartus Lite limit that required a second physical copy of FLASH, JTAG indices, LEDs).

## How to write a test that needs a non-zero initial value

> **Note**: the restriction below is historical: it describes how to work around the bug **before** the definitive fix above. Today a plain C initializer at file scope (`static volatile unsigned int value = 0xCAFEBABEu;`) works normally; the text stays as a record of how the bug was worked around while no hardware fix existed.

Do not use a C initializer at file scope:

```c
// WRONG: becomes .data, fails to compile with this project
static volatile unsigned int value = 0xCAFEBABEu;
```

Declare without an initializer (becomes `.bss`, zero-init works normally) and assign inside a function:

```c
// RIGHT: becomes .bss + a normal li/sw instruction inside main(),
// never depends on reading the ROM via lw/sw
static volatile unsigned int value;

int main(void) {
    value = 0xCAFEBABEu;
    if (value != 0xCAFEBABEu) RV32_FAIL();
    RV32_PASS();
}
```

## Disabled tests (`.off`): history, does not reflect the current state

> This section describes the situation **before** the definitive fix above. With the hardware fix, the five tests below were re-enabled (no `.off` file) and pass normally, including with the original `static volatile ... = 0xCAFEBABEu;` at file scope. The original text stays as a record of why they were turned off while the bug existed.

Five tests existed specifically to verify that `.data` initializes correctly: `c/data-init-byte`, `c/data-init-halfword`, `c/data-init-word`, `c/data-init-word-array`, `c/data-initialization`. Since this mechanism was impossible on this hardware (it was not a bug to fix, it was a characteristic of the core's design), rewriting them to "assign in `main()`" would make them test something completely different (only "I can write/read a variable", redundant with dozens of other tests) under a misleading name.

Each folder had a `.off` file (content = reason, read and printed by `riscv-tools compile`) that made the test discovery skip the whole folder, without deleting the original source code: see `_discover_tests` in `Tools/src/riscv_tools/cli.py`. This was different from simply removing the tests: the code stayed in the repository, versioned, with the exact reason it was turned off recorded right there, in case the core gained support for a unified memory map in the future.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
