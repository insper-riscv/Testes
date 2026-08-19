#!/usr/bin/env python3
"""Converts a flat RV32 .bin into an Intel/Altera .mif, for the ROM IP
that Quartus reads at synthesis time."""
import struct
import sys
from pathlib import Path


def bin_to_mif(bin_path: Path, mif_path: Path, depth: int) -> int:
    data = Path(bin_path).read_bytes()
    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)
    words = [w for (w,) in struct.iter_unpack("<I", data)]

    if len(words) > depth:
        raise ValueError(
            f"{bin_path}: program is {len(words)} words, ROM only holds "
            f"{depth} (memory.rom_words in config.yaml)"
        )

    lines = [
        "WIDTH=32;",
        f"DEPTH={depth};",
        "",
        "ADDRESS_RADIX=HEX;",
        "DATA_RADIX=HEX;",
        "",
        "CONTENT BEGIN",
    ]
    for i, w in enumerate(words):
        lines.append(f"    {i:04X} : {w:08X};")
    if len(words) < depth:
        lines.append(f"    [{len(words):04X}..{depth - 1:04X}] : 00000000;")
    lines.append("END;")

    Path(mif_path).write_text("\n".join(lines) + "\n")
    return len(words)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: bin_to_mif.py <in.bin> <out.mif> <depth>", file=sys.stderr)
        sys.exit(1)
    n = bin_to_mif(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]))
    print(f"Wrote {sys.argv[2]} ({n} words)")
