#!/bin/bash
# Test loop on the handheld over SSH (muOS: Configuration > Web Services > SSH).
#
#   tools/device.sh push [dir]          install a build (default dist/pokemonfulldex) over the port
#   tools/device.sh bin                 recompile work/src as it is (ninja, no clean checkout) and
#                                       push the game alone over the installed port: for edits
#   tools/device.sh run [secs] [code]   the launch script, as from the menu; a game code (IPKE,
#                                       IPKF ...; GBA: BPEE, BPRE or GBA-<key> such as GBA-rubyfr)
#                                       is picked in the list unattended; then the logs
#   tools/device.sh bench <rom> [n]     a DS game, n frames (default 600) headless, timed
#   tools/device.sh frames <rom> [n]    a DS game, n frames (default 1200) in the window, timed
#                                       (vsync: 60/s); GBA games only play in the list (run)
#   tools/device.sh logs                log.txt, game.log, game-previous.log, settings.cfg into
#                                       work/device-logs/<time>/ (and printed)
#   tools/device.sh sh <command>        a command in the port's folder
#   tools/device.sh shot [name]         what the screen shows now, from the framebuffer, into
#                                       work/shots/<name or time>-<page>.png (one per page of
#                                       the triple-buffered framebuffer: the newest is the one shown)
#
# DEVICE (the handheld's SSH address, root@<address>: required), PORTS (/mnt/mmc/ports), SCRIPTS (/mnt/mmc/ROMS/Ports).
# <rom> is a file name in the port's roms folder, or a part of one.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="${DEVICE:?set DEVICE to the SSH address of the handheld, e.g. DEVICE=root@<address>}"
PORTS="${PORTS:-/mnt/mmc/ports}"
SCRIPTS="${SCRIPTS:-/mnt/mmc/ROMS/Ports}"
GAME="$PORTS/pokemonfulldex"
SCRIPT="$SCRIPTS/Pokemon Fulldex.sh"
on() { ssh -o BatchMode=yes -o ConnectTimeout=8 "$DEVICE" "$@"; }
# (Stops what a run leaves behind, by exact name: pkill -f would match this shell too.)
STOP='for p in pokemon-ds-wide gptokeyb gptokeyb2; do pids=$(pidof $p); [ -n "$pids" ] && kill $pids; done; sleep 1'
rom() { on "cd '$GAME/roms' && ls | grep -F -m1 -- '$1'" || { echo "no ROM matching '$1' in $GAME/roms" >&2; exit 1; }; }

logs() {
    local out="$HERE/work/device-logs/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$out"
    on "cd '$GAME' && tar -cf - log.txt game.log game-previous.log settings.cfg version.txt 2>/dev/null" | tar -C "$out" -xf -
    for f in log.txt game.log; do
        [ -f "$out/$f" ] && { echo "== $f"; cat "$out/$f"; }
    done
    echo "(saved in $out)"
}

case "${1:-}" in
    push)
        src="${2:-$HERE/dist/pokemonfulldex}"
        [ -f "$src/pokemonfulldex/pokemon-ds-wide" ] || { echo "no build in $src (./build.sh first)" >&2; exit 1; }
        tar -C "$src" -cf - pokemonfulldex | on "tar -C '$PORTS' -xf -"
        on "cat > '$SCRIPT'" < "$src/Pokemon Fulldex.sh"
        echo "installed $(on "cat '$GAME/version.txt'") on $DEVICE" ;;
    bin)
        W="${FULLDEX_WORK:-$HERE/work}"
        docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -v "$HERE:/p" -v "$W:/w" -w /p fulldex-cross bash -c \
            'ninja -C /w/build ssrecomp > /tmp/ninja.log || { grep -B2 -A6 -m8 "error" /tmp/ninja.log; exit 1; }; aarch64-linux-gnu-strip -o /w/build/ssrecomp.stripped /w/build/ssrecomp'
        on "cat > '$GAME/pokemon-ds-wide.new' && mv '$GAME/pokemon-ds-wide.new' '$GAME/pokemon-ds-wide' && chmod +x '$GAME/pokemon-ds-wide'" < "$W/build/ssrecomp.stripped"
        echo "pushed $(stat -c %s "$W/build/ssrecomp.stripped") bytes" ;;
    run)
        secs="${2:-60}" code="${3:-}"
        on "cd '$SCRIPTS' && SSR_LIST_PICK='$code' timeout $secs bash '$SCRIPT' >/dev/null 2>&1; echo \"launch script: exit \$?\"; $STOP"
        logs ;;
    bench|frames)
        [ -n "${2:-}" ] || { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
        r="$(rom "$2")"
        case "$r" in *.nds) ;; *) echo "$1 takes DS games only: GBA games play inside the game list (run <secs> <code>)" >&2; exit 1 ;; esac
        if [ "$1" = bench ]; then n="${3:-600}" mode=--headless; else n="${3:-1200}" mode=; fi
        on "cd '$GAME' && s=\$(date +%s); timeout 600 ./pokemon-ds-wide 'roms/$r' --jit $mode --frames $n --no-save --config settings.cfg > /tmp/fdx-$1.log 2>&1; rc=\$?; e=\$(date +%s);
            grep -E '^\[(widegpu|display|60fps)\]' /tmp/fdx-$1.log; echo \"$1 $r: $n frames in \$((e - s)) s, exit \$rc (60 frames = 1 s at full speed, plus start-up)\"; $STOP" ;;
    logs) logs ;;
    shot)
        name="${2:-$(date +%Y%m%d-%H%M%S)}" out="$HERE/work/shots" raw="$(mktemp)"
        mkdir -p "$out"
        read -r w h bpp <<<"$(on 'cat /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel' | tr ',\n' '  ')"
        [ "$bpp" = 32 ] || { echo "framebuffer is $bpp bits a pixel, only 32 handled" >&2; exit 1; }
        on 'cat /dev/fb0' > "$raw"
        sh=$(( w * 3 / 4 )) # (a 4:3 screen: the framebuffer holds pages of this height, more than virtual_size says)
        page=$(( w * sh * 4 )) pages=$(( $(stat -c %s "$raw") / (w * sh * 4) ))
        for i in $(seq 0 $((pages - 1))); do
            dd if="$raw" bs=$(( w * 4 )) skip=$(( i * sh )) count=$sh status=none |
                ffmpeg -loglevel error -y -f rawvideo -pix_fmt bgra -s "${w}x${sh}" -i - -frames:v 1 "$out/$name-$i.png"
        done
        rm -f "$raw"
        ls "$out/$name"-*.png ;;
    sh) shift; on "cd '$GAME' && $*" ;;
    *) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
