# Runner da placa DE0-CV

🌐 [Português](board-runner.md) · [English](../../en/testing/board-runner.md)

O `tools/board/board_run.py` roda na placa DE0-CV os programas do Tests e, com o config gerado pelo Certification, os ELFs do ACT4. Cada item recebe PASS, FAIL ou TIMEOUT, e o runner escreve um JSON por placa.

## 1. Etapas

| Etapa | Config | Programas |
| :--- | :--- | :--- |
| `regression` | `config.sdram-flash-regression.yaml` | `asm/` e `c/`, menos os três da UART física |
| `sdram` | `config.sdram-flash.yaml` | `asm-sdram/` e `c-sdram/` |
| `irq` | `config.sdram-flash-irq.yaml` | `asm-irq/`, ligados ao CLINT real da plataforma em `0xE0000000` |

Os programas `uart-echo`, `uart-tx` e `uart-errors` usam os pinos da UART, que as placas não têm ligados. O `hex-id` pausa para uma pessoa ler o display, e por isso o runner dá a ele um timeout de 90 s.

## 2. Subcomandos

| Subcomando | Onde roda | O que faz |
| :--- | :--- | :--- |
| `prepare` | imagem `ci-elf`, sem placa | `generate-header` e `compile --emit mif` de cada etapa |
| `run` | máquina com Quartus e cabo | toma o lock da placa, programa o `.sof`, roda as etapas e escreve `results-<placa>.json` |
| `act` | máquina com Quartus e cabo | toma o lock da placa, programa o `.sof` e roda `certify-board --skip-build` sobre os ELFs já construídos |

A variável `RISCV_TOOLS` dá o comando do `riscv-tools`, por exemplo `uv run --project <clone-do-Tools> riscv-tools`. O programador acha o cabo pelo IDCODE `02B050DD`, nunca pelo nome do cabo.

## 3. Duas placas em paralelo

A opção `--part I/N` reparte a lista ordenada: a placa `I` roda os itens de índice `I` módulo `N`. O notebook toma `/tmp/de0cv-laptop.lock` e a PC1 toma `/tmp/de0cv-ws.lock`, cada uma com `--board laptop` e `--board ws`.

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py run --board laptop --part 0/2 --sof de0-cv.sof
```

## 4. ELFs do ACT4

O Certification gera o alvo da placa com `gen_profiles.py --profile rv32im_full_zifencei --board --out build/target` e constrói os ELFs com `riscv-tools --config build/target/config.yaml certify-board --build-only`, na imagem `ci-act4`. O runner roda então:

```bash
python3 tools/board/board_run.py act --board ws --part 1/2 --sof de0-cv.sof \
  --config <Certification>/build/target/config.yaml --root <Certification> \
  --target rv32im_full_zifencei__board
```

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
