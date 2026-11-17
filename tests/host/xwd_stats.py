#!/usr/bin/env python3
"""Reads an XWD framebuffer (Xvfb -fbdir writes Xvfb_screen0 as one) and
prints what the game drew: the size, the pixels that are not black, and how
many colours (5 bits a channel), counting every 4th pixel each way.
    xwd_stats.py Xvfb_screen0 [--png out.png] [--box X0 Y0 X1 Y1]
MIT, Copyright (c) 2026 AmiCradle Team."""
import struct, sys, zlib

args = sys.argv[1:]
path = args.pop(0)
png = None
box = None
while args:
    a = args.pop(0)
    if a == "--png":
        png = args.pop(0)
    elif a == "--box":
        box = [int(args.pop(0)) for _ in range(4)]
d = open(path, "rb").read()
f = struct.unpack(">25I", d[:100])
hs, w, h, bpl, ncol = f[0], f[4], f[5], f[12], f[19]
off = hs + ncol * 12
x0, y0, x1, y1 = box or (0, 0, w, h)
lit = 0
cols = set()
yellow = 0
for y in range(y0, y1, 4):
    for x in range(x0, x1, 4):
        p = off + y * bpl + x * 4
        b, g, r = d[p], d[p + 1], d[p + 2]
        if r | g | b:
            lit += 1
            cols.add((r >> 3, g >> 3, b >> 3))
        if r > 160 and g > 160 and b < 100:
            yellow += 1
print("size %d %d lit %d colours %d yellow %d" % (w, h, lit, len(cols), yellow))
if png:
    raw = b"".join(b"\0" + bytes(v for x in range(w) for v in (d[off + y * bpl + x * 4 + 2], d[off + y * bpl + x * 4 + 1], d[off + y * bpl + x * 4])) for y in range(h))
    def ch(t, x):
        return struct.pack(">I", len(x)) + t + x + struct.pack(">I", zlib.crc32(t + x) & 0xffffffff)
    open(png, "wb").write(b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                          + ch(b"IDAT", zlib.compress(raw)) + ch(b"IEND", b""))
