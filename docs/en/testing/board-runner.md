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
| `run` | machine with Quartus and the cable | takes the board lock, programs the `.sof`, runs the stages and writes `results-<board>.json` |
| `act` | machine with Quartus and the cable | takes the board lock, programs the `.sof` and runs `certify-board --skip-build` on the ELFs already built |

The `RISCV_TOOLS` variable gives the `riscv-tools` command, for example `uv run --project <Tools-clone> riscv-tools`. The programmer finds the cable by the IDCODE `02B050DD`, never by the cable name.

## 3. Two boards in parallel

The `--part I/N` option splits the sorted list: board `I` runs the items of index `I` modulo `N`. The laptop takes `/tmp/de0cv-laptop.lock` and PC1 takes `/tmp/de0cv-ws.lock`, each with `--board laptop` and `--board ws`.

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py run --board laptop --part 0/2 --sof de0-cv.sof
```

## 4. ACT4 ELFs

Certification generates the board target with `gen_profiles.py --profile rv32im_full_zifencei --board --out build/target` and builds the ELFs with `riscv-tools --config build/target/config.yaml certify-board --build-only`, in the `ci-act4` image. The runner then runs:

```bash
python3 tools/board/board_run.py act --board ws --part 1/2 --sof de0-cv.sof \
  --config <Certification>/build/target/config.yaml --root <Certification> \
  --target rv32im_full_zifencei__board
```

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
