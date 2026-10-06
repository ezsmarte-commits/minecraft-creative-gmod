# Minecraft Creative (Garry's Mod)

Minecraft-style creative building inside Garry's Mod, using the real block textures and sounds
from **your own copy of Minecraft Java Edition**. Build on any Garry's Mod map, then turn your
build into Garry's Mod physics and knock it down, or light some TNT.

## What you get
- A Garry's Mod gamemode, **Minecraft Creative**, based on Sandbox (spawn menu, physics gun and
  tool gun all still work).
- **The Block Hand:** place and break blocks on a 1-block grid, with the outline on the block you
  are aiming at.
- **21 Minecraft blocks:** grass, dirt, stone, cobblestone, stone bricks, bricks, oak planks,
  oak log, oak leaves, glass, sand, gravel, white and red wool, bookshelf, blocks of iron, gold
  and diamond, obsidian, glowstone and TNT.
- **A 9-slot hotbar** (number keys / mouse wheel) and a block picker (E).
- **Creative flight:** double-tap jump to fly; Space goes up, Ctrl goes down, Shift goes faster.
  Landing stops flying.
- **The physics switch:** press F and everything connected to the block you're looking at
  becomes physics blocks (up to 256 at once).
- **TNT:** left-click TNT to light it (crouch to just break it). It explodes after 4 seconds,
  blasting nearby blocks loose as physics props and setting off other TNT. Shooting a loose TNT
  block lights it too.
- **Real Minecraft sounds** for placing, breaking, footsteps on blocks, the TNT fuse and
  explosions.
- **Single player.**

## Controls
| Key | Action |
|---|---|
| Left mouse | Break block (crouch to break TNT without lighting it) |
| Right mouse | Place block |
| Middle mouse | Pick the block you're looking at |
| 1-9, mouse wheel | Choose hotbar slot |
| E | Open all blocks |
| F | Turn the build you're looking at into physics |
| R | Switch to the Physics Gun (press 1 to come back) |
| Space twice | Fly |

Keys follow your own Garry's Mod bindings (use, flashlight, reload, slot keys).

## Requirements
- Garry's Mod.
- Minecraft Java Edition 1.13 or newer, played at least once so its files are on this PC.
  Bedrock (Microsoft Store) Edition doesn't work, because its files can't be read.

None of Minecraft's files are included with this mod. When you press Play, a small helper
(`helper/mcc-assets.exe`) copies the 25 block textures and 56 sounds the mod uses from your own
Minecraft install into the mod's folder. Without Minecraft, the mod still runs with plain
coloured blocks and Garry's Mod sounds, and shows a message saying so.

## How to play
Press **Play** on its Melty page. Melty installs the gamemode, copies the textures and sounds
from your own Minecraft on the first Play (a few seconds), and starts Garry's Mod straight into
Minecraft Creative on gm_flatgrass.

## For developers
Melty's install recipe is `tools/melty_recipe.json`; `build.py package` fills in the version and
writes the release zip with the add-on under `addons/` and the helper under `helper/`.
To run it without Melty: copy `addons/minecraft_creative` into `garrysmod/addons`, run
`helper/mcc-assets.exe -addon <that folder>`, then start Garry's Mod with
`+gamemode mccreative +map gm_flatgrass`.

The design lives in `sheets/*.json`: blocks, sound groups, effects, controls, hooks and settings.
Each row generates code (`lua/mcc/sh_gen_*.lua`); edit the sheet, never the generated file.

```
python3 tools/build.py preflight       # every cell filled, every reference resolves
python3 tools/build.py gen             # preflight, then generate Lua + helper manifest
python3 tools/build.py package 0.1.0   # gen, build the Windows helper, zip into dist/
luajit tests/run_tests.lua             # mod logic in a simulated server + client
python3 tests/test_helper.py           # helper against fake Minecraft installs
python3 tests/test_preflight.py        # preflight catches broken sheets
```

## Credits
- Minecraft, its textures and sounds © Mojang Studios. They are read from the player's own copy
  and never distributed.
- Garry's Mod © Facepunch Studios.
- Mod: see the listing for author, licence and remix permissions.
