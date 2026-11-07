# DE0-CV board runner

🌐 [Português](../../pt-br/testing/board-runner.md) · [English](board-runner.md)

`tools/board/board_run.py` runs the programs of Tests on the DE0-CV board and, with the config that Certification generates, the ACT4 ELFs. Each item gets PASS, FAIL or TIMEOUT, and the runner writes one JSON per board.

## 1. Stages

| Stage | Config | Programs |
| :--- | :--- | :--- |
| `regression` | `config.sdram-flash-regression.yaml` | `asm/` and `c/`, minus the three physical UART ones |
| `sdram` | `config.sdram-flash.yaml` | `asm-sdram/` and `c-sdram/` |
| `irq` | `config.sdram-flash-irq.yaml` | `asm-irq/`, wired to the real CLINT of the platform at `0xE0000000` |

`uart-echo`, `uart-tx` and `uart-errors` use the UART pins, which the boards do not have wired. `hex-id` pauses for a person to read the display, so the runner gives it a 90 s timeout.

## 2. Subcommands

| Subcommand | Where it runs | What it does |
| :--- | :--- | :--- |
| `prepare` | `ci-elf` image, no board | `generate-header` and `compile --emit mif` of each stage |
| `run` | machine with Quartus and the cable | selects the board through JTAG and takes its lock, programs the `.sof`, runs the stages and writes `results-<host>.json` |
| `act` | machine with Quartus and the cable | selects and locks the board, programs the `.sof` and runs `certify-board --skip-build` on the ELFs already built |

The `RISCV_TOOLS` variable gives the `riscv-tools` command, for example `uv run --project <Tools-clone> riscv-tools`. The runner keeps no IDCODE or lock name. `riscv-tools board lock` finds the board by the IDCODE of the chain and the USB port of the cable (package `Insper-RISC-V/boards/de0-cv`), never by the cable name; the chosen cable goes to `quartus_pgm` and, through `--cable`, to the child `riscv-tools`. See the `board` module of Tools.

## 3. Two boards in parallel

The `--part I/N` option splits the sorted list: board `I` runs the items of index `I` modulo `N`. The host label (`--host laptop` or `--host ws`, also accepted as `--board`) goes into the lock name, `de0cv-laptop.lock` and `de0cv-ws.lock`, the same file the other users of the board take. With `--part auto` the runner takes a free board of the host and splits the list among all the boards of the platform that the host has, in the order of their identifiers.

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py run --host laptop --part 0/2 --sof de0-cv.sof
```

## 4. ACT4 ELFs

Certification generates the board target with `gen_profiles.py --profile rv32im_full_zifencei --board --out build/target` and builds the ELFs with `riscv-tools --config build/target/config.yaml certify-board --build-only`, in the `ci-act4` image. The runner then runs:

```bash
python3 tools/board/board_run.py act --host ws --part 1/2 --sof de0-cv.sof \
  --config <Certification>/build/target/config.yaml --root <Certification> \
  --target rv32im_full_zifencei__board
```

## 5. Other boards

The `--platform` option (`de0-cv`, the default, `de0-nano` or `de10-lite`) switches the board to look for and the stages. On the platforms that turn on only part of the extensions, `prepare` compiles only the programs whose `RV32_EXT` header names extensions that the platform has, and the runner never sees the others.

| Platform | Board | Extensions of the programs | Stages |
| :--- | :--- | :--- | :--- |
| `de0-nano` | `de0-nano` | Zicsr only (RV32I) | `regression`, `sdram` |
| `de10-lite` | `de10-lite` | Those of the full profile | `regression`, `sdram`, `irq` |

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py prepare --platform de0-nano
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py run --platform de0-nano --host ws --sof de0-nano.sof
```

The file `include-<platform>/rv32_platform.h` of each platform repeats the map of its `platform.yaml`, and `config.platform-<platform>.yaml` comes from `platform sync`.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
