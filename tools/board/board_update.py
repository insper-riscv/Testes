"""Roda na placa DE0-CV os programas de atualização de programa da FLASH e o de PLIC da FLASH, com um veredito por programa.

Os programas ``flash-update`` e ``flash-update-interrupted`` (``c-sdram-update/``) recebem pela UART sobre
JTAG a imagem da banca B, atualizam a FLASH pelo controlador e reiniciam pela memória de boot. O
``update-new`` (``c-sdram-bank-b/``) é o programa dessa imagem e roda sozinho, gravado na banca B. O
``riscv-tools run`` não envia bytes pela UART, então este roteiro faz a sequência de cada programa:

1. zera a palavra de sobrevivência da SDRAM (a placa não zera a SDRAM entre programas) e o ``tohost``;
2. grava a FLASH inteira pelo carregador JTAG (a banca B sai zerada, portanto inválida) e solta o núcleo;
3. espera o programa chegar à leitura da UART e envia a imagem da banca B (``riscv-tools flash-image send``);
4. espera o ``tohost`` e confere o texto que o programa imprimiu.

O roteiro roda onde estão o Quartus e o cabo, sob o lock da placa, e escreve ``results-update-<placa>.json``.
"""

import argparse
import contextlib
import json
import sys
import time
from pathlib import Path
from typing import Any

from board_run import board_lock
from riscv_tools import (
    flash_image,
    flash_loader,
    htif,
    ram_target,
    rom_writer,
    uart_console,
)
from riscv_tools.cli.common import jtag_link
from riscv_tools.jtag import JtagLink
from riscv_tools.settings import load_config

TESTS_ROOT = Path(__file__).resolve().parents[2]
BUILD = TESTS_ROOT / "tools/riscv_build"

# Endereço, relativo ao início da SDRAM, da palavra que os programas de atualização usam para saber que já
# tentaram atualizar (SURVIVOR em src.c).
SURVIVOR_OFFSET = 0x03000000
FLASH_WORDS = 65536

# Cada programa: config, diretório do fonte, origem do que se envia pela UART e fim esperado.
CASES = {
    "flash-update": {
        "config": "config.sdram-flash-update.yaml",
        "build": "build-sdram-flash-update",
        "source": "c-sdram-update/flash-update",
        "send": True,
    },
    "flash-update-interrupted": {
        "config": "config.sdram-flash-update.yaml",
        "build": "build-sdram-flash-update",
        "source": "c-sdram-update/flash-update-interrupted",
        "send": True,
    },
    "update-new": {
        "config": "config.sdram-flash-bank-b.yaml",
        "build": "build-bank-b",
        "source": "c-sdram-bank-b/update-new",
        "send": False,
        # o mif deste programa tem mais palavras do que a FLASH tem: só as da FLASH valem
        "truncate": True,
        "expected_from": "c-sdram-update/flash-update",
    },
    # Os eventos do controlador de FLASH e da UART sobre JTAG pelo PLIC; o console fica ligado para a UART esvaziar.
    "plic-flash": {
        "config": "config.plic-de0-cv.yaml",
        "build": "build-plic-de0-cv",
        "source": "asm-plic-de0-cv/plic-flash",
        "send": False,
        "expected": "",
    },
}


def stdout_buffer(
    link: JtagLink, cfg: dict[str, Any], target: ram_target.RamTarget
) -> str:
    """Lê o que o programa imprimiu no buffer de ``stdout`` da SDRAM (a cópia que o teste confere).

    Parameters
    ----------
    link : JtagLink
        Qual cabo e chip.
    cfg : dict
        O config carregado.
    target : RamTarget
        Como a RAM é alcançada.

    Returns
    -------
    str
        O texto impresso, vazio se o buffer está vazio.
    """
    memory = cfg["memory"]
    first = htif.word_offset(
        memory["ram_base"], memory["tohost_addr"] - 0x408
    )  # stdout: 1 KiB + 8 bytes below tohost
    length = ram_target.read_words(link, target, first, 1)[0]
    if length == 0 or length > 1024:
        return ""
    words = ram_target.read_words(link, target, first + 2, (length + 3) // 4)
    data = b"".join(w.to_bytes(4, "little") for w in words)
    return data[:length].decode(errors="replace")


def run_case(name: str, wait_s: float, finish_s: float) -> tuple[str, str]:
    """Roda um programa na placa e devolve o veredito e uma observação.

    Parameters
    ----------
    name : str
        Nome do programa, uma chave de ``CASES``.
    wait_s : float
        Quanto esperar entre soltar o núcleo e enviar a imagem.
    finish_s : float
        Quanto esperar o ``tohost`` depois do envio.

    Returns
    -------
    tuple of (str, str)
        PASS, FAIL ou TIMEOUT e o texto impresso pelo programa.
    """
    case = CASES[name]
    cfg = load_config(str(BUILD / str(case["config"])))
    link = jtag_link(cfg)
    memory = cfg["memory"]
    target = ram_target.target_from_config(cfg, link)
    source = TESTS_ROOT / str(case["source"])
    mif = TESTS_ROOT / str(case["build"]) / "real" / f"{name}.mif"
    expected_dir = TESTS_ROOT / str(case.get("expected_from", case["source"]))
    expected = case.get("expected")
    if expected is None:
        expected = (expected_dir / "uart_expected.txt").read_text(errors="replace")

    survivor = htif.word_offset(
        memory["ram_base"], memory["ram_base"] + SURVIVOR_OFFSET
    )
    ram_target.write_word(link, target, survivor, 0)
    htif.clear_tohost_configured(link, cfg)

    printed = bytearray()
    if case.get("truncate"):
        words = rom_writer.mif_words(mif)[:FLASH_WORDS]
        flash_loader.load_image(link, words)
    else:
        rom_writer.write_rom_configured(link, cfg, mif)

    if case["send"]:
        time.sleep(wait_s)
        image = (source / "uart_input.txt").read_bytes()
        flash_image.send_image(link, image, printed.extend)
    deadline = time.monotonic() + finish_s
    verdict = "TIMEOUT"
    while time.monotonic() < deadline:
        uart_console.read_console(link, printed.extend, seconds=3)
        value = htif.read_tohost_configured(link, cfg)
        if htif.is_done(value):
            verdict = "PASS" if value == 1 else f"FAIL({htif.fail_code(value)})"
            break
    text = stdout_buffer(link, cfg, target) or printed.decode(errors="replace")
    if verdict == "PASS" and expected.strip() not in text:
        verdict = "FAIL(output)"
    return verdict, text


def main() -> None:
    """Lê a linha de comando, toma o lock da placa e roda os programas."""
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    parser.add_argument("--board", choices=["laptop", "ws"], required=True)
    parser.add_argument("--cases", nargs="+", default=list(CASES))
    parser.add_argument("--wait", type=float, default=4.0)
    parser.add_argument("--finish", type=float, default=60.0)
    parser.add_argument("--out", default="build/board")
    parser.add_argument(
        "--skip-lock", action="store_true", help="o chamador já segura o lock"
    )
    args = parser.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    results = {}
    lock = contextlib.nullcontext() if args.skip_lock else board_lock(args.board)
    with lock:
        for name in args.cases:
            verdict, text = run_case(name, args.wait, args.finish)
            print(f"{verdict} {name}: {text!r}", flush=True)
            results[name] = verdict
    (out / f"results-update-{args.board}.json").write_text(
        json.dumps(results, indent=1, sort_keys=True)
    )
    sys.exit(0 if all(v == "PASS" for v in results.values()) else 1)


if __name__ == "__main__":
    main()
