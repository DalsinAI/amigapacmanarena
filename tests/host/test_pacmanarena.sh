#!/bin/sh
# Host tests of the port, on this machine: upstream's Pacman Arena with
# amiga/patches applied, built the way the Amiga build is (its own GL
# context, its own SGI GLU subset, no SDL renderer), with SDL 2 and GL,
# run under Xvfb with Mesa's software GL; xdotool sends the keys and
# tests/host/xwd_stats.py reads the framebuffer:
#  - the game finds a GL visual and a context of its own and draws the menu
#    (the yellow title, the maze behind it);
#  - Return starts a game: the frame changes and the maze fills the screen;
#  - the cursor keys move Pacman: the frame changes again;
#  - Escape ends the game, and Escape in the menu quits;
#  - a silent build (NOSOUND, as on a stove without SDL2_mixer) builds and
#    draws the menu too;
#  - the data paths: FILE_PATH_FMT and FILE_BASE_PATH give "PROGDIR:gfx/..."
#    on AmigaOS and "./gfx/..." here;
#  - with AddressSanitizer, when the compiler has it: no bad reads.
# Skipped, with the reason, without a C compiler, SDL 2 (sdl2-config),
# SDL2_mixer, GL, Xvfb or xdotool.
#   UP=/path/to/pacman-arena (patched) sh tests/host/test_pacmanarena.sh
# Copyright (c) 2026 AmiCradle Team. MIT (the port's own files).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UP=${UP:?UP=upstream source}
CC=${HOSTCC:-cc}
for t in "$CC" sdl2-config Xvfb xvfb-run xdotool python3; do
    command -v "$t" >/dev/null 2>&1 || { echo "host tests: skipped (no $t)"; exit 0; }
done
T=$(mktemp -d "${TMPDIR:-/tmp}/pacmanarena-host.XXXXXX")
[ -n "${TEST_KEEP:-}" ] || trap 'rm -rf "$T"' EXIT INT TERM
echo 'int main(void){return 0;}' | $CC -x c -o "$T/glprobe" - -lGL -lSDL2_mixer $(sdl2-config --libs) >/dev/null 2>&1 \
    || { echo "host tests: skipped (no GL or SDL2_mixer to link with)"; exit 0; }

build() {	# output, extra flags
    out=$1; shift
    mkdir -p "$out.o"
    for f in "$UP"/src/*.c "$UP"/src/main/*.c "$UP"/lib3ds/*.c "$UP"/GLU/src/libutil/*.c "$UP"/GLU/src/libutil/quad/*.c; do
        case $f in */vita_stubs.c) continue;; esac
        $CC -std=gnu99 -O1 -w -Werror=implicit-function-declaration -DSDL2 -DPA_OWN_GL_CONTEXT "$@" \
            -I"$UP/src" -I"$UP/src/include" -I"$UP" -I"$UP/platform/generic" -I"$UP/lib3ds" \
            -I"$UP/GLU/src/include" -I"$UP/GLU/src/libutil" $(sdl2-config --cflags) \
            -c -o "$out.o/$(echo "${f#$UP/}" | tr / _).o" "$f"
    done
    case " $* " in *" -DNOSOUND "*) mix= ;; *) mix=-lSDL2_mixer ;; esac
    $CC "$@" -o "$out" "$out.o"/*.o $mix $(sdl2-config --libs) -lGL -lm
}
build "$T/pac"
fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# run the game under Xvfb: keys and framebuffer snapshots, "WAIT KEY|shot:NAME ..."
run() {	# game, steps...
    game=$1; shift
    mkdir -p "$T/fb"
    cat > "$T/drive.sh" <<EOF
cd "$UP"
"$game" > "$T/game.out" 2>&1 &
P=\$!
for s in $*; do
    case \$s in
        shot:*) cp "$T/fb/Xvfb_screen0" "$T/\${s#shot:}.xwd" ;;
        [0-9]*) sleep \$s ;;
        *) timeout 10 xdotool search --sync --name 'Pacman Arena' windowfocus --sync >/dev/null 2>&1 || true; timeout 5 xdotool key \$s || true ;;
    esac
done
sleep 1
if kill -0 \$P 2>/dev/null; then echo running > "$T/state"; kill \$P; else wait \$P; echo "exit \$?" > "$T/state"; fi
EOF
    echo "no state" > "$T/state"
    SDL_AUDIODRIVER=dummy ASAN_OPTIONS=detect_leaks=0 timeout 120 \
        xvfb-run -a -s "-screen 0 800x600x24 +extension GLX -fbdir $T/fb" sh "$T/drive.sh" || echo "(Xvfb run: exit $?)"
}
stat() { python3 "$HERE/xwd_stats.py" "$@"; }
num() { echo "$1" | sed "s/.* $2 \([0-9]*\).*/\1/"; }

run "$T/pac" 5 shot:menu Return 3 shot:game Right Right 1 shot:moved Escape 2 Escape 1
m=$(stat "$T/menu.xwd" --box 0 0 800 200); g=$(stat "$T/game.xwd"); mv=$(stat "$T/moved.xwd")
if ! grep -q 'no GL window' "$T/game.out" && [ "$(num "$m" yellow)" -gt 200 ]; then pass "a GL context of its own; the menu's yellow title ($m)"; else fail "menu: $m"; cat "$T/game.out"; fi
if [ "$(num "$(stat "$T/menu.xwd")" lit)" -gt 3000 ]; then pass "the maze behind the menu"; else fail "no maze"; fi
if ! cmp -s "$T/menu.xwd" "$T/game.xwd" && [ "$(num "$g" colours)" -gt 30 ]; then pass "Return starts a game ($g)"; else fail "game: $g"; fi
if ! cmp -s "$T/game.xwd" "$T/moved.xwd"; then pass "the cursor keys: the frame moves on"; else fail "nothing moved"; fi
if grep -q 'exit 0' "$T/state"; then pass "Escape ends the game, Escape in the menu quits"; else fail "quit: $(cat "$T/state")"; fi

build "$T/silent" -DNOSOUND
run "$T/silent" 5 shot:silent Escape 1
if [ "$(num "$(stat "$T/silent.xwd" --box 0 0 800 200)" yellow)" -gt 200 ]; then pass "a silent build (NOSOUND) draws the menu"; else fail "silent build"; fi

cat > "$T/paths.c" <<'C'
#include <stdio.h>
#include <string.h>
#include "file.h"
int main(void)
{
	char b[64];
	snprintf(b, sizeof b, FILE_PATH_FMT, FILE_BASE_PATH, "gfx/bomb.3d");
	puts(b);
	return 0;
}
C
a=$($CC -D__amigaos__ -I"$UP/src/include" -I"$UP/platform/generic" -o "$T/paths_a" "$T/paths.c" $(sdl2-config --cflags) && "$T/paths_a")
h=$($CC -I"$UP/src/include" -I"$UP/platform/generic" -o "$T/paths_h" "$T/paths.c" $(sdl2-config --cflags) && "$T/paths_h")
if [ "$a" = "PROGDIR:gfx/bomb.3d" ] && [ "$h" = "./gfx/bomb.3d" ]; then pass "data paths: $a on AmigaOS, $h here"; else fail "paths: '$a' '$h'"; fi

if echo 'int main(void){return 0;}' | $CC -fsanitize=address -x c -o "$T/asan_probe" - >/dev/null 2>&1 && "$T/asan_probe"; then
    build "$T/asan" -g -fsanitize=address
    run "$T/asan" 6 Return 3 Right Left 1 Escape 2 Escape 1
    if ! grep -q 'ERROR: AddressSanitizer' "$T/game.out"; then pass "AddressSanitizer: menu, a game, quit, no bad reads"; else fail "AddressSanitizer"; grep -A8 ERROR "$T/game.out" | head -12; fi
else
    echo "skip AddressSanitizer (not in this compiler)"
fi

if [ "$fails" -ne 0 ]; then echo "host tests: $fails failed"; exit 1; fi
echo "host tests: all passed"
