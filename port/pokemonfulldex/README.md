## Installation
Copy your own DS and GBA ROMs (any names) to `ports/pokemonfulldex/roms`, then pick a game from the list. Saves go in `ports/pokemonfulldex/saves`; an existing `.sav` from another emulator can be put there under the game's name (`soulsilver.sav`, `black2.sav`, ...).

Supported: Black 2, White 2, Black, White, HeartGold, SoulSilver, Platinum, Diamond, Pearl (DS) and Emerald, Ruby, Sapphire, FireRed, LeafGreen, Ultra Violet (GBA). See the [upstream README](https://github.com/mamesj/pokemon-fulldex#supported-games) for the regions of each.

## Default Controls
The program reads the controller directly and plays it as a DS. In the list, the d-pad chooses, A plays and Y opens the settings. While playing, Start opens the pause menu (QUIT returns to the list) and holding the right trigger fast-forwards. **CONTROLS > KEYS AND BUTTONS** in the pause menu changes any of them.

## Performance
On the first run the 3D is drawn at the DS's resolution (192P) without 60 fps in-between frames. On faster devices raise **GRAPHICS > 3D RESOLUTION** and turn on 60 FPS. WORLD ON GPU needs desktop OpenGL and falls back to the processor where the GPU only has OpenGL ES.

## Building
Cross-compiled for aarch64 against Debian bullseye (glibc 2.30 or newer needed) from the upstream release named in the version, with the in-app updater turned off so it never replaces this build with the upstream download. The scripts and patches are in the port's build repository.

## Thanks
mamesj -- Pokemon Fulldex  
melonDS team -- DS emulator core  
endrift -- mGBA  
pret, fuddlesworth (pokebw2), Project-Holon (aletheia) -- decompilations the address tables come from  
Testers and Devs from the PortMaster Discord
