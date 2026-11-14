# Pokemon Fulldex for PortMaster

[Pokemon Fulldex](https://github.com/mamesj/pokemon-fulldex) packaged for [PortMaster](https://portmaster.games) on aarch64 handhelds (built for the RG35XX-H on muOS). The release zip goes in the `ports` folder; the ROMs go in `ports/pokemonfulldex/roms`.

## How it is built

Upstream's own aarch64 download needs glibc 2.38, newer than most handheld firmwares, and PortMaster does not allow bundling the C library, libstdc++, SDL2 or EGL. So `build.sh` cross-compiles it in Docker against Debian bullseye, linking the device's own SDL2 and EGL (the result needs glibc 2.30):

```
./build.sh --decomp                    # SoulSilver built from pret/pokeheartgold (no ROM needed)
./build.sh --rom soulsilver-us.nds     # or from your own SoulSilver (US) ROM
```

Either way, SoulSilver is only read for the addresses in its tables, as upstream's `tools/pc/build_all.sh` does: no game code goes in the zip. `patches/` is applied over the pinned upstream release:

- `updater-option.patch` turns off the in-app updater, which would otherwise replace the build with upstream's glibc 2.38 one.
- `pr171-battle-strip-label-width.patch` and `pr174-ui-size.patch` are upstream pull requests [#171](https://github.com/mamesj/pokemon-fulldex/pull/171) (battle buttons' labels in other languages) and [#174](https://github.com/mamesj/pokemon-fulldex/pull/174) (a UI Size setting for small screens), until a release includes them; then drop them.

## Versions and releases

`upstream.env` pins the upstream release (`FULLDEX_TAG`, `FULLDEX_COMMIT`) and the pokeheartgold commit. A port release is `<upstream tag>-<n>`, for example `fulldex-2026-11-12-1`; n starts again at 1 when upstream moves.

Releases are built locally and uploaded by hand, as upstream does its own:

```
PORT_VERSION=fulldex-2026-11-12-1 \
UPDATE_URL=https://api.github.com/repos/<owner>/<repo>/releases/latest \
./build.sh --decomp
git tag fulldex-2026-11-12-1 && git push origin fulldex-2026-11-12-1
gh release create fulldex-2026-11-12-1 dist/pokemonfulldex.zip dist/pokemonfulldex.zip.sha256
```

To follow a new upstream release, set `FULLDEX_TAG` and `FULLDEX_COMMIT` in `upstream.env` to it, check that `patches/` still apply (`build.sh` stops if not), and release `<new tag>-1`.

## Updates on the device

Builds made with `UPDATE_URL` (an API address answering with the latest release as JSON, such as GitHub's `releases/latest` above) carry `update.py` and an `update.cfg` with that address. Each launch of the port then asks for the latest release (5 seconds at most; offline it carries on quietly) and, when it is newer than the installed `version.txt`, downloads its zip, checked against its `.sha256`, into PortMaster's `autoinstall` folder, which PortMaster installs the next time it is opened. Only released builds (`fulldex-*` versions) update themselves; other builds (`dev`) never do. Without `UPDATE_URL` the package has no updater at all, as a PortMaster submission should be.

## Testing on the handheld

`tools/device.sh` drives the device over SSH, at the address in `DEVICE` (`DEVICE=root@<handheld address> tools/device.sh ...`): `push` installs a build, `run [secs] [game code]` starts the launch script as the menu does and picks that game unattended, `bench`/`frames <rom>` time a DS game headless or in the window, and `logs` fetches `log.txt` (the launch script, PortMaster, the updater) and `game.log` (the program) into `work/device-logs/`. For a crash, a build with `-g` (`docker/configure.sh ... "-DCMAKE_CXX_FLAGS_RELEASE=-O3 -DNDEBUG -g"`), `ulimit -c unlimited` on the device and `docker/Dockerfile.gdb` (gdb-multiarch) read its core.
