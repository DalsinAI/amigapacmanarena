# Pacman Arena for GFOS

The AmiCradle Team's port of Pacman Arena (by subtil; gameblabla's SDL 2
version) to GFOS: AmigaOS 3.2 with GFOpenUp, 68040/68060 with an FPU. A
Pacman game in a 3D maze, with missiles and bombs, drawn with OpenGL on
GFOpenGPU's GL through our SDL 2. It ships as a release archive with an
Installer and as the GFOpenUp part Parts/PacmanArena (it needs the
GFOpenGPU part).

Upstream is fetched at build time (package/pacmanarena.lock) and patched
(amiga/patches); this repository holds only the Amiga port. See
[AMIGA_PORT.md](AMIGA_PORT.md).

Pacman Arena is GPL-2.0 (COPYING.txt in the drawer); the port's own files
(amiga/, tests/, package/, tools/) are MIT. Copyright (c) 2026 AmiCradle
Team.
