# Contribution Guide

🌐 [Português](CONTRIBUTING.md) · [English](CONTRIBUTING.en.md)

This document defines the mandatory coding, structural organization, documentation, and verification rules for any contribution to the `Testes` repository.

## 1. C Standard (C23)

All C code in the project (test programs, runtime, and fixtures) is written under the **ISO/IEC 9899:2024 (C23)** standard and compiled with `-std=c23`, never with `-std=gnu23` or compiler extensions that bypass the standard.

| Rule | Specification |
| :--- | :--- |
| Language standard | C23 (`-std=c23`, never `-std=gnu23`) across all `.c` and `.h` files; `riscv-tools` passes the flag on every compile |
| Warnings | `-Wall -Wextra -Wpedantic -Werror`, passed by `riscv-tools` on every compile; no warning is accepted |
| Execution environment | Hosted, with picolibc: programs compile with the platform `--specs`, without `-ffreestanding`, and `main` returns to the crt0, which calls `exit` |
| Headers | The standard guarantees in a freestanding environment only `<float.h>`, `<iso646.h>`, `<limits.h>`, `<stdalign.h>`, `<stdarg.h>`, `<stdbit.h>`, `<stdbool.h>`, `<stddef.h>`, `<stdint.h>`, and `<stdnoreturn.h>` (clause 4); `<stdio.h>` and `<stdlib.h>` come from picolibc and only the programs that test the library include them |
| Fixed-width types | `<stdint.h>` (`uint32_t`, `int32_t`, `uintptr_t`) instead of `int`, `unsigned`, and `long` whenever width matters; `int` stays for counters and return codes |
| C23 keywords | Use `bool`, `true`, `false`, `nullptr`, `constexpr`, `alignas`, `static_assert` without a message, and `typeof`; do not include `<stdbool.h>` or `<stdalign.h>` and do not use `NULL` |
| Attributes | Standard `[[nodiscard]]`, `[[maybe_unused]]`, `[[noreturn]]`, `[[fallthrough]]`, and `[[deprecated]]` syntax instead of `__attribute__`; `alignas(n)` instead of `aligned(n)`; `[[gnu::noinline]]` and `[[gnu::weak]]` only where the standard has no equivalent, with a comment that states the reason |
| Constants | `static constexpr` with a fixed-width type instead of numeric `#define`; `enum : uint32_t` for groups of masks and addresses; binary literals (`0b1010`) and digit separators (`1'000'000`) are allowed |
| `#define` that stays | Only where a `.S` file or an `#if` reads the value, where the pointer targets a fixed address (a `constexpr` pointer accepts only the null pointer, clause 6.7.2), or where the file is generated; each one carries a comment with the reason |
| Naming | Identifiers in **English** with `snake_case`, constants and macros in `UPPER_SNAKE_CASE`, types with the `_t` suffix; no `<stdint.h>` aliases (such as `u32`) and no names POSIX reserves (such as `LINE_MAX`); comments in **Portuguese** |
| Comments | Every function, global variable, constant, and macro has a descriptive comment in Portuguese immediately above its declaration |

### 1.1. Behavior the standard does not define

| Topic | Rule |
| :--- | :--- |
| MMIO registers | The address is an integer constant converted to a `volatile` pointer of the register width (clauses 6.3.3.3 and 6.7.4.1), always aligned to that width, in a single macro or `static inline` function per register |
| Misaligned access | Undefined in C; a test that measures misaligned access does it with an explicit instruction (`lw`, `sw`) in `__asm__ volatile`, never through a pointer |
| Shifts | A negative count, or one greater than or equal to the width, is undefined (clause 6.5.8); `>>` of a negative value is implementation-defined and appears only in a test that measures the `sra` instruction, with a comment that cites the clause; the other shifts use an unsigned operand |
| Aliasing and effective type | Only character types access any object (clause 6.5.1); half-word reads of data written as a word go through an explicit instruction (`lh`, `lhu`, `sh`) |
| Writing to a `const` object | Undefined (clause 6.7.4.1); a test that needs a write to the FLASH does the write with an explicit instruction and reads back through a `volatile` pointer |
| Function pointer | The conversion goes through `uintptr_t`, which the implementation defines (clause 6.3.3.3); direct conversion from an object pointer to a function pointer is not defined |
| Pointer subtraction | Only between elements of the same array (clause 6.5.7); the size of a block of code or data comes from a constant, not from the difference of two symbols |
| `alignas` and `static_assert` | `alignas(n)` sets the alignment (clause 6.7.6); every structure offset that assembly reads at a fixed position has a `static_assert` with `offsetof` (clauses 6.7.12 and 7.21) |

### 1.2. Compiler extensions

No GCC flag forbids `__attribute__`, `__asm__`, or `__builtin_*`, so review checks what the standard does not cover. The only accepted extension is `__asm__`, because `asm` is not a keyword of the standard (clause 6.4.2) and `__asm__` does not conflict with `-std=c23`; it is limited to instructions C cannot express (CSR reads, `fence.i`, and the `lh`, `lhu`, `sh`, `lw`, and `sw` that the test measures) and to the FLASH update routine, always with a comment. The `[[gnu::...]]` attributes, the runtime `__strong_reference`, and `__builtin_*` enter only with a comment that states why the standard has no equivalent; for an unreachable path end, use `unreachable()` from `<stddef.h>`.

The reference standard is [ISO/IEC 9899:2024](https://www.iso.org/standard/82075.html). In academic work, cite it with the BibTeX entry below:

```bibtex
@misc{iso9899,
  title        = {Information technology, Programming languages, C},
  author       = {{ISO/IEC}},
  year         = {2024},
  note         = {ISO/IEC 9899:2024 (C23)},
  howpublished = {\url{https://www.iso.org/standard/82075.html}}
}
```

## 2. Python Standards

| Rule | Specification |
| :--- | :--- |
| Package manager | `uv` (`uv add`, `uv sync`, `uv run`); `pip`, `pip install`, and `python -m pip` are prohibited |
| Tests | `pytest`; every new behavior comes with a test |
| Code documentation | NumPy-style docstrings on public modules, classes, and functions |
| Typing | Complete annotations, checked by Pyright in `strict` mode |
| Style and quality | `ruff` for lint and formatting; `deptry` for declared and used dependencies |
| Naming | Identifiers in **English** with `snake_case`; comments and docstrings in **Portuguese** |

## 3. Markdown Documentation Rules

Every `README`, `CONTRIBUTING`, and `AUTHORS` maintains mirrored versions in Portuguese (`*.md`) and English (`*.en.md`), following these rules:

1. **Language switcher and license footer:** every `README.md` and `README.en.md` includes the `🌐 [Português](...) · [English](...)` switcher at the top, and every `.md` file ends with the copyright footer linking to `LICENSE`.
2. **Numbered progressive sections:** all sections starting at `##` must be numbered (`## 1.`, `### 1.1.`, `## 2.`) in a logical reading order.
3. **Direct punctuation:**
   - **Em-dashes are prohibited** in prose and tables; use commas, parentheses, semicolons, or colons according to the actual syntactic relationship.
   - **Chained colons are prohibited** (more than one `:` in the same sentence or table cell).
4. **Behavior explanation:** never cite an internal file, module, or signal name as if the name itself explained what the system does; always describe the operation performed.
5. **Non-redundant tables and LaTeX:** structured data belongs in Markdown tables and mathematical/boolean equations in LaTeX blocks (`$$ ... $$` or `$ ... $`), without repeating in prose what the table or equation already states.
6. **No changelog or open TODOs in technical docs:** architecture and contract documents describe exclusively the current state, without historical bugfix notes or unimplemented work lists.
7. **Usage guides only instruct:** installation and run instructions say how to do it, without justifying the choice of method.

## 4. Mandatory Verification Before Opening a Pull Request

Any change to code, configuration, or documentation must pass all commands below without errors before submission:

```bash
uv run riscv-tools --config tools/riscv_build/config.yaml compile --emit hex  # Compiles every test program
uv run riscv-tools --config tools/riscv_build/config.yaml sim                 # Runs the simulation suite
uv run riscv-tools --root . check-tree --kind tests                           # Repository tree
```

The `tree` job, in its own workflow, checks the repository tree with `riscv-tools check-tree`.

When adding, renaming, or removing any versioned file, immediately update:
- `tools/riscv_build/config.yaml`
- `docs/`
- `README.md`, `README.en.md`, and the affected documentation

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
