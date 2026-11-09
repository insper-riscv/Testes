# O Python do riscv-tools da imagem (traz o leitor do platform.yaml).
RISCV_TOOLS_PYTHON ?= /opt/riscv-tools/riscv-tools/bin/python

# Alvos do repositório de testes. A regressão usa o riscv-tools da imagem do Infra
# (ghcr.io/insper-riscv/ci-elf), que traz GHDL, o GCC RISC-V e o Spike.
.PHONY: regression regression-no-spike flash-update-images flash-update-check check-headers

# Todos os programas em cada plataforma, a verificação cruzada com o Spike e o relatório único
# em build/regression/report.md.
regression:
	python3 -I tools/regression/regression.py

regression-no-spike:
	python3 -I tools/regression/regression.py --skip-spike

# O programa da banca B que os testes de atualização enviam (c-sdram-bank-b/update-new), construído como a imagem da
# banca B e escrito no uart_input.txt dos testes; flash-update-check só confere se os arquivos estão em dia.
flash-update-images:
	tools/flash_update/make_images.sh

flash-update-check:
	tools/flash_update/make_images.sh --check

# Cada include-<placa>/rv32_platform.h tem de bater com o platform.yaml da plataforma (make check-headers ARGS=--write corrige).
check-headers:
	$(RISCV_TOOLS_PYTHON) -I tools/headers/check_platform_headers.py $(ARGS)
