"""Testes do check que compara cada ``rv32_platform.h`` com o ``platform.yaml`` da plataforma."""

import json
import unittest
from pathlib import Path

from tools.headers import check_platform_headers as check

HEADER = """#define RV32_RAM_BASE    0x40000000   /* RAM */
#define RV32_RAM_END     0x42000000
#define RV32_TOHOST      0x41FFFFE8
#define RV32_BANK_A_SIZE 0x00003000
#define RV32_IMAGE_MAGIC 0x52564946
"""

SYMBOLS = {
    "RAM.base": 0x40000000,
    "RAM.end": 0x42000000,
    "tohost.base": 0x41FFFFE8,
    "BANK_A.size": 0x3000,
}


class CheckHeaderTests(unittest.TestCase):
    """A comparação de um cabeçalho com os símbolos de uma plataforma."""

    def test_a_header_that_matches_has_no_divergence(self) -> None:
        self.assertEqual(check.check_header("include-x", HEADER, SYMBOLS), [])

    def test_a_different_value_is_reported_with_both_numbers(self) -> None:
        text = HEADER.replace("0x42000000", "0x44000000")
        found = check.check_header("include-x", text, SYMBOLS)[0]
        self.assertEqual((found.macro, found.found, found.expected), ("RV32_RAM_END", 0x44000000, 0x42000000))
        self.assertIn("0x42000000", str(found))

    def test_an_address_the_platform_lacks_is_reported(self) -> None:
        symbols = {k: v for k, v in SYMBOLS.items() if k != "BANK_A.size"}
        found = check.check_header("include-x", HEADER, symbols)[0]
        self.assertIsNone(found.expected)
        self.assertIn("não tem BANK_A.size", str(found))

    def test_an_ignored_macro_is_not_compared(self) -> None:
        symbols = {k: v for k, v in SYMBOLS.items() if k != "BANK_A.size"}
        self.assertEqual(check.check_header("include-x", HEADER, symbols, ["RV32_BANK_A_SIZE"]), [])

    def test_macros_without_a_platform_symbol_are_left_alone(self) -> None:
        self.assertEqual([m for m, _ in check.header_values(HEADER)][-1], "RV32_IMAGE_MAGIC")
        self.assertEqual(check.check_header("include-x", HEADER, SYMBOLS), [])

    def test_fix_rewrites_only_the_divergent_values_and_keeps_the_width(self) -> None:
        text = HEADER.replace("0x42000000", "0x44000000").replace("0x00003000", "0x00004000")
        fixed = check.fix_header(text, SYMBOLS)
        self.assertEqual(fixed, HEADER)
        self.assertEqual(check.check_header("include-x", fixed, SYMBOLS), [])


class RepositoryHeadersTests(unittest.TestCase):
    """Os cabeçalhos versionados deste repositório."""

    def test_every_header_folder_is_listed_in_the_mapping(self) -> None:
        mapping = json.loads(check.MAPPING.read_text(encoding="utf-8"))
        on_disk = {p.parent.name for p in check.INCLUDE_ROOT.glob("include*/rv32_platform.h")}
        self.assertEqual(on_disk, set(mapping))

    @unittest.skipUnless(
        (Path(check.PLATFORMS_ROOT) / "src").is_dir(), "o submódulo Insper-RISC-V não está inicializado"
    )
    def test_every_header_matches_the_platform_it_belongs_to(self) -> None:
        problems = check.check_all()
        self.assertEqual([], [str(p) for p in problems])


if __name__ == "__main__":
    unittest.main()
