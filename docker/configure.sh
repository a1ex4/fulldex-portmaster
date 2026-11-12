#!/bin/bash
# Configures the aarch64 build inside the fulldex-cross image.
#   configure.sh SRC BUILD GEN GBA_WORK
set -euo pipefail
SRC="$1" BUILD="$2" GEN="$3" GBA_WORK="$4"
cmake -S "$SRC" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/opt/aarch64.cmake -DCMAKE_FIND_ROOT_PATH="/opt/sdl2-arm64;/" \
    -DSDL2_DIR=/opt/sdl2-arm64/lib/cmake/SDL2 \
    -DSSR_EGL_LIBRARY=/usr/lib/aarch64-linux-gnu/libEGL.so -DSSR_EGL_INCLUDE=/usr/include \
    -DSSR_JIT=ON -DSSR_PC_ALL_GAMES=ON -DSSR_PNG=OFF -DSSR_GPU3D=ON \
    -DSSR_GENERATED_DIR="$GEN" -DSSR_GBA_DIR="$SRC/gba" -DGBAW_WORK="$GBA_WORK"
