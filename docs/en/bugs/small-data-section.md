# Bug: small initialized `.data` globals were never copied (`.sdata`/`gp`)

🌐 [Português](../../pt-br/bugs/small-data-section.md) · [English](small-data-section.md)

## Symptom

`data-init-byte` (`c/data-init-byte/src.c`) hung completely against the real hardware: it gave neither PASS nor FAIL, it simply never wrote anything to the mailbox (`no mailbox result after 15.0s`). Reproduced **3 out of 3 times**, in isolation (`--only data-init-byte --skip-reconfigure`, freshly programmed board, no other test running before), definitively ruling out the hypothesis that it was one more case of the intermittent JTAG bug already documented in [HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md): that one breaks the JTAG *connection* (`jtagconfig` stops seeing the board); this bug makes the *RISC-V program* hang, with JTAG staying healthy the whole time.

The test itself is deliberately trivial:

```c
// RV32_TEST_KIND: unit
#include "rv32_test.h"

/* Diagnoses initialization of a one-byte .data object. */
static volatile unsigned char value = 0xA5u;

int main(void) {
    if (value != 0xA5u) RV32_FAIL();
    RV32_PASS();
}
```

## Investigation

Comparing the generated `.elf` with the expected memory map:

```bash
riscv32-unknown-elf-nm -S build/real/data-init-byte.elf | grep -E "_data_|value"
```

```
00000000     1 OBJECT  LOCAL  DEFAULT    2 value
00000000     D _data_end
00000000     D _data_start
```

`_data_start` and `_data_end` are **equal** (`0x00000000` both), even though `value` really exists, with address `0x0` and size `1`. The `.data` copy loop of `crt0.S` is:

```asm
    la t0, _data_load
    la t1, _data_start
    la t2, _data_end
1:
    bge t1, t2, 2f      // _data_start >= _data_end → exits IMMEDIATELY
    lw  t3, 0(t0)
    sw  t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j   1b
2:
```

With `_data_start == _data_end`, the `bge` on the first iteration is already true: the loop **never copies anything**. `value` keeps whatever was already in RAM (undefined on real hardware: `crt0.S` explicitly documents "RAM starts blank on real hardware"), not `0xA5`.

That alone would already explain an `RV32_FAIL()`, but the real symptom was a **total hang**, without even writing FAIL to the mailbox. A second piece was missing.

### The wrong section

```bash
riscv32-unknown-elf-readelf -S build/real/data-init-byte.elf | grep -E "\.data|\.sdata"
```

```
[ 2] .sdata            PROGBITS        00000000 002000 000001 00  WA  0   0  1
```

`value` did not end up in `.data`, it ended up in **`.sdata`** (the RISC-V "small data" section). The RISC-V GCC redirects small globals (by default, objects up to 8 bytes) to `.sdata`/`.sbss`, addressed relative to the `gp` register (`gp`-relative addressing) instead of absolute addressing: a standard code-size optimization of the ABI.

The `link.ld` of this project only matches `*(.data*)`/`*(.bss*)`:

```ld
.data : {
    _data_start = .;
    *(.data*)          /* does not match .sdata* */
    _data_end = .;
} > RAM AT> ROM
```

`.sdata` is not a classic "orphan" section (`ld` can still place it, since `WA` matches what `.data`/`.bss` accept), but since there is no explicit rule for it, the linker places it **after** `_data_end` has already been computed: in practice, at the same address where `.data` "stopped" (`0x0`, since there was nothing else in `.data`/`.bss` before it in this minimal test). Result: `value` physically exists in the image, but outside the range that `crt0.S` knows it has to copy/zero.

### Why it hangs, instead of just failing

`.sdata`/`.sbss` are addressed via `gp` (`lb rd, offset(gp)` instead of an absolute address): that is how RISC-V gets shorter instructions for these accesses. This only works if the `gp` register is correctly initialized, normally pointing near the middle of the `.sdata`/`.sbss` region (`__global_pointer$` convention).

**`crt0.S` never initializes `gp`**: there is no infrastructure at all for that in this project (it was never needed, because nothing used `.sdata` until a small enough test appeared). So any `gp`-relative access uses the value `gp` had at reset, which is not "a wrong value", it is **an arbitrary address**. Reading/writing at an arbitrary address is undefined behavior: it may silently read garbage, but it may also access a region outside the valid RAM/ROM range of the core (Harvard, no MMU, no exception handling) and hang the pipeline, which matches exactly the observed symptom (total hang, mailbox never written).

## Fix

**Historical note**: the first fix attempted here was to disable small-data generation entirely via `-msmall-data-limit=0` in `gcc` (`Tools/src/riscv_tools/compiler/build.py`): simple, but "oversimplified", it makes every small object slower (always absolute addressing, never `gp`-relative) without solving the root cause. It was reverted in favor of the real fix below, which follows the official RISC-V ABI instead of deviating from it; see the [psABI doc](https://github.com/riscv-non-isa/riscv-elf-psabi-doc).

The definitive fix has two parts:

**1. Really initialize `gp` in `crt0.S`**, the first thing in `_start`, before any other `la` (which the assembler/linker may relax to `gp`-relative if `gp` is already "valid", hence the `.option norelax` around it):

```asm
.option push
.option norelax
1:  auipc gp, %pcrel_hi(__global_pointer$)
    addi  gp, gp, %pcrel_lo(1b)
.option pop
```

**2. Give `.sdata`/`.sbss`/`.srodata` an explicit rule in `link.ld`**, inside the same range that `crt0.S` already knows how to copy/zero (`*(.data*)` alone did not match these sections, see "The wrong section" above):

```ld
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

.sbss (NOLOAD) : {
    _bss_start = .;
    *(.dynsbss)
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
} > RAM
```

`__global_pointer$` sits at the start of `.sdata` + `0x800`: the convention of the RISC-V `ld` itself (signed 12-bit immediates, `gp` reaches `.data` backwards and `.sbss` forwards, both within range).

Along with this fix came the equivalent initialization of `tp` (x4), the same class of bug; nothing uses it today, but it is ready; see [CRT0_BOOT_REFERENCE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/CRT0_BOOT_REFERENCE.md).

**Important**: this fix alone was NOT enough to make `data-init-byte` pass: `.sdata` no longer falling outside the copied range solves *this* symptom, but it exposed a much more fundamental bug of the core (the ROM was never reachable by a `lw`/`sw`, so even copying from the right address, the value read from there came out wrong); see [data-harvard.md](data-harvard.md) for the full investigation and the architecture fix that solved it for good.

## Why it only showed up now

The original test suite (the 11 splits of `full.S`, `example-add`, etc.) always worked with arrays/structures larger than the small-data limit (8 bytes), or wrote directly to fixed addresses via assembly, and never exposed this path. The bug only became visible when new, deliberately tiny tests (`data-init-byte`, `data-init-halfword`) were added specifically to isolate initialization cases: the exact kind of thing this compiler optimization pattern affects.

## Lesson for new tests

Any small `.data`/`.bss` global (a few bytes) is a candidate to fall into `.sdata`/`.sbss` if `-msmall-data-limit=0` is ever removed or overridden. If that happens again, the symptom will be the same: a complete hang (not a clean failure) in tests with few small variables. `nm -S`/`readelf -S` on the generated `.elf` (looking for `.sdata`/`.sbss`, or `_data_start == _data_end` with real objects in `.data`) is the fastest way to confirm whether it is this again.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
