#!/usr/bin/env python3
"""Converts a flat RV32 .bin into plain-text hex (one 32-bit word per
line) — the format sim/test_c_program.py loads into the DUT's ROM."""
import struct
import sys
from pathlib import Path


def bin_to_hex(bin_path: Path, hex_path: Path) -> int:
    data = Path(bin_path).read_bytes()
    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)
    words = [w for (w,) in struct.iter_unpack("<I", data)]
    Path(hex_path).write_text("\n".join(f"{w:08X}" for w in words) + "\n")
    return len(words)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: bin_to_hex.py <in.bin> <out.hex>", file=sys.stderr)
        sys.exit(1)
    n = bin_to_hex(Path(sys.argv[1]), Path(sys.argv[2]))
    print(f"Wrote {sys.argv[2]} ({n} words)")
