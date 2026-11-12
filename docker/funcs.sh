#!/bin/bash
# The per-game function tables (data/funcs), as tools/pc/build_all.sh makes them: from the
# decompilations' symbol files only. Run inside the fulldex-cross image.
#   funcs.sh SRC WORK OUT
set -euo pipefail
SRC="$1" WORK="$2" OUT="$3"
fetch_symbols() { # dir url commit paths...
    local dir="$1" url="$2" commit="$3"
    shift 3
    [ -d "$dir/.git" ] || { git init -q "$dir"; git -C "$dir" remote add origin "$url"; }
    git -C "$dir" sparse-checkout set --no-cone "$@"
    git -C "$dir" fetch -q --depth 1 --filter=blob:none origin "$commit"
    git -C "$dir" checkout -q --force FETCH_HEAD
}
eval "$(grep -E '^(BW2_DECOMP|BW2_COMMIT|W2_COMMIT|BW1_DECOMP|BW1_COMMIT)=' "$SRC/tools/pc/build_all.sh")"
fetch_symbols "$WORK/pokebw2" "$BW2_DECOMP" "$BW2_COMMIT" \
    '/config/b2_us/arm9/symbols.txt' '/config/b2_us/arm9/*/symbols.txt' '/config/b2_us/arm9/overlays/*/symbols.txt'
fetch_symbols "$WORK/pokew2" "$BW2_DECOMP" "$W2_COMMIT" \
    '/config/w2_us/arm9/symbols.txt' '/config/w2_us/arm9/*/symbols.txt' '/config/w2_us/arm9/overlays/*/symbols.txt'
fetch_symbols "$WORK/aletheia" "$BW1_DECOMP" "$BW1_COMMIT" '/layout/function_addrs.tsv'
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$SRC"
python3 tools/bw2/funcmap.py "$WORK/pokebw2/config/b2_us/arm9" - "$OUT/IREO.txt"
python3 tools/bw2/funcmap.py "$WORK/pokew2/config/w2_us/arm9" - "$OUT/IRDO.txt"
python3 tools/bw1/funcmap.py "$WORK/aletheia/layout/function_addrs.tsv" - "$OUT/IRBO.txt"
python3 tools/bw1/funcmap.py "$WORK/aletheia/layout/function_addrs.tsv" - "$OUT/IRAO.txt" --white
cp tools/platinum/CPUE.txt tools/platinum/ADAE.txt "$OUT/"
python3 tools/shift_table.py --all "$OUT"
cp tools/regions/*.txt "$OUT/"
