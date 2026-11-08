"""Confere cada ``rv32_platform.h`` dos programas de teste com o ``platform.yaml`` da sua plataforma.

Os cabeçalhos ``tools/riscv_build/include-<placa>/rv32_platform.h`` repetem à mão o mapa de memória que o
``platform.yaml`` do submódulo Insper-RISC-V define. Este roteiro lê o mapa com o mesmo leitor do
``riscv-tools check-memory-map`` (``riscv_tools.memory_map``) e compara, macro a macro, o valor do cabeçalho
com o valor derivado da plataforma. Um cabeçalho que diverge, ou que define um endereço que a plataforma não
tem, reprova a conferência; ``--write`` corrige os valores divergentes no próprio cabeçalho.

``headers.json`` guarda, para cada pasta de cabeçalho, o ``platform.yaml`` (relativo ao submódulo) e as
macros que não se aplicam à plataforma (``ignore``).
"""

import argparse
import json
import re
import sys
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path

from riscv_tools.memory_map import banks, core

TESTS_ROOT = Path(__file__).resolve().parents[2]
INCLUDE_ROOT = TESTS_ROOT / "tools/riscv_build"
PLATFORMS_ROOT = TESTS_ROOT / "Insper-RISC-V"
MAPPING = Path(__file__).with_name("headers.json")

# Macro do cabeçalho e o símbolo do mapa da plataforma de onde o valor vem.
MACRO_SYMBOLS = {
    "RV32_RAM_BASE": "RAM.base",
    "RV32_RAM_END": "RAM.end",
    "RV32_STDOUT_BASE": "stdout.base",
    "RV32_TOHOST": "tohost.base",
    "RV32_FROMHOST": "fromhost.base",
    "RV32_UART_BASE": "UART.base",
    "RV32_FLASH_CTRL_BASE": "FLASH_CTRL.base",
    "RV32_CLINT_BASE": "CLINT.base",
    "RV32_PLIC_BASE": "PLIC.base",
    "RV32_BANK_A_BASE": "BANK_A.base",
    "RV32_BANK_A_SIZE": "BANK_A.size",
    "RV32_BANK_B_BASE": "BANK_B.base",
    "RV32_BANK_B_SIZE": "BANK_B.size",
}

_DEFINE = re.compile(
    r"^(?P<head>#define\s+(?P<name>RV32_[A-Z0-9_]+)\s+)(?P<value>0[xX][0-9A-Fa-f]+|\d+)\b",
    re.MULTILINE,
)


@dataclass(frozen=True)
class Divergence:
    """Uma macro do cabeçalho que não bate com a plataforma.

    Attributes
    ----------
    header : str
        Pasta do cabeçalho (``include-<placa>``).
    macro : str
        Nome da macro.
    found : int
        Valor escrito no cabeçalho.
    expected : int or None
        Valor da plataforma, ``None`` quando a plataforma não tem o símbolo.
    symbol : str
        Símbolo do mapa de onde o valor deveria vir.
    """

    header: str
    macro: str
    found: int
    expected: int | None
    symbol: str

    def __str__(self) -> str:
        """Descreve a divergência em uma linha."""
        if self.expected is None:
            return f"{self.header}: {self.macro} = {self.found:#x}, mas a plataforma não tem {self.symbol}"
        return f"{self.header}: {self.macro} = {self.found:#x}, a plataforma ({self.symbol}) tem {self.expected:#x}"


def platform_symbols(platform_file: Path) -> dict[str, int]:
    """Lê os símbolos do mapa de memória de uma plataforma.

    Parameters
    ----------
    platform_file : Path
        O ``platform.yaml``.

    Returns
    -------
    dict of {str: int}
        Os símbolos de ``REGIÃO.base|end``, das áreas reservadas, dos periféricos e das bancas da FLASH.
    """
    platform = core.load_platform(platform_file)
    table = core.symbols(platform)
    if platform.get("flash"):
        table |= banks.symbols(platform)
    return table


def header_values(text: str) -> list[tuple[str, int]]:
    """Lista as macros numéricas ``RV32_*`` de um cabeçalho, na ordem em que aparecem.

    Parameters
    ----------
    text : str
        O conteúdo do cabeçalho.

    Returns
    -------
    list of tuple of (str, int)
        Nome da macro e valor.
    """
    return [(m["name"], int(m["value"], 0)) for m in _DEFINE.finditer(text)]


def check_header(
    folder: str,
    text: str,
    symbols: dict[str, int],
    ignore: Iterable[str] = (),
) -> list[Divergence]:
    """Compara as macros mapeadas de um cabeçalho com os símbolos da plataforma.

    Parameters
    ----------
    folder : str
        Pasta do cabeçalho, para a mensagem.
    text : str
        O conteúdo do cabeçalho.
    symbols : dict of {str: int}
        Os símbolos da plataforma.
    ignore : iterable of str
        Macros que não se aplicam à plataforma.

    Returns
    -------
    list of Divergence
        Uma entrada por macro que diverge; vazia quando o cabeçalho bate.
    """
    skipped = set(ignore)
    found: list[Divergence] = []
    for name, value in header_values(text):
        symbol = MACRO_SYMBOLS.get(name)
        if symbol is None or name in skipped:
            continue
        expected = symbols.get(symbol)
        if expected != value:
            found.append(Divergence(folder, name, value, expected, symbol))
    return found


def fix_header(text: str, symbols: dict[str, int], ignore: Iterable[str] = ()) -> str:
    """Reescreve no cabeçalho os valores que a plataforma define de outro modo.

    Parameters
    ----------
    text : str
        O conteúdo do cabeçalho.
    symbols : dict of {str: int}
        Os símbolos da plataforma.
    ignore : iterable of str
        Macros que não se aplicam à plataforma.

    Returns
    -------
    str
        O cabeçalho com os valores corrigidos (as macros sem símbolo na plataforma ficam como estão).
    """
    skipped = set(ignore)

    def replace(match: re.Match[str]) -> str:
        symbol = MACRO_SYMBOLS.get(match["name"])
        expected = symbols.get(symbol) if symbol else None
        if expected is None or match["name"] in skipped:
            return match[0]
        width = len(match["value"]) - 2 if match["value"].lower().startswith("0x") else 0
        if width:
            return f"{match['head']}0x{expected:0{width}X}"
        return f"{match['head']}{expected}"

    return _DEFINE.sub(replace, text)


def check_all(write: bool = False) -> list[Divergence]:
    """Confere todos os cabeçalhos listados em ``headers.json``.

    Parameters
    ----------
    write : bool
        Corrige no disco os valores divergentes antes de devolver o que restou.

    Returns
    -------
    list of Divergence
        As divergências que sobraram.
    """
    mapping = json.loads(MAPPING.read_text(encoding="utf-8"))
    on_disk = {p.parent.name for p in INCLUDE_ROOT.glob("include*/rv32_platform.h")}
    problems = [
        Divergence(name, "(sem entrada em headers.json)", 0, None, "-") for name in sorted(on_disk - mapping.keys())
    ]
    for folder, entry in mapping.items():
        header = INCLUDE_ROOT / folder / "rv32_platform.h"
        symbols = platform_symbols(PLATFORMS_ROOT / entry["platform"])
        ignore = entry.get("ignore", [])
        text = header.read_text(encoding="utf-8")
        if write:
            fixed = fix_header(text, symbols, ignore)
            if fixed != text:
                header.write_text(fixed, encoding="utf-8")
                text = fixed
        problems += check_header(folder, text, symbols, ignore)
    return problems


def main() -> int:
    """Roda a conferência e devolve o código de saída (0 quando todos os cabeçalhos batem)."""
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n", maxsplit=1)[0])
    parser.add_argument("--write", action="store_true", help="corrige os valores divergentes nos cabeçalhos")
    args = parser.parse_args()
    problems = check_all(write=args.write)
    for problem in problems:
        print(f"HEADER {problem}")
    names = len(json.loads(MAPPING.read_text(encoding="utf-8")))
    print(f"{names} cabeçalhos conferidos, {len(problems)} divergências")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
