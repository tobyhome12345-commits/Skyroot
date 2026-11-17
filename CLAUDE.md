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
- Fit check (every island: tiles, flush on ground, overlaps, colliders, gaps): `godot_console --headless --path . --script res://tools/check_fit.gd` must print `RESULT: ALL PASSED`. Run it after any change to props or models.
- Tree check (Great Tree: vines and hanging pieces attached, knots / hollows in the bark, branches and leaves attached, roots resting on the ground and not clipping, fallen leaves on open grass): `godot_console --headless --path . --script res://tools/check_tree.gd`
- Launch check (every island, plus talk spots: shared tiles, launch point on an edge facing sky, landing tile free and reachable, nothing cut off): `godot_console --headless --path . --script res://tools/check_islands.gd`
- Small islands test (bench and seed "Press E" lines, trader's cycling talks, seed glows and stays put): `godot_console --headless --path . --script res://tools/test_small_islands.gd`
- Travel test (launch prompt, menu, full glide cutscene, Esc / Space skip, landing, game state across trips): `godot_console --headless --path . --script res://tools/test_travel.gd`
- Leafwind check (two levels: shared tiles, flush on its floor, no gaps or steps at bridges / stairs / deck edges, guarded drops, physics walks up every stairs and over every bridge, launch on an edge, landing free, every open tile reachable from the landing tile; plus its 3 interiors): `godot_console --headless --path . --script res://tools/check_leafwind.gd` must print `RESULT: ALL PASSED` (add `-- selftest` to prove it catches problems).
- Leafwind talk test (all 8 villagers: prompt, E, turn to face you, cycling lines, player locked): `godot_console --headless --path . --script res://tools/test_leafwind_talk.gd`
- Interior check (all 7 house interiors: tiles, flush stacking, overlaps, walls, colliders, floor, entrance→exit path, physics walk): `godot_console --headless --path . --script res://tools/check_interiors.gd` must print `RESULT: ALL PASSED`. Run it after any interior change.
- Door test (every house: prompt, E, fade, interior, exit, back in front of the same door): `godot_console --headless --path . --script res://tools/test_doors.gd`
- Villager check (Pebblenook, Trader's Rock, Leafwind + 5 interiors: shared tiles, doors/exits blocked, flush, colliders, dialogue files): `godot_console --headless --path . --script res://tools/check_villagers.gd`
- Dialogue test (prompt, E opens/advances/closes, typing, player locked, facing, cycling): `godot_console --headless --path . --script res://tools/test_dialogue.gd`
- Intro test (opening lore scene: starts once, all beats in order, seed glows, camera never clips, Esc / Space skip, no replay, control and colour back, elder recaps): `godot_console --headless --path . --script res://tools/test_intro.gd`
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

- Islands are listed in `data/islands.json`. An island may have two levels (see `scripts/leafwind.gd`): it overrides `cell_level`, `is_land`, `is_walkway` and `walk_links`; place everything with `cell_pos(cell)`. A new island extends `scripts/island.gd` (see `scripts/lookout_isle.gd`) and overrides `_map`, `_prop_layout`, `_villager_layout` and `_launch_layout`; `_add_talk_spot` adds a "Press E" line from a dialogue file.
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

- **Do not take screenshots.** The user asked for none (they use up a lot of their usage). Only take one if the user explicitly asks for that specific screenshot in their latest message; a stage brief listing screenshots is not enough.
- Verify everything with the headless checks and tests instead, and describe results in text.
- If asked: `godot_console --path . --script res://tools/screenshot.gd -- screenshots/<name>.png` (options at the top of `tools/screenshot.gd`).
