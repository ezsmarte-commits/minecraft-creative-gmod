# MODLOG: Minecraft Creative for Garry's Mod

## Intake (2026-10-06)
- Game: Garry's Mod (Source 1, Lua add-ons). Idea: Minecraft creative mode inside GMod, using the
  player's own Minecraft Java textures and sounds. Solo. First version: about 20 blocks, grid
  place/break, hotbar, picker, physics switch, real sounds, outline, flight.
- Required games: Garry's Mod + Minecraft Java Edition 1.13+ (a real dependency, not inspiration).
- Anti-cheat: none relevant. Lua add-ons are GMod's official route; we run a local single-player
  game.

## Route
- A gamemode derived from Sandbox, shipped as a legacy add-on folder
  `garrysmod/addons/minecraft_creative/`. No loader is needed, and Melty installs none for GMod.
- Minecraft assets: a Go helper (`helper/`, a static Windows exe) copies the textures from
  `versions/<v>/<v>.jar` and the sounds via `assets/indexes/<n>.json` → `assets/objects/` into the
  add-on's own `materials/mcc/block/` and `sound/mcc/` before launch. GMod Lua can't read outside
  its own folder, so the helper is required. Nothing of Minecraft is in the upload.
- Rendering: per-chunk (16³) IMesh per texture, UnlitGeneric + `$vertexcolor` with Minecraft's
  fixed per-face shading baked into vertex colours, `$alphatest` for glass/leaves, `$nocull`.
- Collision: one `mcc_chunk` entity per chunk, greedy-merged boxes →
  `PhysicsInitMultiConvex`, static.
- Flight: `Move` hook returning true while flying, with our own hull-trace collision.

## Verified so far
- 25 texture and 56 sound names exist in Minecraft 1.13, 1.21.10 and 26.3 (name listings from
  InventivetalentDev/minecraft-assets; only file names were downloaded, not the assets).
- All 18 hook names confirmed on wiki.facepunch.com (`tools/gmod_hooks.txt`).
- `tests/run_tests.lua`: 34 tests of the real Lua in a simulated server + client.
- `tests/test_helper.py`: 13 helper tests on fake Minecraft installs.
- `tests/test_preflight.py`: preflight catches 12 kinds of broken sheet.

## Not verified yet (needs the real game on the user's PC)
- Anything engine-side: mesh rendering and point sampling, alpha-tested glass/leaves, multi-convex
  collision feel, Move-hook flight feel, PNG Material loading from the add-on folder, the
  `Explosion` effect, the 23 GMod fallback sounds (`build/pending.txt`).
- That `gm_flatgrass` spawn leaves the grid flush with the floor.

## Blocked
- melty.gg is refused by this workspace's network policy (proxy 403), so there has been no
  game_info, search_mashups, inspect_package, one_click_check, listing or upload yet.
- The user's PC is not linked to this chat, so the mod has not run in Garry's Mod yet and no
  screenshot exists.

## Next
1. In-game test on the user's PC: install the add-on, run the helper, launch with
   `+gamemode mccreative +map gm_flatgrass`, check the pending list, take the screenshot.
2. Melty: game_info and recipe (pre-launch helper + launch args), inspect_package, validate_recipe,
   one_click_check, then a draft listing.
