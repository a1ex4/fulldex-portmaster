# Pokemon Fulldex for PortMaster

[Pokemon Fulldex](https://github.com/mamesj/pokemon-fulldex) packaged for [PortMaster](https://portmaster.games) on aarch64 handhelds (built for the RG35XX-H on muOS): the DS and GBA Pokémon games as one widescreen picture.

## Installing

1. **Download** `pokemonfulldex.zip` from the [latest release](https://github.com/a1ex4/fulldex-portmaster/releases/latest).
2. **Install it** with PortMaster: copy the zip, as it is, into PortMaster's `autoinstall` folder (on muOS: `MUOS/PortMaster/autoinstall` on the first SD card), then open PortMaster, which installs it. Or unzip it yourself into your firmware's `ports` folder (muOS: `ports` on either SD card).
3. **Add your ROMs** (below), then start **Pokemon Fulldex** from Ports and pick a game from the list.

After that, each launch checks for a newer release (a few seconds at most, nothing when offline) and downloads it: open PortMaster to install it. Your ROMs, saves and settings are kept.

### Your ROMs

The port holds none of the games: you bring your own copies.

- Put them in `ports/pokemonfulldex/roms` (the folder is there after installing). Any file names work, and subfolders (one per console, say) are read too.
- Use the plain `.nds` and `.gba` files: **unzip** `.zip` or `.7z` downloads first, as the list does not read archives. (Ultra Violet can also be its `.ips` patch beside a FireRed 1.0 ROM.)
- Use unchanged copies of the cartridges (not trimmed, patched or translated): the program recognises each game by its exact contents.
- Supported: Black 2, White 2, Black, White, HeartGold, SoulSilver, Platinum, Diamond and Pearl (DS); Emerald, Ruby, Sapphire, FireRed, LeafGreen and Ultra Violet (GBA). Which languages and versions of each work: upstream's [supported games](https://github.com/mamesj/pokemon-fulldex#supported-games). The 3DS games are not in this port.
- Already have your DS and GBA games in another folder (your firmware's own `NDS` and `GBA` folders, say)? On the **ROMs** page of the list, **Choose ROMs Folder** reads them from there instead.
- To copy them over the network instead of moving the SD card: muOS has SFTP under Configuration > Web Services.

The list shows each game it recognises; a ROM it doesn't is left out of it.

### Your saves

Saves are written to `ports/pokemonfulldex/saves`, one per game and language (`soulsilver.sav`, `heartgold-fr.sav`, `black2-es.sav`, ...). To carry on from another emulator, copy its `.sav` there under that name before starting the game the first time. Save states go in `ports/pokemonfulldex/states` and Fulldex's own settings files in `ports/pokemonfulldex/settings` (since fulldex-2026-11-15: an update moves the old ones there once, by itself).

## How it is built

Upstream's own aarch64 download needs glibc 2.38, newer than most handheld firmwares, and PortMaster does not allow bundling the C library, libstdc++, SDL2 or EGL. So `build.sh` cross-compiles it in Docker against Debian bullseye, linking the device's own SDL2 and EGL (the result needs glibc 2.30):

```
./build.sh --decomp                    # SoulSilver built from pret/pokeheartgold (no ROM needed)
./build.sh --rom soulsilver-us.nds     # or from your own SoulSilver (US) ROM
```

Either way, SoulSilver is only read for the addresses in its tables, as upstream's `tools/pc/build_all.sh` does: no game code goes in the zip. `patches/` is applied over the pinned upstream release:

- `updater-option.patch` turns off the in-app updater, which would otherwise replace the build with upstream's glibc 2.38 one.
- `pr174-ui-size.patch` is upstream pull request [#174](https://github.com/mamesj/pokemon-fulldex/pull/174) (a UI Size setting for small screens), until a release includes it; then drop it. (#171, battle buttons' labels in other languages, is in upstream since fulldex-2026-11-15.)

## Versions and releases

`upstream.env` pins the upstream release (`FULLDEX_TAG`, `FULLDEX_COMMIT`) and the pokeheartgold commit. A port release is `<upstream tag>-<n>`, for example `fulldex-2026-11-12-1`; n starts again at 1 when upstream moves.

Releases are built locally and uploaded by hand, as upstream does its own:

```
PORT_VERSION=fulldex-2026-11-12-1 \
UPDATE_URL=https://api.github.com/repos/a1ex4/fulldex-portmaster/releases/latest \
./build.sh --decomp
git tag fulldex-2026-11-12-1 && git push origin fulldex-2026-11-12-1
gh release create fulldex-2026-11-12-1 dist/pokemonfulldex.zip dist/pokemonfulldex.zip.sha256
```

To follow a new upstream release, set `FULLDEX_TAG` and `FULLDEX_COMMIT` in `upstream.env` to it, check that `patches/` still apply (`build.sh` stops if not), and release `<new tag>-1`.

## Updates on the device

Builds made with `UPDATE_URL` (an API address answering with the latest release as JSON, such as GitHub's `releases/latest` above) carry `update.py` and an `update.cfg` with that address. Each launch of the port then asks for the latest release (5 seconds at most; offline it carries on quietly) and, when it is newer than the installed `version.txt`, downloads its zip, checked against its `.sha256`, into PortMaster's `autoinstall` folder, which PortMaster installs the next time it is opened. Only released builds (`fulldex-*` versions) update themselves; other builds (`dev`) never do. Without `UPDATE_URL` the package has no updater at all, as a PortMaster submission should be.

## Testing on the handheld

`tools/device.sh` drives the device over SSH, at the address in `DEVICE` (`DEVICE=root@<handheld address> tools/device.sh ...`): `push` installs a build, `run [secs] [game code]` starts the launch script as the menu does and picks that game unattended, `bench`/`frames <rom>` time a DS game headless or in the window, and `logs` fetches `log.txt` (the launch script, PortMaster, the updater) and `game.log` (the program) into `work/device-logs/`. For a crash, a build with `-g` (`docker/configure.sh ... "-DCMAKE_CXX_FLAGS_RELEASE=-O3 -DNDEBUG -g"`), `ulimit -c unlimited` on the device and `docker/Dockerfile.gdb` (gdb-multiarch) read its core.
