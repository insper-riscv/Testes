#!/usr/bin/env python3
"""Runs the 'sim' test suite: for every test in the manifest built by
build_tests.py --emit hex, invokes the cocotb/GHDL testbench
(sim/test_c_program.py via sim/Makefile) against that test's ROM image
and checks the exit status (PASS/FAIL comes from the mailbox, asserted
inside the testbench)."""
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "config.yaml"
SIM_DIR = HERE / "sim"


def main() -> None:
    cfg = yaml.safe_load(CONFIG_PATH.read_text())
    build_dir = ROOT / cfg["paths"]["build_dir"] / "sim"
    manifest_path = build_dir / "manifest.json"

    if not manifest_path.is_file():
        print(f"{manifest_path} not found — run build_tests.py --emit hex first", file=sys.stderr)
        sys.exit(1)

    manifest = json.loads(manifest_path.read_text())
    results = {}
    for entry in manifest:
        name = entry["name"]
        print(f"\n=== {name} ({entry['march']}) ===")
        env = dict(os.environ, ROM_HEX=str((ROOT / entry["hex"]).resolve()), TEST_NAME=name)
        proc = subprocess.run(["make", "-C", str(SIM_DIR), "test"], env=env)
        results[name] = proc.returncode == 0

    print("\n=== Summary ===")
    for name, ok in results.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")

    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    main()
