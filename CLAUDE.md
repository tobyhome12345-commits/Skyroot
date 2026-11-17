# First Game — rules for all work

This is a **Godot 4.7** project.

## Godot console

The Godot console exe is:

```
"C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
```

`godot_console` in these notes means that full path (it is not on PATH, so always use the full quoted path).

- Check for script errors after **every** change:
  `godot_console --headless --path . --editor --quit`
  (loads and parses every script; works even before a main scene exists).
  Once a main scene exists, also run it briefly: `godot_console --headless --path . --quit-after 60`
  Read the output; fix any `SCRIPT ERROR` / `ERROR` / `Parse Error` lines before moving on.
- Gameplay test (movement, blocking, F3 debug): `godot_console --headless --path . --script res://tools/test_movement.gd` — must print `RESULT: ALL PASSED`.
- Fit check (both islands: tiles, flush on ground, overlaps, colliders, gaps): `godot_console --headless --path . --script res://tools/check_fit.gd` must print `RESULT: ALL PASSED`. Run it after any change to props or models.
- Tree check (Great Tree: vines and hanging pieces attached, knots / hollows in the bark, branches and leaves attached, roots resting on the ground and not clipping, fallen leaves on open grass): `godot_console --headless --path . --script res://tools/check_tree.gd`
- Launch check (both islands: shared tiles, launch point on an edge facing sky, landing tile free and reachable, nothing cut off): `godot_console --headless --path . --script res://tools/check_islands.gd`
- Travel test (launch prompt, menu, full glide cutscene, Esc / Space skip, landing, game state across trips): `godot_console --headless --path . --script res://tools/test_travel.gd`
- Interior check (all 4 house interiors: tiles, flush stacking, overlaps, walls, colliders, floor, entrance→exit path, physics walk): `godot_console --headless --path . --script res://tools/check_interiors.gd` must print `RESULT: ALL PASSED`. Run it after any interior change.
- Door test (every house: prompt, E, fade, interior, exit, back in front of the same door): `godot_console --headless --path . --script res://tools/test_doors.gd`
- Villager check (island + 4 interiors: shared tiles, doors/exits blocked, flush, colliders, dialogue files): `godot_console --headless --path . --script res://tools/check_villagers.gd`
- Dialogue test (prompt, E opens/advances/closes, typing, player locked, facing, cycling): `godot_console --headless --path . --script res://tools/test_dialogue.gd`
- Window test (not headless; start maximized, F11 fullscreen, Esc untouched): `godot_console --path . --script res://tools/test_fullscreen.gd`
- Check the version: `godot_console --version`

## Display

- Base resolution is 1920x1080 with `canvas_items` stretch and `keep` aspect. The game starts maximized.
- F11 toggles fullscreen (`WindowControls` autoload). **Esc** closes an open menu (destination menu) and skips cutscenes; otherwise it is **reserved for the pause menu**, so don't bind it to anything else.
- Screen effects must look the same at any resolution, so size them by screen fraction, not pixels (see `shaders/tilt_shift.gdshader`).

## Assets

- Kenney CC0 packs live in `Assets/`. Credits are in `Assets/CREDITS.md`, so update it when a new pack is used.
- Use the GLB/GLTF files only. The other formats are skipped via `.gdignore`.
- Place models through `ModelLib` (`scripts/model_lib.gd`), which scales them to the tile footprint and sits them flush on the ground.

## Dialogue

- Villager lines live in `data/dialogue/<id>.json`: `{"name", "model", "conversations": [[page, page], ...]}`. Each talk shows the next conversation, cycling round. Edit the JSON to change what villagers say; no code changes needed.

## Islands, travel and cutscenes

- Islands are listed in `data/islands.json`. A new island extends `scripts/island.gd` (see `scripts/test_island.gd`) and overrides `_map`, `_prop_layout`, `_villager_layout` and `_launch_layout`.
- Every island has a launch point on an edge tile, with its flag / signpost on a tile beside it along the edge; the tile in front of it is the landing tile, reserved so nothing can be placed there. The launch lip is the only thing allowed to stick out of its tile, and only over open sky (the fit checks enforce this).
- Cutscenes are shot lists in `data/cutscenes/*.json`, played by the `Cutscene` autoload (format documented at the top of `scripts/cutscene.gd`). Positions are relative to an anchor the level provides (`cutscene_anchor(name)`).
- Anything that must survive travel goes in `Game.state` (one game state for the whole game).

## Language

- **GDScript only.** No C#, no GDExtension, no other languages.

## Grid world

- Build the world on a grid. Every wall, floor and object snaps to **whole tile coordinates**.
- **No freeform decimal positions.** Positions come from integer tile coords (e.g. `Vector2i` / `Vector3i`) multiplied by a single tile-size constant — never hand-typed decimals.

## Work style

- **Never delete anything without asking the user first** and getting a yes. That includes generated files such as Godot `.import` files. The project is in OneDrive, so bulk deletes pop up alarming prompts.
- **Small steps only.** Do one small change at a time.
- **Test after each step** (at minimum the headless error check above).

## Git & GitHub

- Repo: https://github.com/tobyhome12345-commits/Skyroot (branch `main`, remote `origin`).
- **Always save, commit and push after every update** — no exceptions, however small the change.
  1. Save the game: make sure every changed scene (`.tscn`), resource (`.tres`) and script is written to disk.
  2. Run the error check.
  3. `git add`, commit with a clear message, then `git push`.
- **Never commit passwords, tokens or keys.** Check `git status` / `git diff --cached` before every commit.
- Show the user the push result (terminal output or the GitHub page) after each step.

## Screenshots

- **Use screenshots sparingly**: at most a few per stage, only where a picture really helps (e.g. one before and one after a visual change). Never take dozens. They use up a lot of the user's usage.
- Verify everything else with the headless checks and tests.
- How: `godot_console --path . --script res://tools/screenshot.gd -- screenshots/<name>.png` (not headless; options are listed at the top of `tools/screenshot.gd`).
