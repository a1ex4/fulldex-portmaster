# Pokemon Fulldex for PortMaster

[Pokemon Fulldex](https://github.com/mamesj/pokemon-fulldex) packaged for [PortMaster](https://portmaster.games) on aarch64 handhelds (built for the RG35XX-H on muOS). The release zip goes in the `ports` folder; the ROMs go in `ports/pokemonfulldex/roms`.

## How it is built

Upstream's own aarch64 download needs glibc 2.38, newer than most handheld firmwares, and PortMaster does not allow bundling the C library, libstdc++, SDL2 or EGL. So `build.sh` cross-compiles it in Docker against Debian bullseye, linking the device's own SDL2 and EGL (the result needs glibc 2.30):

```
./build.sh --decomp                    # SoulSilver built from pret/pokeheartgold (no ROM needed)
./build.sh --rom soulsilver-us.nds     # or from your own SoulSilver (US) ROM
```

Either way, SoulSilver is only read for the addresses in its tables, as upstream's `tools/pc/build_all.sh` does: no game code goes in the zip. `patches/` turns off the in-app updater, which would otherwise replace the build with upstream's glibc 2.38 one.

## Versions and releases

`upstream.env` pins the upstream release (`FULLDEX_TAG`, `FULLDEX_COMMIT`) and the pokeheartgold commit. A port release is `<upstream tag>-<n>`, for example `fulldex-2026-11-08-1`.

## Updates on the device
