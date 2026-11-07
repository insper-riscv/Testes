import json
import os
import re
import stat
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.board import board_run

FAKE_TOOLS = """#!/usr/bin/env python3
import json, sys
args = sys.argv[1:]
if "lock" in args:
    print(json.dumps({"id": "de0-cv-ws", "cable": "USB-Blaster [1-2]",
                      "device": "@1: x (0x02B050DD)", "lock_file": "/tmp/x.lock"}), flush=True)
    sys.stdin.read()
    open(sys.argv[0] + ".released", "w").write("released")
elif "--all" in args:
    print(json.dumps([{"id": "de0-cv-ws"}, {"id": "de0-cv-ws-2"}]))
"""


class BoardRunUnitTests(unittest.TestCase):
    def test_the_runner_names_neither_a_lock_nor_an_idcode(self) -> None:
        source = Path(board_run.__file__).read_text(encoding="utf-8")
        self.assertNotIn("LOCKS", source)
        self.assertNotIn("de0cv_cable", source)
        self.assertNotIn("/tmp/de0cv", source)
        self.assertIsNone(re.search(r'"[0-9A-F]{8}"', source))

    def test_partition_takes_every_nth_item(self) -> None:
        self.assertEqual(board_run.partition(list("abcde"), "1/2"), ["b", "d"])

    def test_part_auto_is_the_position_among_the_present_boards(self) -> None:
        boards = [{"id": "de0-cv-ws"}, {"id": "de0-cv-ws-2"}]
        with mock.patch.object(board_run, "present_boards", return_value=boards):
            self.assertEqual(
                board_run.part_of("auto", "ws", {"id": "de0-cv-ws-2"}), "1/2"
            )
            self.assertEqual(board_run.part_of("0/2", "ws", {"id": "x"}), "0/2")

    def test_the_board_comes_from_the_package_when_it_exists(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            package = Path(root) / "Insper-RISC-V/boards/de0-cv"
            package.mkdir(parents=True)
            (package / "board.yaml").write_text("board: de0-cv\n")
            with mock.patch.object(board_run, "TESTS_ROOT", Path(root)):
                self.assertEqual(board_run.board_args(), ["--board", "de0-cv"])

    def test_without_the_package_the_runner_says_what_to_update(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            with mock.patch.object(board_run, "TESTS_ROOT", Path(root)):
                with self.assertRaisesRegex(RuntimeError, "Insper-RISC-V"):
                    board_run.board_args()

    def test_the_session_holds_the_lock_until_it_ends(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            fake = Path(root) / "fake-tools"
            fake.write_text(FAKE_TOOLS)
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            with (
                mock.patch.dict(os.environ, {"RISCV_TOOLS": str(fake)}),
                mock.patch.object(board_run, "board_args", return_value=["--board", "de0-cv"]),
            ):
                with board_run.board_session("ws") as board:
                    self.assertEqual(board["cable"], "USB-Blaster [1-2]")
                    self.assertFalse(Path(f"{fake}.released").exists())
                self.assertTrue(Path(f"{fake}.released").exists())

    def test_a_failed_lock_raises(self) -> None:
        with (
            mock.patch.dict(os.environ, {"RISCV_TOOLS": "true"}),
            mock.patch.object(board_run, "board_args", return_value=["--board", "de0-cv"]),
            self.assertRaises(RuntimeError),
        ):
            with board_run.board_session("ws"):
                pass


if __name__ == "__main__":
    unittest.main()
