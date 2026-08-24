#!/usr/bin/env python3
"""Scans tests/c/real or tests/c/sim, compiles each .c/.S against the
configured memory map, and emits either an FPGA-ready .mif (real) or a
plain-text .hex (sim), plus a manifest.json the downstream runner
(build_fpga.py / run_sim_tests.py) consumes.

Per-test header conventions, read from comments at the top of the .c/.S file:

  // RV32_EXT: M          -> compiled with -march=rv32im (additions to
  // RV32_EXT: M,A        -> the implicit rv32i base; order doesn't matter,
                              it's normalized against isa.canonical_order)
  // RV32_TEST_KIND: unit          -> default. Checked via the PASS/FAIL
                                       mailbox only (see rv32_test.h).
  // RV32_TEST_KIND: memory        -> real tests only. Additionally dumps
                                       the whole RAM and compares it against
                                       tests/c/real/golden/<name>.json.
  // RV32_TIMEOUT_S: 5              -> real tests only. How long build_fpga.py
                                       waits for this test's mailbox before
                                       falling back to a full reprogram+retry.
                                       Defaults to quartus.default_timeout_s.
                                       Simple unit tests can go low; slower/
                                       memory tests may need more.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
CONFIG_PATH = HERE / "config.yaml"

EXT_RE = re.compile(r"^\s*//\s*RV32_EXT:\s*(.+?)\s*$", re.MULTILINE)
KIND_RE = re.compile(r"^\s*//\s*RV32_TEST_KIND:\s*(unit|memory)\s*$", re.MULTILINE)
TIMEOUT_RE = re.compile(r"^\s*//\s*RV32_TIMEOUT_S:\s*([0-9.]+)\s*$", re.MULTILINE)


def load_config() -> dict:
    return yaml.safe_load(CONFIG_PATH.read_text())


def canonical_march(cfg: dict, ext_csv: str) -> str:
    base = "rv32" + cfg["isa"]["base"]
    if not ext_csv:
        return base
    order = cfg["isa"]["canonical_order"]
    letters = {e.strip().upper() for e in ext_csv.split(",") if e.strip()}
    unknown = letters - set(order)
    if unknown:
        raise ValueError(
            f"Unknown extension(s) {sorted(unknown)}; add them to "
            f"isa.canonical_order in config.yaml"
        )
    sorted_ext = "".join(letter for letter in order if letter in letters).lower()
    return base + sorted_ext


def parse_header(cfg: dict, text: str) -> tuple[str, str, float]:
    ext_match = EXT_RE.search(text)
    ext_csv = ext_match.group(1) if ext_match else ""
    kind_match = KIND_RE.search(text)
    kind = kind_match.group(1) if kind_match else "unit"
    timeout_match = TIMEOUT_RE.search(text)
    timeout_s = float(timeout_match.group(1)) if timeout_match else float(cfg["quartus"]["default_timeout_s"])
    return ext_csv, kind, timeout_s


def compile_test(cfg: dict, c_file: Path, build_dir: Path) -> tuple[Path, str, str, float]:
    ext_csv, kind, timeout_s = parse_header(cfg, c_file.read_text())
    march = canonical_march(cfg, ext_csv)

    build_dir.mkdir(parents=True, exist_ok=True)
    elf = build_dir / f"{c_file.stem}.elf"
    bin_ = build_dir / f"{c_file.stem}.bin"

    include_dir = ROOT / cfg["paths"]["include_dir"]
    crt0 = ROOT / cfg["paths"]["crt0"]
    linker = ROOT / cfg["paths"]["linker_script"]

    subprocess.run(
        [
            cfg["toolchain"]["gcc"],
            f"-march={march}", "-mabi=ilp32", "-Os",
            "-ffreestanding", "-nostdlib", "-nostartfiles",
            f"-I{include_dir}",
            f"-Wl,-T,{linker}",
            str(crt0), str(c_file),
            "-o", str(elf),
        ],
        check=True,
    )
    subprocess.run([cfg["toolchain"]["objcopy"], "-O", "binary", str(elf), str(bin_)], check=True)
    return bin_, march, kind, timeout_s


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--emit", choices=["mif", "hex"], required=True,
        help="mif -> compiles tests/c/real for the FPGA; hex -> compiles tests/c/sim for simulation",
    )
    args = parser.parse_args()

    cfg = load_config()
    is_real = args.emit == "mif"
    src_dir = ROOT / (cfg["paths"]["tests_real_dir"] if is_real else cfg["paths"]["tests_sim_dir"])
    build_dir = ROOT / cfg["paths"]["build_dir"] / ("real" if is_real else "sim")

    sys.path.insert(0, str(HERE))
    if is_real:
        from bin_to_mif import bin_to_mif
    else:
        from bin_to_hex import bin_to_hex

    # .S is supported alongside .c: gcc preprocesses+assembles it the
    # same way it compiles .c (same crt0/linker/header conventions
    # below apply — just no C-level codegen to second-guess the exact
    # instruction sequence, useful when the addressing mode itself is
    # what's under test).
    c_files = sorted(src_dir.glob("*.c")) + sorted(src_dir.glob("*.S"))
    if not c_files:
        print(f"No .c/.S files found in {src_dir}", file=sys.stderr)
        sys.exit(1)

    manifest = []
    for c_file in c_files:
        print(f"Building {c_file.relative_to(ROOT)} ...")
        bin_, march, kind, timeout_s = compile_test(cfg, c_file, build_dir)

        entry = {"name": c_file.stem, "march": march, "kind": kind}
        if is_real:
            entry["timeout_s"] = timeout_s
            mif = build_dir / f"{c_file.stem}.mif"
            bin_to_mif(bin_, mif, depth=cfg["memory"]["rom_words"])
            entry["mif"] = str(mif.relative_to(ROOT))
            if kind == "memory":
                golden = ROOT / cfg["paths"]["golden_dir"] / f"{c_file.stem}.json"
                if not golden.is_file():
                    print(
                        f"ERROR: {c_file.name} is RV32_TEST_KIND: memory but "
                        f"{golden.relative_to(ROOT)} is missing",
                        file=sys.stderr,
                    )
                    sys.exit(1)
                entry["golden"] = str(golden.relative_to(ROOT))
        else:
            hex_ = build_dir / f"{c_file.stem}.hex"
            bin_to_hex(bin_, hex_)
            entry["hex"] = str(hex_.relative_to(ROOT))

        manifest.append(entry)

    manifest_path = build_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    print(f"Wrote {manifest_path.relative_to(ROOT)} ({len(manifest)} test(s))")


if __name__ == "__main__":
    main()
