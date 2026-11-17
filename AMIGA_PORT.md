Pacman Arena for GFOS
=====================

Pacman Arena: eat the pellets in a 3D maze while the ghosts chase you.
Pacman can fight back: he fires missiles and drops bombs.

The cursor keys move Pacman, Ctrl fires a missile, Alt drops a bomb.
In the menu the cursor keys choose and Return starts. Escape ends the
game, and Escape in the menu quits (as does the window's close gadget).

What it needs
-------------
GFOS (AmigaOS 3.2 with GFOpenUp) on a 68040 or 68060 with its FPU, and
the GFOpenGPU part (its GL and our SDL 2). The game opens an 800 x 600
GL window. About 28 MB on disk (gfx/ and sfx/).

How it was ported
-----------------
The game is built from upstream with one patch (amiga/patches/0001):
 - it makes its own GL context (SDL_GL_CreateContext) instead of relying
   on an SDL renderer to have made one, and asks for a GL every GL has
   (16-bit depth, no multisampling) instead of a 32-bit depth buffer
   with 8 x multisampling;
 - its data comes from PROGDIR:gfx and PROGDIR:sfx ("./gfx" is no
   AmigaDOS path);
 - its data files are read right on a big-endian 68k (upstream tested
   #ifdef SDL_LIL_ENDIAN, which is always defined, so it never swapped;
   the TGA header's width and height are now read little-endian too);
 - a silent build (NOSOUND) needs no SDL_mixer header, for a stove
   without SDL2_mixer;
 - a NULL glGetString and a pointer cut to int on 64-bit hosts are
   fixed.
GLU (mipmaps, the spheres) is upstream's own SGI GLU subset: GFOpenGPU's
kit has no GLU.

Tests: tests/host/test_pacmanarena.sh builds the game the way the Amiga
build does and runs it under Xvfb with Mesa's software GL: the menu (its
title and maze), Return starting a game, the cursor keys moving it on,
Escape, a silent build, the AmigaOS data paths, and a whole run under
AddressSanitizer.

Credits
-------
Pacman Arena (c) 2003 subtil, SDL 2 version by gameblabla, GPL-2.0
(COPYING.txt). lib3ds (c) Jan Eric Kyprianidis, LGPL-2.1. GLU (c) SGI,
Free Software License B.
Amiga port: Designed, tested and delivered by The AmiCradle Team.
Copyright (c) 2026 AmiCradle Team; the port's own files MIT.
