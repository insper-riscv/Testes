# Two bugs in the "Run per-entity VHDL unit tests" step (`tests/python/`)

🌐 [Português](../../pt-br/bugs/per-entity-tests-ci-breakage.md) · [English](per-entity-tests-ci-breakage.md)

## Context

This step (`uv run python tests/python/runner.py`) is a cocotb test suite **separate** from the `riscv-tools` suite (`Tests/asm`/`Tests/c`) that the rest of this repository uses: it is older, tests individual VHDL entities (`ALU`, `RegFile`, `ROM_simulation`, etc.) and some raw instruction sequences, configured in `tests/python/tests.json`, without going through the `riscv-tools` compiler/linker/`config.yaml`.

Found while investigating why the CI `sim.yml` started failing on this step (after changing the Spike cache, see [MEMORY_ARCHITECTURE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/MEMORY_ARCHITECTURE.md)): both problems below already existed before, they had just never been noticed by anyone running this step to the end.

## Bug 1 (fixed): `ROM.py` used an API removed in cocotb 2.0

```
ImportError: cannot import name 'TestFailure' from 'cocotb.result'
```

`tests/python/unittests/entities/ROM.py` did `from cocotb.result import TestFailure` and `raise TestFailure(...)`: that class **no longer exists in cocotb 2.0** (the project already uses `cocotb>=2.0`, confirmed in the logs themselves: `Initialized cocotb v2.0.1`). The test crashed on the module import, before running any assertion.

**Fix**: the import was removed; `raise TestFailure(...)` became `raise AssertionError(...)`: in cocotb 2.0 any exception raised inside the test already marks it as FAIL, no special class is needed. Verified by running `python3 tests/python/runner.py ROM` alone: `TESTS=1 PASS=1`.

## Bug 2 (not truly fixed; tests marked as `skip`): real regression from the BOOT_MEMORY+FLASH redesign

```
/.../Memory/sim/rom_simulation.vhd:79:12:error: cannot open file: default.hex
in process ...boot_memory@rom_simulation(rtl).init
```

### Root cause

Since the memory redesign (fixed BOOT_MEMORY + FLASH + RAM; see [MEMORY_ARCHITECTURE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/MEMORY_ARCHITECTURE.md)), `rv32i3stage_core_sim_test.vhd` instantiates **two** copies of `ROM_simulation`: one for BOOT_MEMORY (generic `ROM_FILE => BOOT_MEMORY_FILE`) and one for FLASH (generic `ROM_FILE => ROM_FILE`). The 10 configs of the `instructions` group in `tests/python/tests.json` (`one`, `two`, `three`, `four`, `five`, `six`, `MUL`, `FWD`, `LOAD_USE`, `MEXT`) only passed `ROM_FILE`: they were never updated after the redesign to also pass `BOOT_MEMORY_FILE`. Without that generic, BOOT_MEMORY falls back to the default value hardcoded in the entity itself (`"default.hex"`), which does not exist, and the elaboration fails before any test runs.

### Why this is NOT a one-line fix

Just adding `BOOT_MEMORY_FILE` would make the elaboration pass, but the tests would remain **logically wrong**, because each of these 10 modules assumes the old architecture (reset going straight to the contents of `ROM_FILE`, address 0), not the current one (reset always enters through BOOT_MEMORY first, user code only starts at `FLASH_BASE = 0x800` after the boot). Concrete example (`tests/python/unittests/instructions/one.py`):

```python
# PC of each AUIPC: starts at 4 * instruction number (simple single-cycle model)
pcs = [i * 4 for i in range(len(auipc_immediates))]
```

This `pcs` assumes PC = 0, 4, 8, ... from the first cycle: with a real BOOT_MEMORY in front, the execution of the test code would only start at `0x800`, and would still take extra cycles (the BOOT_MEMORY jump itself causes bubbles in the pipeline). The `.hex` files of these tests (`tests/python/unittests/instructions/codes/**/*.hex`) were also generated assuming that their own content starts at address 0 of the array, without the padding that the real `riscv-tools` uses (`bin_to_image.read_words`'s `pad_words`, see `Tests/tools/Tools/src/riscv_tools/bin_to_image/core.py`) to align the content starting at `FLASH_BASE`.

A real fix needs, for each of the 10 tests:
1. A real `BOOT_MEMORY_FILE` (e.g. `boot_memory.hex`, or a minimal stub that only does `j 0x800`);
2. The `.hex` of each test regenerated/realigned with the `FLASH_BASE` padding;
3. The PC/cycle-count computations of each Python module rewritten to count the real boot delay.

This is redesign work, not a parameter tweak: that is why it was not done here.

### What was done for now

The 10 entries in `tests/python/tests.json` gained `"skip": true` + `"skip_reason"` (in the same spirit as the `.off` files already used in the `asm`/`c` suite, see [data-harvard.md](data-harvard.md); only adapted to the single config format of this suite). `tests/python/runner.py` now skips any entry with `"skip": true` when it runs `all` (printing the reason), but still tries to run normally if called explicitly by name (`python3 tests/python/runner.py one`): useful for whoever tackles the real redesign and wants to see the current error without editing `tests.json` back.

Verified locally: `python3 tests/python/runner.py all` now ends with exit code 0 (13 tests pass, 10 skipped, 0 errors): the same command that the CI `sim.yml` runs.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
