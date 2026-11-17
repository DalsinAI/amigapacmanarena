#!/usr/bin/env python3
"""Pacman Arena's picture for its GlowIcons (art/pacmanarena.png), drawn
here: a yellow Pacman in a blue maze with pellets and a ghost, as the game
shows them. 64 x 64, RGBA.
    python3 amiga/icons/draw_art.py amiga/icons/art
Pure Python. MIT, Copyright (c) 2026 AmiCradle Team."""
import math, struct, sys, zlib
from pathlib import Path

W = H = 64
INK = (10, 10, 18, 255)
BLUE = (70, 110, 220, 255)
DEEP = (40, 60, 150, 255)
YELLOW = (250, 220, 40, 255)
PELLET = (250, 240, 190, 255)
RED = (220, 50, 40, 255)
WHITE = (240, 240, 240, 255)


def png(px, path):
    raw = b"".join(b"\0" + bytes(v for p in row for v in p) for row in px)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def draw():
    px = [[(0, 0, 0, 0)] * W for _ in range(H)]
    def rect(x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(H, y1)):
            for x in range(max(0, x0), min(W, x1)):
                px[y][x] = c
    def wall(x0, y0, x1, y1):
        rect(x0, y0, x1, y1, DEEP)
        rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, BLUE)
    rect(2, 2, 62, 62, INK)
    wall(4, 4, 60, 9); wall(4, 55, 60, 60); wall(4, 4, 9, 60); wall(55, 4, 60, 60)
    wall(16, 16, 26, 26); wall(38, 16, 48, 26); wall(16, 38, 48, 44)
    for x in range(14, 54, 6):
        rect(x, 31, x + 2, 33, PELLET)
    # Pacman, mouth to the right
    cx, cy, r = 20, 32, 7
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= r * r and not (dx > 0 and abs(dy) < dx * 0.7):
                px[y][x] = YELLOW
    # a ghost
    gx, gy = 42, 46
    for y in range(gy, gy + 8):
        for x in range(gx - 5, gx + 6):
            if y > gy + 2 or (x - gx) ** 2 + (y - gy - 3) ** 2 <= 30:
                if not (y == gy + 7 and (x - gx) % 3 == 0):
                    px[y][x] = RED
    rect(gx - 3, gy + 2, gx - 1, gy + 4, WHITE); rect(gx + 1, gy + 2, gx + 3, gy + 4, WHITE)
    return px


if __name__ == "__main__":
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "art")
    out.mkdir(parents=True, exist_ok=True)
    png(draw(), out / "pacmanarena.png")
