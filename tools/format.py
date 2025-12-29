#!/usr/bin/env python3
"""Format a hex instruction stream into memfile.dat for the Project-2 imem.

Expected input: a text file or stdin containing 32-bit instructions as 8 hex chars each.
Examples (one per line):
  05401234
  0A1B2C3D

Output: memfile.dat with ONE BYTE (2 hex chars) per line, little-endian per instruction:
  instr 0x11223344 -> lines: 44, 33, 22, 11

Usage:
  python3 format.py input.hex memfile.dat
  # or interactive: python3 format.py
"""

import sys

def normalize_line(s: str) -> str:
    s = s.strip().replace(" ", "").replace("_", "")
    if s.startswith("0x") or s.startswith("0X"):
        s = s[2:]
    return s

def instr_to_bytes_le(h8: str):
    if len(h8) != 8:
        raise ValueError(f"Instruction must be 8 hex chars (32-bit). Got: '{h8}'")
    b0 = h8[6:8]
    b1 = h8[4:6]
    b2 = h8[2:4]
    b3 = h8[0:2]
    return [b0, b1, b2, b3]

def main():
    if len(sys.argv) == 3:
        inp_path, out_path = sys.argv[1], sys.argv[2]
        with open(inp_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    else:
        print("Enter 32-bit instructions (8 hex chars each). End with EOF (Ctrl+D on Linux/Mac, Ctrl+Z then Enter on Windows):")
        lines = sys.stdin.readlines()
        out_path = "./memfile.dat"

    out_lines = []
    for line in lines:
        s = normalize_line(line)
        if not s:
            continue
        out_lines.extend(instr_to_bytes_le(s))

    with open(out_path, "w", encoding="utf-8") as out:
        out.write("\n".join(out_lines) + ("\n" if out_lines else ""))
    print(f"Wrote {len(out_lines)} bytes to {out_path}")

if __name__ == "__main__":
    main()
