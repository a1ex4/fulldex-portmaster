#!/bin/bash
# Builds the PortMaster package of Pokemon Fulldex for aarch64 (glibc 2.31), in Docker.
#
#   ./build.sh --rom your-soulsilver-us.nds   SoulSilver's address tables from your own ROM
#   ./build.sh --decomp                       ... or from pret/pokeheartgold, built from source
#
# The ROM (or the decompilation's build) is only read for the addresses in SoulSilver and
# HeartGold's tables, as upstream's tools/pc/build_all.sh does: nothing of the game is packaged.
# Result: dist/pokemonfulldex.zip
set -euo pipefail

FULLDEX_URL=https://github.com/mamesj/pokemon-fulldex.git
PHG_URL=https://github.com/pret/pokeheartgold.git
SHA1_SS=f8dc38ea20c17541a43b58c5e6d18c1732c7e582   # Pokemon SoulSilver (USA)

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/upstream.env"
# The work folder (sources, tables, the build): kept between builds, so they are incremental.
W="${FULLDEX_WORK:-$HERE/work}"
mkdir -p "$W"
say() { printf '\n== %s\n' "$*"; }
fail() { printf '\nerror: %s\n' "$*" >&2; exit 1; }
# Runs a command in an image, as this user, with the project at /p and the work folder at /w.
in_docker() { local image="$1"; shift; docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$HERE:/p" -v "$W:/w" -w /p "$image" "$@"; }

MODE="" ROM=""
case "${1:-}" in
    --rom) MODE=rom; ROM="${2:-}"; [ -f "$ROM" ] || fail "no such file: $ROM" ;;
    --decomp) MODE=decomp ;;
    *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

say "Docker images"
docker build -q -t fulldex-cross -f "$HERE/docker/Dockerfile.cross" "$HERE/docker" >/dev/null
docker build -q -t fulldex-decomp -f "$HERE/docker/Dockerfile.decomp" "$HERE/docker" >/dev/null

say "Pokemon Fulldex $FULLDEX_TAG ($FULLDEX_COMMIT)"
SRC="$W/src"
if [ ! -d "$SRC/.git" ]; then
    git init -q "$SRC"
    git -C "$SRC" remote add origin "$FULLDEX_URL"
fi
git -C "$SRC" fetch -q --depth 1 origin "$FULLDEX_COMMIT"
git -C "$SRC" checkout -q --force FETCH_HEAD
git -C "$SRC" clean -qfdx
git -C "$SRC" apply "$HERE"/patches/*.patch

say "mGBA with the widescreen patch"
GBA="$W/pokemon-gba-wide"
MGBA_COMMIT="$(cat "$SRC/gba/patches/mgba.commit")"
if [ ! -d "$GBA/mgba/.git" ]; then
    git init -q "$GBA/mgba"
    git -C "$GBA/mgba" remote add origin https://github.com/mgba-emu/mgba.git
fi
git -C "$GBA/mgba" fetch -q --depth 1 origin "$MGBA_COMMIT"
git -C "$GBA/mgba" checkout -q --force FETCH_HEAD
git -C "$GBA/mgba" apply "$SRC/gba/patches/mgba-wide.patch"
mkdir -p "$GBA/build/patches"
cp "$SRC/gba/wide-patches/"* "$GBA/build/patches/"

# (Kept between builds of the same upstream and pokeheartgold commits.)
STAMP="$FULLDEX_COMMIT $PHG_COMMIT"
if [ "$(cat "$W/gen-tables/.stamp" 2>/dev/null)" = "$STAMP" ]; then
    say "SoulSilver and HeartGold's tables: already made for this version"
else
say "SoulSilver and HeartGold's tables ($MODE)"
rm -rf "$W/gen" "$W/gen-tables"
if [ "$MODE" = rom ]; then
    [ "$(sha1sum "$ROM" | cut -d' ' -f1)" = "$SHA1_SS" ] || fail "$ROM is not Pokemon SoulSilver (USA)"
    cp "$ROM" "$W/soulsilver-us.nds"
    in_docker fulldex-decomp bash -c 'cd /w/src &&
        python3 tools/recomp.py --rom /w/soulsilver-us.nds --layout layouts/soulsilver-us.json melonDS/src /w/gen &&
        python3 tools/apps.py --layout layouts/soulsilver-us.json /w/gen'
    rm -f "$W/soulsilver-us.nds"
else
    if [ ! -d "$W/pokeheartgold/.git" ]; then
        git init -q "$W/pokeheartgold"
        git -C "$W/pokeheartgold" remote add origin "$PHG_URL"
    fi
    git -C "$W/pokeheartgold" fetch -q --depth 1 origin "$PHG_COMMIT"
    git -C "$W/pokeheartgold" checkout -q --force FETCH_HEAD
    in_docker fulldex-decomp make -C /w/pokeheartgold soulsilver -j"$(nproc)"
    [ "$(sha1sum "$W/pokeheartgold/build/soulsilver.us/pokesoulsilver.us.nds" | cut -d' ' -f1)" = "$SHA1_SS" ] ||
        fail "the decompilation did not build the retail SoulSilver"
    in_docker fulldex-decomp bash -c 'cd /w/src &&
        python3 tools/recomp.py /w/pokeheartgold/build/soulsilver.us melonDS/src /w/gen &&
        python3 tools/apps.py /w/pokeheartgold/build/soulsilver.us /w/gen'
fi
in_docker fulldex-decomp bash -c 'cd /w/src && python3 tools/soulsilver/tables_only.py /w/gen /w/gen-tables'
rm -rf "$W/gen"   # (the recompiled game code: only the tables are kept)
echo "$STAMP" > "$W/gen-tables/.stamp"
fi

say "The function tables"
in_docker fulldex-cross /p/docker/funcs.sh /w/src /w/decomp-symbols /w/funcs
in_docker fulldex-cross bash -c 'cd /w/src &&
    python3 tools/regions/package_profiles.py --funcs /w/funcs --portable /w/gen-tables/rc_portable.cpp'

say "Compiling for aarch64"
in_docker fulldex-cross /p/docker/configure.sh /w/src /w/build /w/gen-tables /w/pokemon-gba-wide >/dev/null
in_docker fulldex-cross ninja -C /w/build ssrecomp

say "The package"
OUT="$HERE/dist/pokemonfulldex"
rm -rf "$HERE/dist"
mkdir -p "$HERE/dist"
cp -r "$HERE/port/pokemonfulldex" "$OUT"
G="$OUT/pokemonfulldex"
cp "$W/build/ssrecomp" "$G/pokemon-ds-wide"
in_docker fulldex-cross bash -c 'aarch64-linux-gnu-strip /p/dist/pokemonfulldex/pokemonfulldex/pokemon-ds-wide &&
    patchelf --remove-rpath /p/dist/pokemonfulldex/pokemonfulldex/pokemon-ds-wide'
mkdir -p "$G/data" "$G/roms" "$G/licenses"
cp -r "$W/funcs" "$G/data/funcs"
cp "$SRC/LICENSE" "$G/licenses/LICENSE.fulldex.txt"
cp "$SRC/LICENSE-Noto.txt" "$G/licenses/LICENSE.noto.txt"
cp "$SRC/frontend/fonts/FONT-LICENSES.txt" "$G/licenses/LICENSE.fonts.txt"
cp "$GBA/mgba/LICENSE" "$G/licenses/LICENSE.mgba.txt"
(cd "$HERE/dist" && rm -f pokemonfulldex.zip && python3 -c "
import os, zipfile
with zipfile.ZipFile('pokemonfulldex.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk('pokemonfulldex'):
        dirs.sort()
        for f in sorted(files):
            p = os.path.join(root, f)
            z.write(p, os.path.relpath(p, 'pokemonfulldex'))
        for d in dirs:
            p = os.path.join(root, d)
            if not os.listdir(p): z.writestr(os.path.relpath(p, 'pokemonfulldex') + '/', '')
")
say "Done: $HERE/dist/pokemonfulldex.zip"
in_docker fulldex-cross bash -c 'f=/p/dist/pokemonfulldex/pokemonfulldex/pokemon-ds-wide; file "$f";
    aarch64-linux-gnu-readelf -d "$f" | grep NEEDED;
    echo "needs: $(aarch64-linux-gnu-objdump -T "$f" | grep -oE "GLIBC_[0-9.]+|GLIBCXX_[0-9.]+" | sort -uV | tr "\n" " ")"'
