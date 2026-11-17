#!/bin/sh
# The release archive and the GFOpenUp part, for Cradle's stove_build
# (target package):
#  1. upstream Pacman Arena, the commit package/pacmanarena.lock names
#     (fetched, never kept in this repository), with amiga/patches;
#  2. the host tests (tests/host/test_pacmanarena.sh), when the machine has
#     SDL 2, GL and Xvfb;
#  3. the game for the 68040 with its FPU (GFOpenGPU's GL and our SDL 2 are
#     hard float): upstream's C, its lib3ds and its SGI GLU subset
#     (mipmaps and quadrics: GFOpenGPU's kit has no GLU), linked with the
#     stove's SDL2 and GL, and SDL2_mixer when the stove has it (without
#     it the game is built silent, upstream's NOSOUND, and says so here);
#  4. the drawer (the game, gfx/, sfx/, ReadMe, licence, GlowIcons) and
#     the Installer script packed as NAME-VERSION-68040.lha
#     (tools/pack_dist.py), with its .sha256 and a short .readme;
#  5. OUT/Parts/PacmanArena, a GFOpenUp part (needs the GFOpenGPU part)
#     for SYS:Games/PacmanArena, installed with
#       GFOpenUpTool INSTALL Parts/PacmanArena
# Nothing is published from here.
# MIT, Copyright (c) 2026 AmiCradle Team.
set -eu
# everything on stdout, and the step a failure stopped in: the stove log keeps only stdout
exec 2>&1
STEP=start
trap 'rc=$?; [ $rc = 0 ] || echo "build-amiga.sh: failed (exit $rc) in step: $STEP"' EXIT

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
. "$HERE/package.env"
. "$HERE/pacmanarena.lock"
OUT=${OUT:-"$ROOT/build-amiga-package"}
mkdir -p "$OUT"
OUT=$(CDPATH= cd -- "$OUT" && pwd)
STOVE=${STOVE:-"$HOME/AmiCradle/kitchen/stoves/os32-gcc16-open6"}
# outside the checkout: Cradle cleans it (git clean -ffdx) before every job
WORK=${WORK:-"$HOME/.cache/amigapacmanarena"}
mkdir -p "$WORK"
cd "$ROOT"
t0=$(date +%s)
if [ -x "$STOVE/prefix/bin/m68k-amigaos-gcc" ]; then TC="$STOVE/prefix"; else TC="$STOVE"; fi

# 1. upstream at the locked commit, patched afresh every time
STEP=upstream
SRC="$WORK/pacmanarena-git"
if [ "$(git -C "$SRC" rev-parse HEAD 2>/dev/null)" != "$UP_COMMIT" ]; then
    rm -rf "$SRC"; mkdir -p "$SRC"
    git -C "$SRC" init -q
    git -C "$SRC" fetch -q --depth 1 "$UP_URL" "$UP_COMMIT"
    git -C "$SRC" checkout -q FETCH_HEAD
fi
UPSRC="$WORK/pacmanarena-$UP_VERSION"
rm -rf "$UPSRC"; mkdir -p "$UPSRC"
git -C "$SRC" archive HEAD | tar x -C "$UPSRC"
for p in "$ROOT"/amiga/patches/*.patch; do
    patch -s -d "$UPSRC" -p1 < "$p"
done

# 2. the host tests
STEP="host tests"
UP="$UPSRC" sh tests/host/test_pacmanarena.sh

# 3. the game
STEP=build
SDK="$TC/m68k-amigaos"
for f in include/GL/gl.h include/SDL2/SDL.h lib/libGL.a lib/libSDL2.a; do
    [ -f "$SDK/$f" ] || { echo "the stove has no $f"; exit 2; }
done
SOUND=-DNOSOUND; MIXLIB=
if [ -f "$SDK/include/SDL2/SDL_mixer.h" ] && [ -f "$SDK/lib/libSDL2_mixer.a" ]; then
    SOUND=; MIXLIB=-lSDL2_mixer
else
    echo "note: the stove has no SDL2_mixer: Pacman Arena is built silent (NOSOUND)"
fi
CC="$TC/bin/m68k-amigaos-gcc"
# -fno-tree-loop-distribute-patterns: GCC 16's loop miscompile.
CF="-noixemul -m68040 -m68881 -O2 -fomit-frame-pointer -fno-tree-loop-distribute-patterns -std=gnu99 -fcommon
    -w -Werror=implicit-function-declaration -D__amigaos__ -DSDL2 -DPA_OWN_GL_CONTEXT $SOUND
    -I$ROOT/amiga -I$UPSRC/src -I$UPSRC/src/include -I$UPSRC -I$UPSRC/platform/generic -I$UPSRC/lib3ds
    -I$UPSRC/GLU/src/include -I$UPSRC/GLU/src/libutil -I$SDK/include -I$SDK/include/SDL2"
O="$WORK/obj"; rm -rf "$O"; mkdir -p "$O"
n=0
for f in "$UPSRC"/src/*.c "$UPSRC"/src/main/*.c "$UPSRC"/lib3ds/*.c \
         "$UPSRC"/GLU/src/libutil/*.c "$UPSRC"/GLU/src/libutil/quad/*.c; do
    case $f in */vita_stubs.c) continue;; esac  # (the PS Vita's GL stubs)
    o="$O/$(echo "${f#$UPSRC/}" | tr / _).o"
    $CC $CF -c -o "$o" "$f" > "$O/cc.log" 2>&1 || { cat "$O/cc.log" | head -30; exit 1; }
    n=$((n + 1))
done
echo "compile: $n files, $(( $(date +%s) - t0 )) s"
$CC -noixemul -m68040 -m68881 -o "$O/PacmanArena.debug" "$O"/*.o \
    -L"$SDK/lib" $MIXLIB -lSDL2 -lGL -lm -lpthread -latomic > "$O/link.log" 2>&1 || { head -60 "$O/link.log"; exit 1; }

# 4. the drawer and the archive
STEP=archive
D="$DIST/$NAME"; rm -rf "$DIST"; mkdir -p "$D"
"$TC/bin/m68k-amigaos-strip" -o "$D/PacmanArena" "$O/PacmanArena.debug"
cp -R "$UPSRC/gfx" "$UPSRC/sfx" "$D/"
cp AMIGA_PORT.md "$D/ReadMe"
cp "$UPSRC/COPYING" "$D/COPYING.txt"
cp amiga/icons/PacmanArena.info amiga/icons/ReadMe.info "$D/"
cp amiga/icons/ReadMe.info "$D/COPYING.txt.info"
cp amiga/icons/PacmanArena-drawer.info "$DIST/$NAME.info"
cp amiga/Install-PacmanArena amiga/Install-PacmanArena.info "$DIST/"
python3 "$ROOT/tools/pack_dist.py" --dist "$DIST" --name "$NAME" --out "$OUT"

# 5. the GFOpenUp part
STEP=part
sh "$ROOT/package/write-part.sh" "$D" "$OUT/Parts/$NAME" "$NAME" "$PORT_VERSION" \
    "Pacman Arena: 3D Pacman with missiles and bombs, drawn with GFOpenGPU's GL"
echo "part: $(grep -c '^copy' "$OUT/Parts/$NAME/Part") files, $(du -sk "$OUT/Parts/$NAME" | cut -f1) KB"
ls -l "$D/PacmanArena"
echo "total: $(( $(date +%s) - t0 )) s"
