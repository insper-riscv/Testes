# Testes

🌐 [Português](README.md) · [English](README.en.md)

Real-hardware and simulation test suite of the `RV32IM` RISC-V core, driven by the `riscv-tools` package, installed in the CI images.

## 1. Documentation

- [AUTHORS.en.md](AUTHORS.en.md): authors with commits in the repository, with name and GitHub account.
- [CONTRIBUTING.en.md](CONTRIBUTING.en.md): mandatory contribution rules, C23 and Python standards, documentation rules, and verification before opening a Pull Request.
- [CITATION.cff](CITATION.cff): software citation metadata.
- [tools/riscv_build/README.md](tools/riscv_build/README.md): conventions specific to this suite (test format, hardware facts, and how to write a new test).
- [docs/HARDWARE_PROGRAMMING.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/HARDWARE_PROGRAMMING.md): permanent rule on compiling and programming the board, and the JTAG bug already diagnosed.
- [docs/MEMORY_ARCHITECTURE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/MEMORY_ARCHITECTURE.md): BOOT_ROM, FLASH, and RAM architecture.
- [docs/RUNTIME.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/RUNTIME.md): C runtime (picolibc, `crt0`, and toolchain linker script), platform file, `stdout`, and Spike.
- [docs/CRT0_BOOT_REFERENCE.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/CRT0_BOOT_REFERENCE.md): boot state, picolibc `crt0`, and `boot_rom.S`.
- [docs/PROGRAM_UPDATE_HANDOFF.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/PROGRAM_UPDATE_HANDOFF.md): FLASH rewrite over JTAG and boot handoff between tests.
- [docs/SIMULACAO_TOPO_FPGA.md](https://github.com/insper-riscv/TopLevel/blob/main/docs/SIMULACAO_TOPO_FPGA.md): hardware-top simulation with the real Quartus memories.
- [docs/bugs/PLL_LOCK_LOSS_BUG.md](docs/bugs/PLL_LOCK_LOSS_BUG.md), [docs/bugs/SMALL_DATA_SECTION_BUG.md](docs/bugs/SMALL_DATA_SECTION_BUG.md), and [docs/bugs/DATA_HARVARD_BUG.md](docs/bugs/DATA_HARVARD_BUG.md): hardware bugs investigated and fixed.
- [docs/bugs/PER_ENTITY_TESTS_CI_BREAKAGE.md](docs/bugs/PER_ENTITY_TESTS_CI_BREAKAGE.md): bugs in the per-entity tests CI.

## 2. Prerequisites

Real-hardware tests require a workstation with Quartus, a self-hosted GitHub Actions runner, and the RISC-V and Spike toolchains configured, as described in the [Infra](https://github.com/insper-riscv/Infra) repository. The simulation suite (`sim`) requires only GHDL and the `sim` extra of `riscv-tools`.

## 3. Repository Structure

| Path | Contents |
| :--- | :--- |
| `asm/`, `c/` | The 89 tests of the suite (52 in assembly and 37 in C), one `<name>/src.S` or `<name>/src.c` per folder |
| `tools/riscv_build/` | This project's configuration for `riscv-tools` (`config.yaml` and `config.fpga-sim.yaml`): it extends the platform one, which lives in [TopLevel](https://github.com/insper-riscv/TopLevel) (toolchain, memory map, runtime, Quartus project, and simulation), and adds only the test paths |
| `tests/python/` | Remaining per-entity tests: raw instruction sequences, all marked `skip`, in `tests.json` ([documentation](tests/python/README.md)) |
| `.github/workflows/` | `real.yml` (real hardware), `sim.yml` (simulation), and `sim-fpga.yml` (hardware-top simulation) |
| `docs/` | Investigated bugs in `docs/bugs/`; the memory architecture, boot, runtime, and board programming are in TopLevel's `docs/` |

## 4. Quick Start

```bash
riscv-tools --config tools/riscv_build/config.yaml generate-header
riscv-tools --config tools/riscv_build/config.yaml compile --emit mif   # real hardware
riscv-tools --config tools/riscv_build/config.yaml compile --emit hex   # simulation
riscv-tools --config tools/riscv_build/config.yaml run                  # real-hardware suite
riscv-tools --config tools/riscv_build/config.yaml sim                  # simulation suite
riscv-tools --root ../TopLevel check-memory-map --platform platforms/internal-mem/platform.yaml   # memory map (in TopLevel)
```

The `uart-tx`, `uart-echo` and `uart-errors` programs run in the simulation of the `internal-mem` platform and on the board, because they use the serial pins of the hardware top. In the simulations of the `sdram` and `sdram-flash` platforms, whose tops only have the UART over JTAG, they are left out with `--exclude uart-echo,uart-tx,uart-errors`.

The `flash-const` and `cpi-kernels` programs of `c-sdram/` need the FLASH behind the caches, and `hex-id` waits for a person at the board. The simulation of the `sdram` platform therefore excludes them, and the `sdram-flash` one runs the first two.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](LICENSE).
