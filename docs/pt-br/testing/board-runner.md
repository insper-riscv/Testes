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
| `run` | máquina com Quartus e cabo | escolhe a placa pelo JTAG e toma a trava dela, programa o `.sof`, roda as etapas e escreve `results-<host>.json` |
| `act` | máquina com Quartus e cabo | escolhe e trava a placa, programa o `.sof` e roda `certify-board --skip-build` sobre os ELFs já construídos |

A variável `RISCV_TOOLS` dá o comando do `riscv-tools`, por exemplo `uv run --project <clone-do-Tools> riscv-tools`. O runner não guarda IDCODE nem nome de trava. Quem acha a placa é o `riscv-tools board lock`, pelo IDCODE da cadeia e pela porta USB do cabo (pacote `Insper-RISC-V/boards/de0-cv`), nunca pelo nome do cabo; o cabo escolhido segue para o `quartus_pgm` e, por `--cable`, para os `riscv-tools` filhos. Ver o módulo `board` do Tools.

## 3. Duas placas em paralelo

A opção `--part I/N` reparte a lista ordenada: a placa `I` roda os itens de índice `I` módulo `N`. O rótulo do host (`--host laptop` ou `--host ws`, também aceito como `--board`) entra no nome da trava, `de0cv-laptop.lock` e `de0cv-ws.lock`, o mesmo arquivo que os demais usuários da placa tomam. Com `--part auto` o runner toma uma placa livre do host e reparte a lista entre todas as placas da plataforma que o host tem, na ordem do identificador delas.

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py run --host laptop --part 0/2 --sof de0-cv.sof
```

## 4. ELFs do ACT4

O Certification gera o alvo da placa com `gen_profiles.py --profile rv32im_full_zifencei --board --out build/target` e constrói os ELFs com `riscv-tools --config build/target/config.yaml certify-board --build-only`, na imagem `ci-act4`. O runner roda então:

```bash
python3 tools/board/board_run.py act --host ws --part 1/2 --sof de0-cv.sof \
  --config <Certification>/build/target/config.yaml --root <Certification> \
  --target rv32im_full_zifencei__board
```

## 5. Programas de atualização, Zihpm reduzido e PLIC

O `tools/board/board_update.py` conduz os programas que o `riscv-tools run` sozinho não conduz, com o lock da placa e `--board laptop` ou `--board ws`.

| Etapa | Programas | Condução |
| :--- | :--- | :--- |
| `update` | `flash-update`, `flash-update-interrupted` e `update-new` | Zera a palavra de sobrevivência da SDRAM e o `tohost`, grava a FLASH inteira pelo carregador JTAG, envia a imagem da banca B pela UART (`flash-image send`) e confere o `stdout` com o `uart_expected.txt`. O `update-new` roda sozinho, gravado na banca B |
| `plic` | `plic-flash` | Roda com o console da UART ligado, que esvazia a fila de transmissão |

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  uv run --project ../Tools python tools/board/board_update.py --board laptop
```

O `hpm-reduced` (`config.sdram-flash-hpm-reduced.yaml`) exige o bitstream reduzido, com 4 contadores de 40 bits, e falha no completo. Compila-se com `quartus_sh -t de0-cv_synth.tcl 1 HPM_COUNTERS=4 HPM_WIDTH=40` e roda-se com `riscv-tools --config tools/riscv_build/config.sdram-flash-hpm-reduced.yaml run --skip-reconfigure --skip-recompile`, depois de programar o `.sof` reduzido.

A FLASH da placa é regravada pelo carregador JTAG (`quartus.rom_write_method: jtag_loader`), que reinicia o núcleo a cada programa; a porta de depuração da SDRAM é a instância 3 do Virtual JTAG (`quartus.sdram_debug_instance`).

## 6. Outras placas

A opção as etapas `de0-nano-*` e `de10-lite-*` (`--stages`) trazem a placa delas. Nas plataformas que ligam só parte das extensões, o `prepare` compila só os programas cujo cabeçalho `RV32_EXT` cita extensões que a plataforma tem, e o runner nunca vê os outros.

| Plataforma | Placa | Extensões dos programas | Etapas |
| :--- | :--- | :--- | :--- |
| `de0-nano` | `de0-nano` | Zicsr e Zifencei (RV32I) | `de0-nano-regression`, `de0-nano-sdram` |
| `de10-lite` | `de10-lite` | As do perfil completo | `de10-lite-regression`, `de10-lite-sdram`, `de10-lite-irq` |

```bash
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py prepare --stages de0-nano-regression de0-nano-sdram
RISCV_TOOLS="uv run --project ../Tools riscv-tools" \
  python3 tools/board/board_run.py run --stages de0-nano-regression de0-nano-sdram --host ws --sof de0-nano.sof
```

O arquivo `include-<plataforma>/rv32_platform.h` de cada plataforma repete o mapa do `platform.yaml` dela, e o `config.platform-<plataforma>.yaml` sai do `platform sync`.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
