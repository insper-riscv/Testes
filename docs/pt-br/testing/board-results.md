# Resultados dos programas na placa DE0-CV

🌐 [Português](board-results.md) · [English](../../en/testing/board-results.md)

## 1. Condições

| Item | Valor |
| :--- | :--- |
| Bitstream completo | `de0-cv.sof` do Insper-RISC-V `ceea999` (perfil `rv32im_zicclsm_zicntr_zihpm_zifencei` com Zimop, Zicond, Zihintntl, Zihintpause, interrupções com PLIC e o controlador de FLASH), semente 1, 29 contadores de 64 bits |
| Bitstream reduzido | O mesmo código com `HPM_COUNTERS=4 HPM_WIDTH=40` (`de0-cv_synth.tcl 1 HPM_COUNTERS=4 HPM_WIDTH=40`), 4 contadores de 40 bits |
| Os cinco programas do `board_update.py` | Repetidos com os bitstreams completo e reduzido do Insper-RISC-V `1c2137d` (SDRAM a 100 MHz e fase do núcleo em 8250 ps), com o mesmo resultado nas duas placas |
| Clock do núcleo | 50 MHz (pior folga de setup do Quartus: -0,745 ns) |
| Placas | notebook (`/tmp/de0cv-laptop.lock`) e PC1 (`/tmp/de0cv-ws.lock`), em paralelo, lista repartida por `--part 0/2` e `1/2` |
| Runner | [board-runner.md](board-runner.md) |

## 2. Resumo

154 de 154 programas passaram com o bitstream completo: 127 de `asm/` e `c/` (etapa `regression`), 20 de `asm-sdram/` e `c-sdram/` (etapa `sdram`) e 7 de `asm-irq/` (etapa `irq`). Os cinco programas abaixo, que o runner `board_run.py` não cobre, também passaram nas duas placas: `flash-update`, `flash-update-interrupted` e `update-new` (etapa `update`), `hpm-reduced` com o bitstream reduzido e `plic-flash` (etapa `plic`), conduzidos pelo `board_update.py` ([board-runner.md](board-runner.md)).

## 3. Programas fora da lista

| Programa | Motivo |
| :--- | :--- |
| `uart-echo`, `uart-tx`, `uart-errors` | Usam os pinos físicos da UART, que as placas não têm ligados; é o único teste que pode falhar na placa |
| `asm-plic/` (`plic-timer`, `plic-switches`, `plic-keys`, `plic-uart`, `plic-uart-jtag`, `plic-priority`) | Usam o temporizador, as GPIO e a UART de pinos da plataforma `modular`, que o topo da placa não tem; a placa só tem as fontes `UART_JTAG` e `FLASH`, e o `plic-uart-jtag` e o `plic-priority` dependem de um hospedeiro de latência de ciclos (`fromhost`), que o JTAG da placa não oferece |

## 4. Falhas e causas encontradas no caminho

| Programa | Sintoma | Causa | Correção |
| :--- | :--- | :--- | :--- |
| `hex-id` | TIMEOUT com o timeout de 15 s | As pausas para uma pessoa ler o display somam mais de 15 s | O runner dá 90 s ao programa |
| `irq-masked`, `irq-wfi`, `irq-mepc-precise` | TIMEOUT ou FAIL ao rodar em sequência | Com a regravação da FLASH pelo editor de memória, a placa reiniciava o programa sem resetar o núcleo nem o CLINT, e o programa seguinte herdava `mie`, `mstatus.MIE` e `mtimecmp`; além disso o `mtime` conta a 1 MHz, e não a cada ciclo como o modelo | `RVIRQ_INIT` no início de cada programa e `RV32_PRECISE_ADDS` e laço de espera em `irq-wfi`; a simulação continua com 7 de 7. Com o carregador JTAG da FLASH, cada troca de programa reinicia o núcleo, o CLINT e o PLIC |
| `flash-update`, `flash-update-interrupted` | O `riscv-tools run` não envia a imagem da banca B pela UART, e a placa não zera a SDRAM entre programas (a palavra de sobrevivência ficava em `UPDATING`) | Nenhuma falha no hardware; falta de condução | O `board_update.py` zera a palavra, grava a FLASH inteira (banca B zerada, inválida), envia a imagem e confere o `stdout` |
| `plic-flash` | FAIL(9) na parte C | O console que esvazia a UART sobre JTAG liga segundos depois do programa, e o `WAIT_COUNT` desistia em cerca de 60 ms | `RVPLIC_WAIT_POLLS` no cabeçalho de `include-plic-de0-cv`, com cerca de 16 s |

## 5. Veredito por programa

| Programa | Etapa | Placa | Veredito |
| :--- | :--- | :--- | :--- |
| `add` | regression | notebook | PASS |
| `add-upper-immediate-to-pc` | regression | PC1 | PASS |
| `and` | regression | notebook | PASS |
| `arithmetic-add` | regression | PC1 | PASS |
| `arithmetic-addi-negative` | regression | notebook | PASS |
| `arithmetic-sub` | regression | PC1 | PASS |
| `branch-beq` | regression | notebook | PASS |
| `branch-bge` | regression | PC1 | PASS |
| `branch-bgeu` | regression | notebook | PASS |
| `branch-blt` | regression | PC1 | PASS |
| `branch-bltu` | regression | notebook | PASS |
| `branch-bne` | regression | PC1 | PASS |
| `branch-equal` | regression | notebook | PASS |
| `branch-not-equal` | regression | PC1 | PASS |
| `bss-zero` | regression | notebook | PASS |
| `cache-sweep` | sdram | notebook | PASS |
| `clint-mtip` | sdram | PC1 | PASS |
| `cntr-cycle-monotonic` | regression | PC1 | PASS |
| `cntr-forwarding` | regression | notebook | PASS |
| `cntr-instret-exact` | regression | PC1 | PASS |
| `cntr-muldiv-cost` | regression | notebook | PASS |
| `cntr-readonly-illegal` | regression | PC1 | PASS |
| `cntr-rollover` | regression | notebook | PASS |
| `cntr-time-rate` | regression | PC1 | PASS |
| `cntr-trap-no-retire` | regression | notebook | PASS |
| `cntr-write` | regression | PC1 | PASS |
| `code-sweep` | sdram | notebook | PASS |
| `compare-signed` | regression | notebook | PASS |
| `compare-slt` | regression | PC1 | PASS |
| `compare-slti` | regression | notebook | PASS |
| `compare-sltiu` | regression | PC1 | PASS |
| `compare-sltu` | regression | notebook | PASS |
| `compare-unsigned` | regression | PC1 | PASS |
| `conformance-decode` | regression | notebook | PASS |
| `conformance-fencei` | sdram | PC1 | PASS |
| `cpi-kernels` | sdram | notebook | PASS |
| `csr-back-to-back` | regression | PC1 | PASS |
| `csr-forwarding` | regression | notebook | PASS |
| `csr-rw-basic` | regression | PC1 | PASS |
| `csr-x0-no-effect` | regression | notebook | PASS |
| `data-init-byte` | regression | PC1 | PASS |
| `data-init-halfword` | regression | notebook | PASS |
| `data-init-word` | regression | PC1 | PASS |
| `data-init-word-array` | regression | notebook | PASS |
| `data-initialization` | regression | PC1 | PASS |
| `display` | sdram | PC1 | PASS |
| `div` | regression | notebook | PASS |
| `div-rem-back-to-back` | regression | PC1 | PASS |
| `divide-signed` | regression | notebook | PASS |
| `divide-unsigned` | regression | PC1 | PASS |
| `divu` | regression | notebook | PASS |
| `example-add` | regression | PC1 | PASS |
| `example-integration-mem` | regression | notebook | PASS |
| `fence-tso` | regression | PC1 | PASS |
| `flash-const` | sdram | notebook | PASS |
| `flash-update` | update | notebook e PC1 | PASS |
| `flash-update-interrupted` | update | notebook e PC1 | PASS |
| `hazard-forwarding-chain` | regression | notebook | PASS |
| `hazard-forwarding-mul` | regression | PC1 | PASS |
| `hazard-forwarding-raw` | regression | notebook | PASS |
| `hazard-load-use` | regression | PC1 | PASS |
| `hello` | sdram | PC1 | PASS |
| `hex-id` | sdram | notebook | PASS |
| `hpm-branch-count` | regression | notebook | PASS |
| `hpm-cpi` | regression | PC1 | PASS |
| `hpm-full` | regression | notebook | PASS |
| `hpm-fused-high` | regression | PC1 | PASS |
| `hpm-inhibit-select` | regression | notebook | PASS |
| `hpm-load-use` | regression | PC1 | PASS |
| `hpm-muldiv-stall` | regression | notebook | PASS |
| `hpm-reduced` | hpm-reduced | notebook e PC1 | PASS |
| `hpm-sweep` | regression | PC1 | PASS |
| `irq-ecall` | irq | PC1 | PASS |
| `irq-masked` | irq | PC1 | PASS |
| `irq-mepc-precise` | irq | PC1 | PASS |
| `irq-priority` | irq | PC1 | PASS |
| `irq-timer-basic` | irq | PC1 | PASS |
| `irq-vectored` | irq | PC1 | PASS |
| `irq-wfi` | irq | PC1 | PASS |
| `jump-jal` | regression | notebook | PASS |
| `jump-jalr` | regression | PC1 | PASS |
| `load-byte-signed` | regression | notebook | PASS |
| `load-byte-unsigned` | regression | PC1 | PASS |
| `load-halfword-signed` | regression | notebook | PASS |
| `load-halfword-unsigned` | regression | PC1 | PASS |
| `load-store-byte` | regression | notebook | PASS |
| `load-store-halfword` | regression | PC1 | PASS |
| `load-store-word` | regression | notebook | PASS |
| `load-upper-immediate` | regression | PC1 | PASS |
| `load-word` | regression | notebook | PASS |
| `logical-and` | regression | PC1 | PASS |
| `logical-andi` | regression | notebook | PASS |
| `logical-or` | regression | PC1 | PASS |
| `logical-ori` | regression | notebook | PASS |
| `logical-xor` | regression | PC1 | PASS |
| `logical-xori` | regression | notebook | PASS |
| `loop` | regression | PC1 | PASS |
| `misaligned-cache-lines` | sdram | PC1 | PASS |
| `misaligned-crossing` | regression | notebook | PASS |
| `misaligned-crossing` | sdram | notebook | PASS |
| `monitor` | sdram | PC1 | PASS |
| `mul` | regression | PC1 | PASS |
| `muldiv-fusion` | regression | notebook | PASS |
| `mulh` | regression | PC1 | PASS |
| `mulhsu` | regression | notebook | PASS |
| `mulhu` | regression | PC1 | PASS |
| `multiply` | regression | notebook | PASS |
| `not` | regression | PC1 | PASS |
| `or` | regression | notebook | PASS |
| `plic-flash` | plic | notebook e PC1 | PASS |
| `rem` | regression | PC1 | PASS |
| `remainder-signed` | regression | notebook | PASS |
| `remainder-unsigned` | regression | PC1 | PASS |
| `remu` | regression | notebook | PASS |
| `rodata-lookup-table` | regression | PC1 | PASS |
| `sdram-bytes` | sdram | notebook | PASS |
| `sdram-copy` | sdram | PC1 | PASS |
| `sdram-exec-copy` | sdram | notebook | PASS |
| `sdram-loop` | sdram | PC1 | PASS |
| `sdram-memtest` | sdram | notebook | PASS |
| `sdram-muldiv` | sdram | PC1 | PASS |
| `sdram-refresh` | sdram | notebook | PASS |
| `section6-loadstore` | regression | notebook | PASS |
| `selfmod-repeat` | sdram | PC1 | PASS |
| `shift-left` | regression | PC1 | PASS |
| `shift-left-logical` | regression | notebook | PASS |
| `shift-left-logical-imm` | regression | PC1 | PASS |
| `shift-right-arithmetic` | regression | notebook | PASS |
| `shift-right-arithmetic-imm` | regression | PC1 | PASS |
| `shift-right-arithmetic-reg` | regression | notebook | PASS |
| `shift-right-logical` | regression | PC1 | PASS |
| `shift-right-logical-imm` | regression | notebook | PASS |
| `shift-right-logical-reg` | regression | PC1 | PASS |
| `stdout-printf` | regression | notebook | PASS |
| `stdout-printf-int` | regression | PC1 | PASS |
| `stdout-truncate` | regression | notebook | PASS |
| `store-byte-roundtrip` | regression | PC1 | PASS |
| `store-halfword-roundtrip` | regression | notebook | PASS |
| `store-word-roundtrip` | regression | PC1 | PASS |
| `struct-alignment` | regression | notebook | PASS |
| `struct-init-heap` | regression | PC1 | PASS |
| `struct-init-stack` | regression | notebook | PASS |
| `sub` | regression | PC1 | PASS |
| `trap-ecall-ebreak` | regression | notebook | PASS |
| `trap-illegal` | regression | PC1 | PASS |
| `trap-mem-squash` | regression | notebook | PASS |
| `trap-misaligned-jump` | regression | PC1 | PASS |
| `trap-misaligned-ldst` | regression | notebook | PASS |
| `trap-muldiv-load-use` | regression | PC1 | PASS |
| `update-new` | update | notebook e PC1 | PASS |
| `wb-hold-crossing` | regression | notebook | PASS |
| `x0-readonly` | regression | PC1 | PASS |
| `xor` | regression | notebook | PASS |
| `zicond-bits` | regression | PC1 | PASS |
| `zicond-edge` | regression | notebook | PASS |
| `zihintntl-hints` | regression | PC1 | PASS |
| `zihintpause-loop` | regression | notebook | PASS |
| `zimop-mop-r` | regression | PC1 | PASS |
| `zimop-mop-rr` | regression | notebook | PASS |

## 6. Núcleo a 76,923 MHz

O bitstream da frente de frequência (Insper-RISC-V `a612e9c`, núcleo e busca a 76,923077 MHz com a fase do núcleo em 7500 ps, semente 5, pior folga de setup do núcleo +0,707 ns) rodou na placa da PC1 (`/tmp/de0cv-ws.lock`, `board_run.py run --board ws --stages sdram irq regression`, Tests `c990ab0`).

| Etapa | Programas | PASS | FAIL | TIMEOUT |
| :--- | ---: | ---: | ---: | ---: |
| `regression` | 128 | 128 | 0 | 0 |
| `sdram` | 20 | 20 | 0 | 0 |
| `irq` | 13 | 13 | 0 | 0 |
| Total | 161 | 161 | 0 | 0 |

Uma rodada anterior, com o RTL que ainda trazia o atributo `maxfan` e os testes antigos, deu 159 de 161: `clint-mtip` (código 2) esperava o `mip` logo depois da escrita no `msip`, e as linhas de interrupção agora entram no núcleo por um registrador; `flash-const` esperava que o store na FLASH fosse ignorado, e o núcleo com falhas de acesso o recusa com `mcause` 7. Os dois programas foram ajustados (`c990ab0`) e passam na simulação e na placa. Os ELFs do ACT4 não foram rodados nesta sessão.

## 7. Projeto gerado pelo `board generate`

O bitstream do projeto que o `riscv-tools program` escreve e compila (Insper-RISC-V `a3d9d03`, semente 5, pior folga de setup +0,759 ns) rodou na placa do notebook (`/tmp/de0cv-laptop.lock`, `board_run.py run --host laptop`) com os 161 programas da seção 6.

| Etapa | Programas | PASS | FAIL | TIMEOUT |
| :--- | ---: | ---: | ---: | ---: |
| `regression` | 128 | 128 | 0 | 0 |
| `sdram` | 20 | 20 | 0 | 0 |
| `irq` | 13 | 13 | 0 | 0 |
| Total | 161 | 161 | 0 | 0 |

O `hpm-cpi` falhava nesta placa com o bitstream gerado e com o escrito à mão. A causa era o RTL. A leitura registrada do banco do Zihpm guarda o valor do contador lido, e o `csr_file` fazia o OU desse registrador na leitura de qualquer CSR sem caso próprio, de modo que o `csrr` de `instret` logo depois de um `csrr` de `mhpmcounterK` recebia os bits do contador e a janela de `instret` do teste saía errada. O teste ficou como estava, e o Core passou a ligar a saída do banco só quando o endereço é do banco.

---

Copyright 2026 Insper. Licenciado sob a [Apache License, Version 2.0](../../../LICENSE).
