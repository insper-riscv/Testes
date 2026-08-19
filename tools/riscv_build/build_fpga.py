#!/usr/bin/env python3
"""Runs the 'real' test suite: for every test in the manifest built by
build_tests.py --emit mif, recompiles the whole Quartus project with
that test's ROM content baked in, programs the board, and reads the
result back over JTAG — the PASS/FAIL mailbox for every test, plus a
full RAM-vs-golden-JSON compare for RV32_TEST_KIND: integration tests.

Recompiling per test (instead of loading ROM into an already-flashed
bitstream) is slower but self-contained; see README.md for the
trade-off and how to switch later if it becomes a bottleneck.
"""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "config.yaml"


def run(cmd: list, **kw) -> subprocess.CompletedProcess:
    print("+", " ".join(str(c) for c in cmd))
    return subprocess.run(cmd, check=True, **kw)


def mailbox_word_offset(cfg: dict) -> int:
    return (cfg["memory"]["mailbox_addr"] - cfg["memory"]["ram_base"]) // 4


def read_mailbox(cfg: dict) -> int:
    out = subprocess.run(
        [
            "quartus_stp", "-t", str(HERE / "jtag" / "read_mailbox.tcl"),
            cfg["quartus"]["jtag_hardware"], cfg["quartus"]["jtag_device"],
            str(cfg["quartus"]["mailbox_mem_instance"]), str(mailbox_word_offset(cfg)),
        ],
        check=True, capture_output=True, text=True,
    )
    for line in out.stdout.splitlines():
        if line.startswith("MAILBOX="):
            return int(line.split("=", 1)[1].strip())
    raise RuntimeError(f"read_mailbox.tcl produced no MAILBOX= line:\n{out.stdout}")


def dump_ram(cfg: dict, out_mif: Path) -> None:
    run([
        "quartus_stp", "-t", str(HERE / "jtag" / "dump_ram.tcl"),
        cfg["quartus"]["jtag_hardware"], cfg["quartus"]["jtag_device"],
        str(cfg["quartus"]["ram_mem_instance"]), str(out_mif),
    ])


def run_one(cfg: dict, entry: dict, build_dir: Path) -> bool:
    name = entry["name"]
    print(f"\n=== {name} ({entry['march']}, {entry['kind']}) ===")

    project_dir = ROOT / cfg["quartus"]["project_dir"]
    rom_target = project_dir / cfg["quartus"]["rom_mif_target"]
    rom_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(ROOT / entry["mif"], rom_target)

    run(["quartus_sh", "--flow", "compile", cfg["quartus"]["project_name"]], cwd=project_dir)
    run(["quartus_pgm", "-m", "JTAG", "-o", f"p;{project_dir / cfg['quartus']['sof_file']}"])

    wait_s = cfg["quartus"]["program_wait_seconds"]
    print(f"Waiting {wait_s}s for the program to run ...")
    time.sleep(wait_s)

    mailbox = read_mailbox(cfg)
    if mailbox == 1:
        print(f"{name}: PASS (mailbox=1)")
        passed = True
    elif mailbox == 2:
        print(f"{name}: FAIL (mailbox=2)")
        passed = False
    else:
        print(f"{name}: TIMEOUT/UNKNOWN (mailbox={mailbox}); program may not have finished")
        passed = False

    if entry["kind"] == "integration":
        dump_path = build_dir / f"{name}_ram.mif"
        dump_ram(cfg, dump_path)
        sys.path.insert(0, str(HERE))
        from compare_ram_dump import compare
        passed = compare(dump_path, ROOT / entry["golden"]) and passed

    return passed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", default=None, help="Path to manifest.json (default: build/real/manifest.json)")
    args = parser.parse_args()

    cfg = yaml.safe_load(CONFIG_PATH.read_text())
    build_dir = ROOT / cfg["paths"]["build_dir"] / "real"
    manifest_path = Path(args.manifest) if args.manifest else build_dir / "manifest.json"

    if not manifest_path.is_file():
        print(f"{manifest_path} not found — run build_tests.py --emit mif first", file=sys.stderr)
        sys.exit(1)

    manifest = json.loads(manifest_path.read_text())
    results = {entry["name"]: run_one(cfg, entry, build_dir) for entry in manifest}

    print("\n=== Summary ===")
    for name, ok in results.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")

    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    main()
