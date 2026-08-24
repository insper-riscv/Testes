#!/usr/bin/env python3
"""Runs the 'real' test suite: for every test in the manifest built by
build_tests.py --emit mif, loads that test's ROM content into an
already-programmed board over JTAG and pulses the restart "go" flag,
instead of recompiling+reprogramming the whole Quartus project per
test (see crt0.S:rv32_wait_restart and rv32_test.h).

The project is compiled and the board programmed exactly once, up
front. From then on each test is just: JTAG-write its ROM .mif
(write_mem.tcl), JTAG-pulse go_flag_addr (pulse_go_flag.tcl), then
poll the PASS/FAIL mailbox until it's set or that test's timeout_s
elapses (RV32_TIMEOUT_S header, see build_tests.py). A timeout falls
back to a full recompile+reprogram+retry of just that test, in case
the board wedged (e.g. a lost JTAG chain) rather than the test
program itself hanging.
"""
import argparse
import json
import re
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


def detect_jtag_hardware() -> str:
    # The "USB-Blaster [<bus>-<port>]" suffix reflects USB topology, not
    # the physical cable — it can (and does) change across reboots/hub
    # renumbering, so config.yaml's jtag_hardware is unreliable. Ask
    # jtagconfig for the live value instead of trusting a static string.
    #
    # Matched specifically on "USB-Blaster" rather than just taking the
    # first hardware line: a second cable (a DE5's onboard blaster) can
    # show up in the same jtagconfig listing when another board is
    # plugged into the same workstation, and it isn't ours.
    out = subprocess.run(["jtagconfig"], check=True, capture_output=True, text=True).stdout
    for line in out.splitlines():
        m = re.match(r"^\s*\d+\)\s+(USB-Blaster.*)$", line)
        if m:
            return m.group(1).strip()
    raise RuntimeError(f"jtagconfig produced no USB-Blaster hardware line:\n{out}")


def word_offset(cfg: dict, addr: int) -> int:
    return (addr - cfg["memory"]["ram_base"]) // 4


def mailbox_word_offset(cfg: dict) -> int:
    return word_offset(cfg, cfg["memory"]["mailbox_addr"])


def go_flag_word_offset(cfg: dict) -> int:
    return word_offset(cfg, cfg["memory"]["go_flag_addr"])


def read_mailbox(cfg: dict, jtag_hardware: str) -> int:
    out = subprocess.run(
        [
            "quartus_stp", "-t", str(HERE / "jtag" / "read_mailbox.tcl"),
            jtag_hardware, cfg["quartus"]["jtag_device"],
            str(cfg["quartus"]["mailbox_mem_instance"]), str(mailbox_word_offset(cfg)),
        ],
        check=True, capture_output=True, text=True,
    )
    for line in out.stdout.splitlines():
        if line.startswith("MAILBOX="):
            return int(line.split("=", 1)[1].strip())
    raise RuntimeError(f"read_mailbox.tcl produced no MAILBOX= line:\n{out.stdout}")


def write_rom_via_jtag(cfg: dict, jtag_hardware: str, mif_path: Path) -> None:
    run([
        "quartus_stp", "-t", str(HERE / "jtag" / "write_mem.tcl"),
        jtag_hardware, cfg["quartus"]["jtag_device"],
        str(cfg["quartus"]["rom_mem_instance"]), str(mif_path),
    ])


def pulse_go_flag(cfg: dict, jtag_hardware: str) -> None:
    run([
        "quartus_stp", "-t", str(HERE / "jtag" / "pulse_go_flag.tcl"),
        jtag_hardware, cfg["quartus"]["jtag_device"],
        str(cfg["quartus"]["ram_mem_instance"]), str(go_flag_word_offset(cfg)), "1",
    ])


def dump_ram(cfg: dict, jtag_hardware: str, out_mif: Path) -> None:
    run([
        "quartus_stp", "-t", str(HERE / "jtag" / "dump_ram.tcl"),
        jtag_hardware, cfg["quartus"]["jtag_device"],
        str(cfg["quartus"]["ram_mem_instance"]), str(out_mif),
    ])


def full_reconfigure(cfg: dict, jtag_hardware: str, mif_path: Path, project_dir: Path) -> None:
    """Compiles the whole Quartus project with mif_path baked in as the
    ROM's init_file and programs the board — the slow path, used once
    up front to establish a baseline bitstream, and again as a
    fallback if a test times out (see run_one)."""
    rom_target = project_dir / cfg["quartus"]["rom_mif_target"]
    rom_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(mif_path, rom_target)

    # Quartus' incremental compilation caches synthesized netlists across
    # runs, including the ROM megafunction's baked-in init_file content —
    # since that .mif is read as a string parameter, not tracked as a
    # project source, changing it does NOT invalidate the cache. Without
    # this, recompiling would silently reprogram whatever ROM content was
    # cached from the previous compile, no matter what .mif we just wrote.
    for stale in ("db", "incremental_db", "output_files", "simulation"):
        shutil.rmtree(project_dir / stale, ignore_errors=True)

    run(["quartus_sh", "--flow", "compile", cfg["quartus"]["project_name"]], cwd=project_dir)
    # -c pins the cable explicitly: with a second board's blaster also
    # enumerated (see detect_jtag_hardware), letting quartus_pgm guess
    # is no longer safe.
    run(["quartus_pgm", "-c", jtag_hardware, "-m", "JTAG", "-o", f"p;{project_dir / cfg['quartus']['sof_file']}"])


def run_test_via_jtag(cfg: dict, jtag_hardware: str, entry: dict) -> int | None:
    """Loads entry's ROM and pulses the restart flag on the already-
    programmed board, then polls the mailbox up to entry's timeout_s.
    Returns the mailbox value (1 PASS, 2 FAIL) or None on timeout."""
    write_rom_via_jtag(cfg, jtag_hardware, ROOT / entry["mif"])
    pulse_go_flag(cfg, jtag_hardware)

    poll_s = cfg["quartus"]["poll_interval_seconds"]
    deadline = time.monotonic() + entry["timeout_s"]
    while time.monotonic() < deadline:
        mailbox = read_mailbox(cfg, jtag_hardware)
        if mailbox in (1, 2):
            return mailbox
        time.sleep(poll_s)
    return None


def run_one(cfg: dict, jtag_hardware: str, entry: dict, build_dir: Path, project_dir: Path) -> bool:
    name = entry["name"]
    print(f"\n=== {name} ({entry['march']}, {entry['kind']}, timeout={entry['timeout_s']}s) ===")

    mailbox = run_test_via_jtag(cfg, jtag_hardware, entry)
    if mailbox is None:
        print(
            f"{name}: no mailbox result after {entry['timeout_s']}s; the board may have "
            "wedged (e.g. a dropped JTAG chain) rather than the test hanging — "
            "falling back to a full recompile+reprogram+retry"
        )
        full_reconfigure(cfg, jtag_hardware, ROOT / entry["mif"], project_dir)
        wait_s = cfg["quartus"]["program_wait_seconds"]
        print(f"Waiting {wait_s}s for the program to run ...")
        time.sleep(wait_s)
        mailbox = read_mailbox(cfg, jtag_hardware)

    if mailbox == 1:
        print(f"{name}: PASS (mailbox=1)")
        passed = True
    elif mailbox == 2:
        print(f"{name}: FAIL (mailbox=2)")
        passed = False
    else:
        print(f"{name}: TIMEOUT/UNKNOWN (mailbox={mailbox}); program may not have finished")
        passed = False

    if entry["kind"] == "memory":
        dump_path = build_dir / f"{name}_ram.mif"
        dump_ram(cfg, jtag_hardware, dump_path)
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
    if not manifest:
        print("Manifest is empty; nothing to run", file=sys.stderr)
        sys.exit(1)

    jtag_hardware = detect_jtag_hardware()
    print(f"JTAG hardware: {jtag_hardware}")

    project_dir = ROOT / cfg["quartus"]["project_dir"]
    print("Compiling and programming the board once ...")
    full_reconfigure(cfg, jtag_hardware, ROOT / manifest[0]["mif"], project_dir)

    results = {entry["name"]: run_one(cfg, jtag_hardware, entry, build_dir, project_dir) for entry in manifest}

    print("\n=== Summary ===")
    for name, ok in results.items():
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")

    if not all(results.values()):
        sys.exit(1)


if __name__ == "__main__":
    main()
