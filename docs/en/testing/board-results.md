# Program results on the DE0-CV board

🌐 [Português](../../pt-br/testing/board-results.md) · [English](board-results.md)

## 1. Conditions

| Item | Value |
| :--- | :--- |
| Full bitstream | `de0-cv.sof` of Insper-RISC-V `ceea999` (profile `rv32im_zicclsm_zicntr_zihpm_zifencei` with Zimop, Zicond, Zihintntl, Zihintpause, interrupts with the PLIC and the FLASH controller), seed 1, 29 counters of 64 bits |
| Reduced bitstream | The same code with `HPM_COUNTERS=4 HPM_WIDTH=40` (`de0-cv_synth.tcl 1 HPM_COUNTERS=4 HPM_WIDTH=40`), 4 counters of 40 bits |
| The five programs of `board_update.py` | Repeated with the full and reduced bitstreams of Insper-RISC-V `1c2137d` (SDRAM at 100 MHz and core phase at 8250 ps), with the same result on both boards |
| Core clock | 50 MHz (worst Quartus setup slack: -0.745 ns) |
| Boards | laptop (`/tmp/de0cv-laptop.lock`) and PC1 (`/tmp/de0cv-ws.lock`), in parallel, list split by `--part 0/2` and `1/2` |
| Runner | [board-runner.md](board-runner.md) |

## 2. Summary

154 of 154 programs passed with the full bitstream: 127 of `asm/` and `c/` (stage `regression`), 20 of `asm-sdram/` and `c-sdram/` (stage `sdram`) and 7 of `asm-irq/` (stage `irq`). The five programs below, which the `board_run.py` runner does not cover, also passed on both boards: `flash-update`, `flash-update-interrupted` and `update-new` (stage `update`), `hpm-reduced` with the reduced bitstream and `plic-flash` (stage `plic`), driven by `board_update.py` ([board-runner.md](board-runner.md)).

## 3. Programs left out

| Program | Reason |
| :--- | :--- |
| `uart-echo`, `uart-tx`, `uart-errors` | Use the physical UART pins, which the boards do not have wired; the only test allowed to fail on the board |
| `asm-plic/` (`plic-timer`, `plic-switches`, `plic-keys`, `plic-uart`, `plic-uart-jtag`, `plic-priority`) | They use the timer, the GPIOs and the pin UART of the `modular` platform, which the board top does not have; the board only has the `UART_JTAG` and `FLASH` sources, and `plic-uart-jtag` and `plic-priority` depend on a host with cycle-level latency (`fromhost`), which the JTAG of the board does not offer |

## 4. Failures found on the way, and their causes

| Program | Symptom | Cause | Fix |
| :--- | :--- | :--- | :--- |
| `hex-id` | TIMEOUT with the 15 s timeout | The pauses for a person to read the display add up to more than 15 s | The runner gives the program 90 s |
| `irq-masked`, `irq-wfi`, `irq-mepc-precise` | TIMEOUT or FAIL when run in sequence | With the FLASH rewritten through the memory editor, the board restarted the program without resetting the core or the CLINT, so the next program inherited `mie`, `mstatus.MIE` and `mtimecmp`; also `mtime` counts at 1 MHz, not every cycle like the model | `RVIRQ_INIT` at the start of each program, `RV32_PRECISE_ADDS` and a wait loop in `irq-wfi`; the simulation still passes 7 of 7. With the JTAG loader of the FLASH, every program change restarts the core, the CLINT and the PLIC |
| `flash-update`, `flash-update-interrupted` | `riscv-tools run` does not send the image of bank B over the UART, and the board does not clear the SDRAM between programs (the survivor word stayed at `UPDATING`) | No hardware fault; missing driver | `board_update.py` clears the word, writes the whole FLASH (bank B zeroed, invalid), sends the image and checks `stdout` |
| `plic-flash` | FAIL(9) in part C | The console that drains the UART over JTAG attaches seconds after the program, and `WAIT_COUNT` gave up in about 60 ms | `RVPLIC_WAIT_POLLS` in the header of `include-plic-de0-cv`, about 16 s |

## 5. Verdict per program

| Program | Stage | Board | Verdict |
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
| `flash-update` | update | laptop and PC1 | PASS |
| `flash-update-interrupted` | update | laptop and PC1 | PASS |
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
| `hpm-reduced` | hpm-reduced | laptop and PC1 | PASS |
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
| `plic-flash` | plic | laptop and PC1 | PASS |
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
| `update-new` | update | laptop and PC1 | PASS |
| `wb-hold-crossing` | regression | notebook | PASS |
| `x0-readonly` | regression | PC1 | PASS |
| `xor` | regression | notebook | PASS |
| `zicond-bits` | regression | PC1 | PASS |
| `zicond-edge` | regression | notebook | PASS |
| `zihintntl-hints` | regression | PC1 | PASS |
| `zihintpause-loop` | regression | notebook | PASS |
| `zimop-mop-r` | regression | PC1 | PASS |
| `zimop-mop-rr` | regression | notebook | PASS |

## 6. Core at 76.923 MHz

The bitstream of the frequency front (Insper-RISC-V `a612e9c`, core and fetch at 76.923077 MHz with the core phase at 7500 ps, seed 5, worst core setup slack +0.707 ns) ran on the PC1 board (`/tmp/de0cv-ws.lock`, `board_run.py run --board ws --stages sdram irq regression`, Tests `c990ab0`).

| Stage | Programs | PASS | FAIL | TIMEOUT |
| :--- | ---: | ---: | ---: | ---: |
| `regression` | 128 | 128 | 0 | 0 |
| `sdram` | 20 | 20 | 0 | 0 |
| `irq` | 13 | 13 | 0 | 0 |
| Total | 161 | 161 | 0 | 0 |

An earlier run, with the RTL that still had the `maxfan` attribute and the old tests, gave 159 of 161: `clint-mtip` (code 2) expected `mip` right after the write to `msip`, and the interrupt lines now enter the core through a register; `flash-const` expected the store to the FLASH to be ignored, and the core with access faults refuses it with `mcause` 7. Both programs were adjusted (`c990ab0`) and pass in simulation and on the board. The ACT4 ELFs were not run in this session.

## 7. Project generated by `board generate`

The bitstream of the project that `riscv-tools program` writes and compiles (Insper-RISC-V `a3d9d03`, seed 5, worst setup slack +0.759 ns) ran on the laptop board (`/tmp/de0cv-laptop.lock`, `board_run.py run --host laptop`) with the 161 programs of section 6.

| Stage | Programs | PASS | FAIL | TIMEOUT |
| :--- | ---: | ---: | ---: | ---: |
| `regression` | 128 | 128 | 0 | 0 |
| `sdram` | 20 | 20 | 0 | 0 |
| `irq` | 13 | 13 | 0 | 0 |
| Total | 161 | 161 | 0 | 0 |

`hpm-cpi` failed on this board with the generated bitstream and with the hand-written one. The cause was the RTL. The registered read of the Zihpm bank keeps the value of the counter it read, and `csr_file` ORed that register into the read of any CSR without its own case, so the `csrr` of `instret` right after a `csrr` of `mhpmcounterK` received the bits of the counter and the `instret` window of the test came out wrong. The test stayed as it was, and the Core now connects the bank output only when the address belongs to the bank.

---

Copyright 2026 Insper. Licensed under the [Apache License, Version 2.0](../../../LICENSE).
