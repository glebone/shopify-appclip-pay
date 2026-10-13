#!/usr/bin/env python3
"""Write a 1200x630 solid PNG for og:image. Usage: make_preview.py out.png"""
import struct, sys, zlib

W, H = 1200, 630
R, G, B = 0x1E, 0x7A, 0xFF  # blue

def chunk(tag: bytes, data: bytes) -> bytes:
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

row = b"\x00" + bytes([R, G, B]) * W
raw = row * H
png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9))
       + chunk(b"IEND", b""))
with open(sys.argv[1], "wb") as f:
    f.write(png)
